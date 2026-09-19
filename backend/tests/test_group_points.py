"""Group points are tracked per group challenge, separate from personal HP."""

import uuid
from datetime import date

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.session import Base
from app.models.profile import (
    Challenge,
    ChallengeDay,
    ChallengeStatus,
    Group,
    GroupMember,
    GroupMemberRole,
    HpEvent,
    Profile,
)
from app.services.group_service import GroupService


def _profile(name: str, hp: int = 100) -> Profile:
    return Profile(id=uuid.uuid4(), email=f"{name}@t.io", full_name=name, hp=hp)


def _challenge(user: Profile, group_id=None, name="c") -> Challenge:
    return Challenge(
        id=uuid.uuid4(),
        user_id=user.id,
        name=name,
        duration_days=21,
        status=ChallengeStatus.ACTIVE,
        start_date=date.today(),
        current_day=1,
        group_id=group_id,
    )


def _events(user, challenge, deltas):
    return [
        HpEvent(user_id=user.id, challenge_id=challenge.id, delta=d, reason="t")
        for d in deltas
    ]


@pytest.fixture
async def session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as s:
        yield s
    await engine.dispose()


async def test_group_ranking_uses_group_points_only(session):
    ana, ben, cy, dee = (_profile(n) for n in ("Ana", "Ben", "Cy", "Dee"))
    group = Group(
        id=uuid.uuid4(), leader_id=ana.id, name="G", invite_code="ABC123",
        duration_days=21, starts_at=date.today(),
    )
    session.add_all([ana, ben, cy, dee, group])
    await session.flush()
    session.add_all(
        GroupMember(group_id=group.id, user_id=u.id,
                    role=GroupMemberRole.LEADER if u is ana else GroupMemberRole.MEMBER)
        for u in (ana, ben, cy, dee)
    )

    ana_g, ben_g, cy_g, dee_g = (_challenge(u, group.id, "group") for u in (ana, ben, cy, dee))
    # Ben has a huge personal challenge; it must not lift his group rank.
    ben_personal = _challenge(ben, None, "personal")
    session.add_all([ana_g, ben_g, cy_g, dee_g, ben_personal])
    await session.flush()

    session.add_all(_events(ana, ana_g, [10, 10, 10, 10]))          # 40
    session.add_all(_events(ben, ben_g, [10, 10, 10, 10, 10, -15]))  # 35 net of a miss
    session.add_all(_events(ben, ben_personal, [10] * 50))           # 500 personal, ignored
    session.add_all(_events(cy, cy_g, [-15, -15]))                   # floors at 0
    # Dee: legacy challenge with no events, 3 complete days -> 30
    session.add_all(
        ChallengeDay(challenge_id=dee_g.id, day_number=n, calendar_date=date.today(),
                     is_complete=True)
        for n in (1, 2, 3)
    )
    ben.hp = 600  # global HP is inflated by the personal challenge
    await session.flush()

    members = await GroupService(session)._build_members_data(group.id, ana.id)
    by_name = {m["full_name"]: m for m in members}

    assert by_name["Ana"]["group_points"] == 40
    assert by_name["Ben"]["group_points"] == 35
    assert by_name["Dee"]["group_points"] == 30
    assert by_name["Cy"]["group_points"] == 0

    # Ranking follows group points, not global HP (Ben has the highest HP).
    assert [m["full_name"] for m in members] == ["Ana", "Ben", "Dee", "Cy"]
    assert [m["rank"] for m in members] == [1, 2, 3, 4]
    assert by_name["Ben"]["hp"] == 600

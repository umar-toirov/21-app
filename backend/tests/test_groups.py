"""Groups: admin-set tasks, joining, leaving, chat, group leaderboard, cancel, calendar."""

import uuid
from app.core.security import app_today

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.exceptions import AppError, ConflictError, ForbiddenError
from app.db.session import Base
from app.models.profile import (
    Challenge,
    ChallengeStatus,
    GroupMember,
    HpEvent,
    Profile,
    TaskType,
)
from app.schemas.schemas import GroupCreate, GroupDashboardResponse
from app.services.challenge_service import TASK_POINTS, ChallengeService
from app.services.group_service import MAX_MESSAGES_PER_MINUTE, GroupService


@pytest.fixture
async def session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as s:
        yield s
    await engine.dispose()


async def _user(session, name: str) -> Profile:
    p = Profile(id=uuid.uuid4(), email=f"{name}@t.io", full_name=name, hp=0)
    session.add(p)
    await session.flush()
    return p


def _data(mode="shared", group_tasks=("Read 20 pages", "Walk 30 minutes"), own=(), name="Study Squad", is_public=False):
    return {
        "name": name,
        "duration_days": 21,
        "max_missed_days": 3,
        "starts_at": app_today(),
        "group_tasks": list(group_tasks),
        "task_mode": mode,
        "personal_tasks": list(own),
        "is_public": is_public,
    }


async def _challenge_of(session, user: Profile, group) -> Challenge:
    from sqlalchemy.orm import selectinload

    result = await session.execute(
        select(Challenge)
        .where(Challenge.user_id == user.id, Challenge.group_id == group.id)
        .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
    )
    return result.scalar_one()


def _titles(challenge: Challenge, active_only=True):
    return sorted(t.title for t in challenge.tasks if t.is_active or not active_only)


# ------------------------------------------------------------------ tasks & joining
async def test_shared_group_gives_everyone_the_admins_tasks(session):
    admin, ben = await _user(session, "Ana"), await _user(session, "Ben")
    service = GroupService(session)
    group = await service.create_group(admin, _data())

    preview = await service.preview_by_invite_code(group.invite_code)
    assert preview["group_tasks"] == ["Read 20 pages", "Walk 30 minutes"]
    assert preview["foundation_tasks"] == preview["group_tasks"]  # older app builds
    assert preview["leader_name"] == "Ana"
    assert preview["member_count"] == 1

    await service.join_group(ben, group.invite_code)
    mine = await _challenge_of(session, ben, group)
    assert _titles(mine) == ["Read 20 pages", "Walk 30 minutes"]
    # No made-up "foundation" habits are ever added to a group.
    assert all(t.type == TaskType.FOUNDATION for t in mine.tasks)  # stored type only
    assert "Wake up on time" not in _titles(mine)


async def test_freedom_group_members_choose_their_own_tasks(session):
    admin, ben = await _user(session, "Ana"), await _user(session, "Ben")
    service = GroupService(session)
    group = await service.create_group(
        admin, _data(mode="freedom", group_tasks=(), own=("Code 1 hour",))
    )
    assert _titles(await _challenge_of(session, admin, group)) == ["Code 1 hour"]

    with pytest.raises(AppError):  # nothing chosen and no group tasks
        await service.join_group(ben, group.invite_code, personal_tasks=[])
    await service.join_group(ben, group.invite_code, personal_tasks=["Gym", "gym", " "])
    assert _titles(await _challenge_of(session, ben, group)) == ["Gym"]


async def test_creating_a_group_needs_tasks(session):
    admin = await _user(session, "Ana")
    service = GroupService(session)
    with pytest.raises(AppError):
        await service.create_group(admin, _data(group_tasks=()))
    with pytest.raises(AppError):
        await service.create_group(admin, _data(mode="freedom", group_tasks=(), own=()))


def test_old_apps_can_still_send_foundation_tasks():
    body = GroupCreate.model_validate(
        {
            "name": "G",
            "duration_days": 21,
            "starts_at": app_today().isoformat(),
            "foundation_tasks": ["A", "B"],
        }
    )
    assert body.group_tasks == ["A", "B"]


async def test_admin_adds_and_removes_tasks_for_everyone(session):
    admin, ben = await _user(session, "Ana"), await _user(session, "Ben")
    service = GroupService(session)
    group = await service.create_group(admin, _data())
    await service.join_group(ben, group.invite_code)

    result = await service.add_group_task(group.id, admin.id, "Drink water")
    assert result["tasks"][-1] == "Drink water"
    for user in (admin, ben):
        assert "Drink water" in _titles(await _challenge_of(session, user, group))

    with pytest.raises(ForbiddenError):
        await service.add_group_task(group.id, ben.id, "Nope")
    with pytest.raises(ConflictError):
        await service.add_group_task(group.id, admin.id, "drink WATER")

    await service.remove_group_task(group.id, admin.id, "Drink water")
    for user in (admin, ben):
        assert "Drink water" not in _titles(await _challenge_of(session, user, group))

    await service.remove_group_task(group.id, admin.id, "Read 20 pages")
    with pytest.raises(AppError):  # a shared group keeps at least one task
        await service.remove_group_task(group.id, admin.id, "Walk 30 minutes")


# ------------------------------------------------------------------ leaving
async def test_leave_and_end_group(session):
    admin, ben = await _user(session, "Ana"), await _user(session, "Ben")
    service = GroupService(session)
    group = await service.create_group(admin, _data())
    await service.join_group(ben, group.invite_code)

    with pytest.raises(AppError) as err:
        await service.leave_group(group.id, admin.id)
    assert err.value.detail["code"] == "LEADER_CANNOT_LEAVE"

    await service.leave_group(group.id, ben.id)
    members = (await session.execute(select(GroupMember.user_id))).scalars().all()
    assert ben.id not in members
    assert (await _challenge_of(session, ben, group)).status == ChallengeStatus.ARCHIVED

    await service.end_group(group.id, admin.id)
    assert group.status == "ended"
    assert group.id not in [g["id"] for g in await service.get_user_groups(admin.id)]
    assert (await _challenge_of(session, admin, group)).status == ChallengeStatus.ARCHIVED


# ------------------------------------------------------------------ chat
async def test_chat_flow(session):
    admin = await _user(session, "Ana")
    ben = await _user(session, "Ben")
    outsider = await _user(session, "Cy")
    service = GroupService(session)
    group = await service.create_group(admin, _data())
    await service.join_group(ben, group.invite_code)

    m1 = await service.post_message(group.id, admin.id, "  Welcome team!  ")
    m2 = await service.post_message(group.id, ben.id, "Hi!")
    assert m1["body"] == "Welcome team!" and m1["is_leader"] and m1["is_you"]

    listing = await service.list_messages(group.id, ben.id)
    assert [m["body"] for m in listing["messages"]] == ["Welcome team!", "Hi!"]
    assert [m["is_you"] for m in listing["messages"]] == [False, True]

    # Polling: only what is newer than the last message the app has.
    m3 = await service.post_message(group.id, admin.id, "Day 1 starts today")
    newer = await service.list_messages(group.id, ben.id, after_id=m2["id"])
    ids = [m["id"] for m in newer["messages"]]
    assert m3["id"] in ids and m1["id"] not in ids

    older = await service.list_messages(group.id, ben.id, before_id=m3["id"], limit=1)
    assert len(older["messages"]) == 1

    with pytest.raises(ForbiddenError):
        await service.list_messages(group.id, outsider.id)
    with pytest.raises(ForbiddenError):
        await service.post_message(group.id, outsider.id, "let me in")
    with pytest.raises(AppError):
        await service.post_message(group.id, ben.id, "   ")

    # Members delete their own; the admin can delete anyone's; others cannot.
    with pytest.raises(ForbiddenError):
        await service.delete_message(group.id, m1["id"], ben.id)
    await service.delete_message(group.id, m2["id"], ben.id)
    await service.delete_message(group.id, m1["id"], admin.id)
    after = await service.list_messages(group.id, ben.id)
    deleted = [m for m in after["messages"] if m["is_deleted"]]
    assert len(deleted) == 2 and all(m["body"] == "" for m in deleted)


async def test_chat_rate_limit_and_length(session):
    admin = await _user(session, "Ana")
    service = GroupService(session)
    group = await service.create_group(admin, _data())
    long = await service.post_message(group.id, admin.id, "x" * 5000)
    assert len(long["body"]) == 1000
    for _ in range(MAX_MESSAGES_PER_MINUTE - 1):
        await service.post_message(group.id, admin.id, "spam")
    with pytest.raises(AppError) as err:
        await service.post_message(group.id, admin.id, "one too many")
    assert err.value.status_code == 429


# ------------------------------------------------------------------ points, dashboard, leaderboard
async def test_dashboard_reports_group_points_through_the_response_schema(session):
    """Regression: group_points used to be dropped by the API schema (app showed 0)."""
    admin, ben = await _user(session, "Ana"), await _user(session, "Ben")
    service = GroupService(session)
    group = await service.create_group(admin, _data())
    await service.join_group(ben, group.invite_code)

    challenge = await _challenge_of(session, admin, group)
    await ChallengeService(session).complete_task(admin, challenge.id, challenge.tasks[0].id)

    dashboard = await service.get_dashboard(group.id, admin.id)
    parsed = GroupDashboardResponse.model_validate(dashboard)
    by_name = {m.full_name: m for m in parsed.members}
    assert by_name["Ana"].group_points == TASK_POINTS
    assert by_name["Ben"].group_points == 0
    assert parsed.members[0].full_name == "Ana"  # ranked first
    assert parsed.stats.average_group_points == round(TASK_POINTS / 2)


async def test_groups_are_ranked_by_their_participants_points(session):
    a1, a2, b1, b2, b3 = [await _user(session, n) for n in ("A1", "A2", "B1", "B2", "B3")]
    service = GroupService(session)
    big = await service.create_group(a1, {**_data(), "name": "Big"})
    await service.join_group(a2, big.invite_code)
    small = await service.create_group(b1, {**_data(), "name": "Small"})
    await service.join_group(b2, small.invite_code)
    await service.join_group(b3, small.invite_code)

    async def points(user, group, amount):
        challenge = await _challenge_of(session, user, group)
        session.add(HpEvent(user_id=user.id, challenge_id=challenge.id, delta=amount, reason="t"))

    await points(a1, big, 40)
    await points(a2, big, 30)   # Big: total 70 across 2 members -> avg 35
    await points(b1, small, 30)
    await points(b2, small, 30)
    await points(b3, small, -100)  # a member's score never drops below 0 in the sum
    # Small: 30 + 30 + 0 = 60 across 3 members -> avg 20
    await session.flush()

    by_total = await service.groups_leaderboard(a1.id, "total")
    assert [g["name"] for g in by_total] == ["Big", "Small"]
    assert by_total[0]["total_points"] == 70 and by_total[1]["total_points"] == 60
    assert [g["rank"] for g in by_total] == [1, 2]
    assert by_total[0]["is_yours"] and not by_total[1]["is_yours"]

    by_avg = await service.groups_leaderboard(b1.id, "average")
    assert {g["name"]: g["average_points"] for g in by_avg} == {"Big": 35, "Small": 20}
    assert by_avg[0]["name"] == "Big"


# ------------------------------------------------------------------ cancel + calendar
async def test_cancel_personal_challenge(session):
    admin = await _user(session, "Ana")
    challenges = ChallengeService(session)
    c = await challenges.create_personal_challenge(
        admin, name="Read", goal_slug="reading", duration_days=21,
        personal_tasks=["Read 30 min", "Notes"], include_foundation=False,
    )
    cancelled = await challenges.cancel_challenge(admin, c.id)
    assert cancelled.status == ChallengeStatus.ARCHIVED

    with pytest.raises(AppError):  # already cancelled
        await challenges.cancel_challenge(admin, c.id)

    # A new one can be started right away.
    again = await challenges.create_personal_challenge(
        admin, name="Read again", goal_slug="reading", duration_days=21,
        personal_tasks=["Read 30 min", "Notes"], include_foundation=False,
    )
    assert again.status == ChallengeStatus.ACTIVE


async def test_group_challenge_is_left_not_cancelled(session):
    admin = await _user(session, "Ana")
    group = await GroupService(session).create_group(admin, _data())
    challenge = await _challenge_of(session, admin, group)
    with pytest.raises(AppError) as err:
        await ChallengeService(session).cancel_challenge(admin, challenge.id)
    assert err.value.detail["code"] == "USE_LEAVE_GROUP"


async def test_calendar_shows_what_the_user_did(session):
    admin = await _user(session, "Ana")
    challenges = ChallengeService(session)
    c = await challenges.create_personal_challenge(
        admin, name="Read", goal_slug="reading", duration_days=21,
        personal_tasks=["Read 30 min", "Write notes"], include_foundation=False,
    )
    c = await challenges.get_active_challenge(admin.id)
    today = app_today()

    empty = await challenges.activity_for_month(admin.id, today.year, today.month)
    assert next(d for d in empty["days"] if d["date"] == today.isoformat())["status"] == "pending"

    await challenges.complete_task(admin, c.id, c.tasks[0].id)
    month = await challenges.activity_for_month(admin.id, today.year, today.month)
    day = next(d for d in month["days"] if d["date"] == today.isoformat())
    assert day["status"] == "partial" and day["done"] == 1
    assert day["tasks"][0]["title"] == c.tasks[0].title
    assert day["tasks"][0]["challenge"] == "Read"

    await challenges.complete_task(admin, c.id, c.tasks[1].id)
    month = await challenges.activity_for_month(admin.id, today.year, today.month)
    day = next(d for d in month["days"] if d["date"] == today.isoformat())
    assert day["status"] == "done" and day["done"] == 2
    assert month["totals"]["tasks_done"] == 2 and month["totals"]["perfect_days"] == 1


# ------------------------------------------------------------------ names & visibility
async def test_group_names_are_unique_case_insensitive(session):
    admin = await _user(session, "Ana")
    other = await _user(session, "Ben")
    service = GroupService(session)
    await service.create_group(admin, _data(name="Study Squad"))

    with pytest.raises(ConflictError):
        await service.create_group(other, _data(name="study squad"))

    # Freed up once the group ends.
    group = (await session.execute(select(Challenge).where(Challenge.user_id == admin.id))).scalar_one()
    from app.models.profile import Group as GroupModel

    row = (await session.execute(select(GroupModel).where(GroupModel.leader_id == admin.id))).scalar_one()
    row.status = "ended"
    await session.flush()
    reused = await service.create_group(other, _data(name="Study Squad"))
    assert reused.name == "Study Squad"


async def test_renaming_a_group_checks_uniqueness(session):
    admin = await _user(session, "Ana")
    other = await _user(session, "Ben")
    service = GroupService(session)
    mine = await service.create_group(admin, _data(name="Alpha Team"))
    theirs = await service.create_group(other, _data(name="Beta Team"))

    with pytest.raises(ConflictError):
        await service.update_group(theirs.id, other.id, {"name": "Alpha Team"})

    # Renaming to the same name (any case) is a no-op, not a conflict.
    await service.update_group(mine.id, admin.id, {"name": "alpha team"})
    # A genuinely free name works.
    await service.update_group(mine.id, admin.id, {"name": "Alpha Squad"})
    assert mine.name == "Alpha Squad"


async def test_public_groups_are_discoverable_and_joinable_without_a_code(session):
    admin = await _user(session, "Ana")
    seeker = await _user(session, "Ben")
    service = GroupService(session)
    public_group = await service.create_group(admin, _data(name="Open Study", is_public=True))
    await service.create_group(await _user(session, "Cy"), _data(name="Closed Study", is_public=False))

    listing = await service.list_public_groups(seeker.id)
    names = {g["name"] for g in listing}
    assert "Open Study" in names
    assert "Closed Study" not in names
    entry = next(g for g in listing if g["name"] == "Open Study")
    assert entry["is_member"] is False

    joined = await service.join_public_group(seeker, public_group.id)
    assert joined.id == public_group.id
    members = (await session.execute(select(GroupMember.user_id).where(GroupMember.group_id == public_group.id))).scalars().all()
    assert seeker.id in members


async def test_private_groups_cannot_be_joined_via_the_public_endpoint(session):
    admin = await _user(session, "Ana")
    seeker = await _user(session, "Ben")
    service = GroupService(session)
    private_group = await service.create_group(admin, _data(name="Invite Only", is_public=False))

    with pytest.raises(ForbiddenError):
        await service.join_public_group(seeker, private_group.id)

"""Points: every task earns points, a perfect day adds a bonus, a missed day costs points."""

import uuid
from datetime import date, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.session import Base
from app.models.profile import HpEvent, Profile
from app.services.challenge_service import (
    DAY_BONUS_POINTS,
    MISSED_DAY_PENALTY,
    TASK_POINTS,
    ChallengeService,
)


@pytest.fixture
async def session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as s:
        yield s
    await engine.dispose()


async def _start(session, hp=0):
    profile = Profile(id=uuid.uuid4(), email="a@t.io", full_name="Ana", hp=hp)
    session.add(profile)
    await session.flush()
    service = ChallengeService(session)
    await service.create_personal_challenge(
        profile, name="Read", goal_slug="reading", duration_days=21,
        personal_tasks=["Read 30 minutes", "Write one takeaway"],
        include_foundation=False,
    )
    challenge = await service.get_active_challenge(profile.id)
    return service, profile, challenge


async def test_each_task_earns_points_and_last_task_adds_bonus(session):
    service, profile, challenge = await _start(session)
    assert profile.hp == 0

    first, second = challenge.tasks

    r1 = await service.complete_task(profile, challenge.id, first.id)
    assert r1["hp_delta"] == TASK_POINTS
    assert r1["celebration"] is False
    assert profile.hp == TASK_POINTS

    r2 = await service.complete_task(profile, challenge.id, second.id)
    assert r2["hp_delta"] == TASK_POINTS + DAY_BONUS_POINTS
    assert r2["celebration"] is True
    assert profile.hp == 2 * TASK_POINTS + DAY_BONUS_POINTS

    # Ticking the same task again never pays twice.
    again = await service.complete_task(profile, challenge.id, second.id)
    assert again["hp_delta"] == 0
    assert profile.hp == 2 * TASK_POINTS + DAY_BONUS_POINTS

    events = (await session.execute(select(HpEvent.reason, HpEvent.delta))).all()
    assert sorted(events) == sorted(
        [("task_complete", TASK_POINTS)] * 2 + [("daily_complete", DAY_BONUS_POINTS)]
    )

    detail = await service.build_detail(profile, challenge)
    assert detail["points_today"] == 2 * TASK_POINTS + DAY_BONUS_POINTS
    assert detail["penalty_points"] == 0


async def test_missed_days_remove_points_and_are_reported(session):
    service, profile, challenge = await _start(session, hp=100)

    # Pretend the challenge began two days ago and nothing was done.
    challenge.start_date = date.today() - timedelta(days=2)
    profile.current_streak = 4
    await session.flush()

    await service.sync_calendar_day(profile, challenge)

    assert challenge.current_day == 3
    assert profile.hp == 100 - 2 * MISSED_DAY_PENALTY
    assert profile.current_streak == 0

    detail = await service.build_detail(profile, challenge)
    assert detail["penalty_points"] == 2 * MISSED_DAY_PENALTY

    reasons = (await session.execute(select(HpEvent.reason))).scalars().all()
    assert reasons.count("missed_day") == 2


async def test_points_never_go_below_zero(session):
    service, profile, challenge = await _start(session, hp=10)
    challenge.start_date = date.today() - timedelta(days=1)
    await session.flush()
    await service.sync_calendar_day(profile, challenge)
    assert profile.hp == 0

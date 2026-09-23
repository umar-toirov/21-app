"""Challenge frameworks and start-date scheduling."""

import uuid
from datetime import timedelta
from app.core.security import app_today

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.exceptions import AppError, ConflictError
from app.data.challenge_templates import CATEGORIES, TEMPLATES, TEMPLATES_BY_ID
from app.db.session import Base
from app.models.profile import ChallengeStatus, Profile
from app.services.challenge_service import MAX_START_AHEAD_DAYS, ChallengeService

SEEDED_GOALS = {
    "ielts", "sat", "programming", "fitness", "reading", "productivity",
    "quran", "personal_development", "other",
}


def test_catalog_is_consistent():
    ids = [t["id"] for t in TEMPLATES]
    assert len(ids) == len(set(ids)), "template ids must be unique"
    assert len(TEMPLATES) >= 30

    categories = {c["id"] for c in CATEGORIES}
    for t in TEMPLATES:
        assert t["category"] in categories, t["id"]
        assert t["goal"] in SEEDED_GOALS, t["id"]
        assert t["difficulty"] in {"easy", "medium", "hard"}, t["id"]
        assert 7 <= t["duration_days"] <= 90, t["id"]
        assert 2 <= len(t["tasks"]) <= 10, t["id"]
        assert all(x.strip() for x in t["tasks"]), t["id"]
        assert t["title"].strip() and t["description"].strip() and t["icon"], t["id"]
    assert set(TEMPLATES_BY_ID) == set(ids)
    # every category is used
    assert {t["category"] for t in TEMPLATES} == categories


@pytest.fixture
async def session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as s:
        yield s
    await engine.dispose()


async def _profile(session, name="Ana") -> Profile:
    p = Profile(id=uuid.uuid4(), email=f"{name}@t.io", full_name=name)
    session.add(p)
    await session.flush()
    return p


TASKS = ["Read 30 minutes", "Write one takeaway"]


async def test_starts_today_by_default(session):
    profile = await _profile(session)
    service = ChallengeService(session)
    c = await service.create_personal_challenge(
        profile, name="Read", goal_slug="reading", duration_days=21, personal_tasks=TASKS
    )
    assert c.start_date == app_today()
    assert c.status == ChallengeStatus.ACTIVE
    assert profile.onboarding_step == 6

    c = await service.get_active_challenge(profile.id)  # loads tasks/days like the API
    detail = await service.build_detail(profile, c)
    assert detail["days_until_start"] == 0
    assert detail["name"] == "Read"
    # 3 foundation + 2 personal
    assert len(detail["tasks"]) == 5


async def test_future_start_is_scheduled_and_locked(session):
    profile = await _profile(session)
    service = ChallengeService(session)
    start = app_today() + timedelta(days=3)
    c = await service.create_personal_challenge(
        profile, name="Later", goal_slug="other", duration_days=21,
        personal_tasks=TASKS, start_date=start,
    )
    assert c.start_date == start

    c = await service.get_active_challenge(profile.id)
    detail = await service.build_detail(profile, c)
    assert detail["days_until_start"] == 3
    assert "Starts" in detail["today_mission"]

    # No penalties or day advance before the start date.
    hp_before = profile.hp
    await service.sync_calendar_day(profile, c)
    assert c.current_day == 1 and profile.hp == hp_before

    # Calendar days begin on the chosen date.
    days = sorted(c.days, key=lambda d: d.day_number)
    assert days[0].calendar_date == start
    assert days[-1].calendar_date == start + timedelta(days=20)

    task_id = next(t["id"] for t in detail["tasks"])
    with pytest.raises(AppError) as err:
        await service.complete_task(profile, c.id, task_id)
    assert err.value.detail["code"] == "NOT_STARTED"


async def test_validation_rules(session):
    profile = await _profile(session)
    service = ChallengeService(session)

    with pytest.raises(AppError):  # too few tasks (duplicates collapse)
        await service.create_personal_challenge(
            profile, name=None, goal_slug="other", duration_days=21,
            personal_tasks=["Walk", "walk", "  "],
        )
    with pytest.raises(AppError):  # too far ahead
        await service.create_personal_challenge(
            profile, name=None, goal_slug="other", duration_days=21, personal_tasks=TASKS,
            start_date=app_today() + timedelta(days=MAX_START_AHEAD_DAYS + 1),
        )
    with pytest.raises(AppError):  # duration out of range
        await service.create_personal_challenge(
            profile, name=None, goal_slug="other", duration_days=3, personal_tasks=TASKS,
        )

    # A past start date is treated as today; only one personal challenge at a time.
    c = await service.create_personal_challenge(
        profile, name=None, goal_slug="other", duration_days=21, personal_tasks=TASKS,
        start_date=app_today() - timedelta(days=1),
    )
    assert c.start_date == app_today()
    with pytest.raises(ConflictError):
        await service.create_personal_challenge(
            profile, name=None, goal_slug="other", duration_days=21, personal_tasks=TASKS,
        )

from datetime import date, timedelta
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_profile, get_current_user_id
from app.db.session import get_db
from app.models.profile import (
    Badge,
    Certificate,
    Challenge,
    ChallengeStatus,
    DeviceToken,
    Goal,
    GroupMember,
    HpEvent,
    Profile,
    UserBadge,
)
from app.schemas.schemas import (
    AnnouncementCreate,
    BadgeResponse,
    CertificateResponse,
    ChallengeDetailResponse,
    ChallengeResponse,
    ChallengeTaskCreate,
    CompleteTaskRequest,
    CompleteTaskResponse,
    DeviceTokenCreate,
    GoalResponse,
    GroupCreate,
    GroupDashboardResponse,
    GroupInvitePreview,
    GroupJoin,
    GroupResponse,
    GroupSessionCreate,
    GroupUpdate,
    HpEventResponse,
    LeaderboardEntry,
    OnboardingResponse,
    OnboardingStepUpdate,
    PersonalStatsResponse,
    ProfileCreate,
    ProfileResponse,
    ProfileUpdate,
    WeeklyReportResponse,
)
from app.services.challenge_service import (
    ChallengeService,
    DisciplineScoreService,
    PERSONAL_TASK_TEMPLATES,
)
from app.services.group_service import GroupService

router = APIRouter()


@router.get("/health")
async def health():
    return {"status": "ok", "service": "ilm-mode-api"}


# --- Profile ---
@router.get("/me", response_model=ProfileResponse)
async def get_me(profile: Annotated[Profile, Depends(get_current_profile)]):
    return profile


@router.patch("/me", response_model=ProfileResponse)
async def update_me(
    data: ProfileUpdate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)
    await db.flush()
    return profile


@router.delete("/me")
async def delete_me(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from app.core.security import utcnow

    profile.is_deleted = True
    profile.deleted_at = utcnow()
    await db.flush()
    return {"message": "Account scheduled for deletion"}


@router.post("/me/device-token")
async def register_device_token(
    data: DeviceTokenCreate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    existing = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == profile.id, DeviceToken.fcm_token == data.fcm_token
        )
    )
    if not existing.scalar_one_or_none():
        db.add(DeviceToken(user_id=profile.id, fcm_token=data.fcm_token, platform=data.platform))
    return {"status": "registered"}


@router.post("/profiles", response_model=ProfileResponse)
async def create_profile(data: ProfileCreate, db: Annotated[AsyncSession, Depends(get_db)]):
    existing = await db.execute(select(Profile).where(Profile.id == data.id))
    if existing.scalar_one_or_none():
        result = await db.execute(select(Profile).where(Profile.id == data.id))
        return result.scalar_one()
    profile = Profile(
        id=data.id,
        email=data.email,
        full_name=data.full_name,
        discipline_score=0,
        hp=100,
    )
    db.add(profile)
    await db.flush()
    return profile


# --- Onboarding ---
@router.get("/onboarding", response_model=OnboardingResponse)
async def get_onboarding(profile: Annotated[Profile, Depends(get_current_profile)]):
    return OnboardingResponse(step=profile.onboarding_step, data=profile.onboarding_data or {})


@router.put("/onboarding/step/{step}")
async def save_onboarding_step(
    step: int,
    data: OnboardingStepUpdate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    merged = {**(profile.onboarding_data or {}), **data.data}
    profile.onboarding_data = merged
    profile.onboarding_step = max(profile.onboarding_step, step)
    await db.flush()
    return {"step": profile.onboarding_step, "data": profile.onboarding_data}


@router.post("/onboarding/complete", response_model=ChallengeResponse)
async def complete_onboarding(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = ChallengeService(db)
    challenge = await service.create_from_onboarding(profile)
    return challenge


# --- Goals ---
@router.get("/goals", response_model=list[GoalResponse])
async def list_goals(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Goal).order_by(Goal.id))
    return result.scalars().all()


@router.get("/tasks/templates")
async def task_templates(goal: str = Query(default="other")):
    return {"goal": goal, "templates": PERSONAL_TASK_TEMPLATES.get(goal, PERSONAL_TASK_TEMPLATES["other"])}


# --- Challenges ---
@router.get("/challenges", response_model=list[ChallengeResponse])
async def list_challenges(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: str | None = None,
):
    query = select(Challenge).where(Challenge.user_id == profile.id)
    if status:
        query = query.where(Challenge.status == status)
    result = await db.execute(query.order_by(Challenge.created_at.desc()))
    return result.scalars().all()


@router.get("/challenges/active", response_model=ChallengeDetailResponse | None)
async def get_active_challenge(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = ChallengeService(db)
    challenge = await service.get_active_challenge(profile.id)
    if not challenge:
        return None
    return await service.build_detail(profile, challenge)


@router.get("/challenges/active-all")
async def get_active_programs(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = ChallengeService(db)
    return await service.get_active_programs(profile.id)


@router.get("/challenges/{challenge_id}", response_model=ChallengeDetailResponse)
async def get_challenge(
    challenge_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from sqlalchemy.orm import selectinload

    result = await db.execute(
        select(Challenge)
        .where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
        .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
    )
    challenge = result.scalar_one_or_none()
    if not challenge:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Challenge")
    service = ChallengeService(db)
    return await service.build_detail(profile, challenge)


@router.post("/challenges/{challenge_id}/complete-task", response_model=CompleteTaskResponse)
async def complete_task(
    challenge_id: UUID,
    data: CompleteTaskRequest,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = ChallengeService(db)
    result = await service.complete_task(profile, challenge_id, data.task_id)
    new_score = await DisciplineScoreService.recompute(db, profile)
    result["new_score"] = new_score
    return result


@router.post("/challenges/{challenge_id}/tasks")
async def add_challenge_task(
    challenge_id: UUID,
    data: ChallengeTaskCreate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = ChallengeService(db)
    task = await service.add_personal_task(profile, challenge_id, data.title)
    await db.commit()
    type_val = task.type.value if hasattr(task.type, "value") else str(task.type)
    return {
        "id": task.id,
        "title": task.title,
        "type": type_val,
        "sort_order": task.sort_order,
    }

@router.get("/challenges/{challenge_id}/days/{day_number}")
async def get_challenge_day_detail(
    challenge_id: UUID,
    day_number: int,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Return task history for a specific challenge day (past or today)."""
    from sqlalchemy.orm import selectinload

    result = await db.execute(
        select(Challenge)
        .where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
        .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
    )
    challenge = result.scalar_one_or_none()
    if not challenge:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Challenge")

    service = ChallengeService(db)
    return await service.build_day_history(challenge, day_number)


@router.post("/challenges/{challenge_id}/recovery/check-in")
async def recovery_check_in(
    challenge_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = ChallengeService(db)
    challenge = await service.recovery_check_in(profile, challenge_id)
    return {"status": challenge.status.value}


# --- HP & Streaks ---
@router.get("/me/hp/history", response_model=list[HpEventResponse])
async def hp_history(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = Query(default=20, le=100),
):
    result = await db.execute(
        select(HpEvent)
        .where(HpEvent.user_id == profile.id)
        .order_by(HpEvent.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/me/streaks")
async def get_streaks(profile: Annotated[Profile, Depends(get_current_profile)]):
    return {
        "current_streak": profile.current_streak,
        "longest_streak": profile.longest_streak,
        "perfect_weeks": profile.perfect_weeks,
        "challenges_completed": profile.challenges_completed,
    }


# --- Statistics ---
@router.get("/statistics/me", response_model=PersonalStatsResponse)
async def personal_statistics(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await DisciplineScoreService.recompute(db, profile)

    result = await db.execute(
        select(Challenge)
        .where(Challenge.user_id == profile.id)
        .options(selectinload(Challenge.days))
    )
    challenges = result.scalars().all()

    completed_day_rows = 0
    total_elapsed_days = 0
    missed = 0
    for c in challenges:
        if c.status not in (
            ChallengeStatus.COMPLETED,
            ChallengeStatus.ACTIVE,
            ChallengeStatus.RECOVERY,
            ChallengeStatus.FAILED,
        ):
            continue
        day_complete_count = sum(1 for d in c.days if d.is_complete)
        completed_day_rows += day_complete_count
        elapsed = min(c.current_day, c.duration_days)
        total_elapsed_days += max(elapsed, 1)
        missed += sum(1 for d in c.days if d.calendar_date < date.today() and not d.is_complete)

    completion_rate = (
        round((completed_day_rows / total_elapsed_days) * 100, 1) if total_elapsed_days else 0.0
    )

    # Last 7 calendar days of completion across active challenges.
    today = date.today()
    daily = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        done = False
        for c in challenges:
            match = next((d for d in c.days if d.calendar_date == day), None)
            if match and match.is_complete:
                done = True
                break
        daily.append({"day": day.isoformat(), "complete": done, "label": day.strftime("%a")})

    return PersonalStatsResponse(
        completion_rate=completion_rate,
        daily_consistency=daily,
        monthly_trend=[
            {
                "month": m,
                "score": max(0, profile.discipline_score - max(0, (6 - m)) * 0),
            }
            for m in range(1, 7)
        ],
        missed_days=missed,
        discipline_breakdown={
            "base": 0,
            "completed_days": min(completed_day_rows * 5, 400),
            "challenges": min(profile.challenges_completed * 40, 200),
            "perfect_weeks": min(profile.perfect_weeks * 10, 100),
            "streak_bonus": min(profile.longest_streak * 3, 120),
        },
    )


@router.get("/leaderboard", response_model=list[LeaderboardEntry])
async def global_leaderboard(
    db: Annotated[AsyncSession, Depends(get_db)],
    metric: str = Query(default="discipline_score"),
    limit: int = Query(default=50, le=100),
):
    column_map = {
        "discipline_score": Profile.discipline_score,
        "hp": Profile.hp,
        "longest_streak": Profile.longest_streak,
        "challenges_completed": Profile.challenges_completed,
    }
    col = column_map.get(metric, Profile.discipline_score)
    result = await db.execute(
        select(Profile)
        .where(Profile.is_deleted.is_(False))
        .order_by(col.desc(), Profile.created_at.asc())
        .limit(limit)
    )
    profiles = result.scalars().all()
    return [
        LeaderboardEntry(
            rank=i + 1,
            user_id=p.id,
            full_name=p.full_name,
            avatar_url=p.avatar_url,
            value=getattr(p, metric if metric != "longest_streak" else "longest_streak"),
        )
        for i, p in enumerate(profiles)
    ]


@router.get("/statistics/me/weekly-report", response_model=WeeklyReportResponse)
async def weekly_report(profile: Annotated[Profile, Depends(get_current_profile)]):
    from datetime import date, timedelta

    today = date.today()
    week_start = today - timedelta(days=today.weekday())
    return WeeklyReportResponse(
        week_start=week_start,
        completion_percent=min(100.0, profile.current_streak * 14.3),
        hp_delta=profile.hp - 100,
        rank_change=0,
        message="Discipline wins today. Keep building.",
    )


# --- Badges & Certificates ---
@router.get("/me/badges", response_model=list[BadgeResponse])
async def my_badges(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    badges_result = await db.execute(select(Badge))
    badges = badges_result.scalars().all()
    earned_result = await db.execute(select(UserBadge).where(UserBadge.user_id == profile.id))
    earned = {ub.badge_id: ub for ub in earned_result.scalars().all()}

    return [
        BadgeResponse(
            id=b.id,
            code=b.code.value,
            name=b.name,
            description=b.description,
            earned=b.id in earned,
            earned_at=earned[b.id].earned_at if b.id in earned else None,
        )
        for b in badges
    ]


@router.get("/me/certificates", response_model=list[CertificateResponse])
async def my_certificates(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Certificate).where(Certificate.user_id == profile.id).order_by(Certificate.issued_at.desc())
    )
    return result.scalars().all()


@router.get("/certificates/{certificate_id}", response_model=CertificateResponse)
async def get_certificate(certificate_id: UUID, db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Certificate).where(Certificate.id == certificate_id))
    cert = result.scalar_one_or_none()
    if not cert:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Certificate")
    return cert


# --- Groups ---
@router.post("/groups", response_model=GroupResponse)
async def create_group(
    data: GroupCreate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    group = await service.create_group(profile, data.model_dump())
    return GroupResponse(
        id=group.id,
        name=group.name,
        invite_code=group.invite_code,
        duration_days=group.duration_days,
        max_missed_days=group.max_missed_days,
        starts_at=group.starts_at,
        status=group.status,
        task_mode=getattr(group, "task_mode", None) or "shared",
        member_count=1,
    )


@router.get("/groups/preview/{invite_code}", response_model=GroupInvitePreview)
async def preview_group_invite(
    invite_code: str,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    return await service.preview_by_invite_code(invite_code)


@router.post("/groups/join", response_model=GroupResponse)
async def join_group(
    data: GroupJoin,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    group = await service.join_group(
        profile, data.invite_code, personal_tasks=data.personal_tasks
    )
    count = await db.execute(
        select(func.count()).select_from(GroupMember).where(GroupMember.group_id == group.id)
    )
    return GroupResponse(
        id=group.id,
        name=group.name,
        invite_code=group.invite_code,
        duration_days=group.duration_days,
        max_missed_days=group.max_missed_days,
        starts_at=group.starts_at,
        status=group.status,
        task_mode=getattr(group, "task_mode", None) or "shared",
        member_count=count.scalar() or 1,
    )


@router.get("/groups", response_model=list[GroupResponse])
async def list_groups(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    return await service.get_user_groups(profile.id)


@router.get("/groups/{group_id}/dashboard", response_model=GroupDashboardResponse)
async def group_dashboard(
    group_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    return await service.get_dashboard(group_id, profile.id)


@router.get("/groups/{group_id}/day-roster")
async def group_day_roster(
    group_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
    roster_date: date | None = Query(default=None, alias="date"),
):
    service = GroupService(db)
    return await service.get_day_roster(group_id, profile.id, roster_date)


@router.post("/groups/{group_id}/announcements")
async def post_announcement(
    group_id: UUID,
    data: AnnouncementCreate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    announcement = await service.post_announcement(
        group_id,
        profile.id,
        data.body,
        title=data.title,
        is_pinned=data.is_pinned,
    )
    await db.commit()
    return {
        "id": announcement.id,
        "title": announcement.title,
        "body": announcement.body,
        "is_pinned": announcement.is_pinned,
        "created_at": announcement.created_at,
    }

@router.get("/groups/{group_id}/members/{member_id}")
async def group_member_profile(
    group_id: UUID,
    member_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    return await service.get_member_profile(group_id, member_id, profile.id)


@router.get("/groups/{group_id}/statistics")
async def group_statistics(
    group_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    return await service.get_group_statistics(group_id, profile.id)


@router.patch("/groups/{group_id}")
async def update_group(
    group_id: UUID,
    data: GroupUpdate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    group = await service.update_group(
        group_id, profile.id, data.model_dump(exclude_unset=True)
    )
    await db.commit()
    return {"id": group.id, "name": group.name, "max_missed_days": group.max_missed_days}


@router.delete("/groups/{group_id}/members/{member_id}")
async def remove_group_member(
    group_id: UUID,
    member_id: UUID,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    await service.remove_member(group_id, profile.id, member_id)
    await db.commit()
    return {"ok": True}


@router.post("/groups/{group_id}/sessions")
async def create_group_session(
    group_id: UUID,
    data: GroupSessionCreate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = GroupService(db)
    session = await service.create_session(group_id, profile.id, data.model_dump())
    await db.commit()
    return {
        "id": session.id,
        "title": session.title,
        "scheduled_at": session.scheduled_at,
        "meeting_url": session.meeting_url,
    }


@router.get("/quotes/today")
async def today_quote(profile: Annotated[Profile, Depends(get_current_profile)]):
    from app.services.challenge_service import QUOTES

    idx = (profile.id.int + profile.current_streak) % len(QUOTES)
    text, author = QUOTES[idx]
    return {"text": text, "author": author}

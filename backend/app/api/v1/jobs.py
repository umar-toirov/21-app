from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import as_utc, utcnow, verify_internal_job
from app.db.session import get_db
from app.models.profile import Challenge, ChallengeStatus, Profile
from app.services.challenge_service import ChallengeService, DisciplineScoreService

router = APIRouter(prefix="/internal/jobs", tags=["jobs"])


@router.post("/close-day")
async def close_day(
    _: None = Depends(verify_internal_job),
    db: AsyncSession = Depends(get_db),
):
    """Advance active challenges past midnight and apply miss penalties."""
    result = await db.execute(
        select(Challenge)
        .where(Challenge.status.in_([ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY]))
        .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
    )
    challenges = result.scalars().all()
    processed = 0
    service = ChallengeService(db)

    for challenge in challenges:
        profile_result = await db.execute(select(Profile).where(Profile.id == challenge.user_id))
        profile = profile_result.scalar_one_or_none()
        if not profile:
            continue
        before = challenge.current_day
        await service.sync_calendar_day(profile, challenge)
        if challenge.current_day != before or challenge.status != ChallengeStatus.ACTIVE:
            processed += 1

    await db.flush()
    return {"processed": processed}


@router.post("/check-recovery")
async def check_recovery(
    _: None = Depends(verify_internal_job),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Challenge).where(Challenge.status == ChallengeStatus.RECOVERY)
    )
    failed = 0
    for challenge in result.scalars().all():
        if challenge.recovery_started_at and utcnow() - as_utc(challenge.recovery_started_at) > timedelta(hours=24):
            challenge.status = ChallengeStatus.FAILED
            challenge.failed_at = utcnow()
            failed += 1
    await db.flush()
    return {"failed": failed}


@router.post("/recompute-discipline-scores")
async def recompute_scores(
    _: None = Depends(verify_internal_job),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Profile).where(Profile.is_deleted.is_(False)))
    count = 0
    for profile in result.scalars().all():
        await DisciplineScoreService.recompute(db, profile)
        count += 1
    return {"updated": count}

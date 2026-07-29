import secrets
import string
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.exceptions import AppError, ConflictError, NotFoundError
from app.core.security import as_utc, utcnow
from app.models.profile import (
    Badge,
    BadgeCode,
    Certificate,
    Challenge,
    ChallengeDay,
    ChallengeStatus,
    ChallengeType,
    Goal,
    HpEvent,
    Payment,
    PaymentStatus,
    Profile,
    Task,
    TaskCompletion,
    TaskType,
    UserBadge,
)

FOUNDATION_TASKS = [
    "Wake up on time",
    "Daily planning",
    "Evening review",
]

PERSONAL_TASK_TEMPLATES = {
    "ielts": ["Study IELTS 1 hour", "Practice speaking", "Vocabulary review"],
    "sat": ["SAT math practice", "Reading comprehension", "Essay writing"],
    "programming": ["Code for 1 hour", "Review documentation", "Build a small project"],
    "fitness": ["Workout 30 min", "Stretching", "Track nutrition"],
    "reading": ["Read 30 pages", "Take notes", "Summarize reading"],
    "productivity": ["Deep work 2 hours", "Inbox zero", "Plan tomorrow"],
    "quran": ["Quran recitation", "Memorization", "Tafsir study"],
    "personal_development": ["Journal", "Gratitude practice", "Learn something new"],
    "other": ["Custom focus task", "Skill practice", "Reflection"],
}

QUOTES = [
    ("Discipline is choosing between what you want now and what you want most.", "Abraham Lincoln"),
    ("We are what we repeatedly do. Excellence, then, is not an act, but a habit.", "Aristotle"),
    ("The pain of discipline is far less than the pain of regret.", "Unknown"),
    ("Future you is watching.", "ILM Mode"),
    ("Small daily improvements lead to stunning results.", "Unknown"),
    ("Your mission awaits.", "ILM Mode"),
]


class ChallengeService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_active_challenge(self, user_id: UUID) -> Challenge | None:
        result = await self.db.execute(
            select(Challenge)
            .where(
                Challenge.user_id == user_id,
                Challenge.status.in_([ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY]),
            )
            .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
            .order_by(Challenge.updated_at.desc())
        )
        challenge = result.scalars().first()
        if not challenge:
            return None
        profile_result = await self.db.execute(select(Profile).where(Profile.id == user_id))
        profile = profile_result.scalar_one()
        return await self.sync_calendar_day(profile, challenge)

    async def create_from_onboarding(self, profile: Profile) -> Challenge:
        data = profile.onboarding_data or {}
        goal_slug = data.get("goal", "other")
        duration = data.get("duration_days", 21)
        personal_tasks = data.get("personal_tasks", [])

        active_result = await self.db.execute(
            select(Challenge.id).where(
                Challenge.user_id == profile.id,
                Challenge.status.in_(
                    [ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY]
                ),
            ).limit(1)
        )
        if active_result.scalar_one_or_none():
            raise ConflictError(
                "Finish or leave your current challenge before starting another one"
            )

        if len(personal_tasks) < 2:
            raise AppError("VALIDATION", "Select at least 2 personal tasks")

        existing = await self.db.execute(
            select(func.count())
            .select_from(Challenge)
            .where(Challenge.user_id == profile.id, Challenge.type == ChallengeType.INDIVIDUAL)
        )
        challenge_count = existing.scalar() or 0
        is_first_free = challenge_count == 0

        goal_result = await self.db.execute(select(Goal).where(Goal.slug == goal_slug))
        goal = goal_result.scalar_one_or_none()

        challenge_name = data.get("name") or f"{goal.name if goal else 'Personal'} {duration}-Day Discipline"

        challenge = Challenge(
            user_id=profile.id,
            goal_id=goal.id if goal else None,
            name=challenge_name,
            type=ChallengeType.INDIVIDUAL,
            duration_days=duration,
            status=ChallengeStatus.ACTIVE if is_first_free else ChallengeStatus.PENDING_PAYMENT,
            start_date=date.today(),
            current_day=1,
            is_first_free=is_first_free,
        )
        self.db.add(challenge)
        await self.db.flush()

        include_foundation = bool(data.get("include_foundation", True))
        sort_base = 0
        if include_foundation:
            for i, title in enumerate(FOUNDATION_TASKS):
                self.db.add(
                    Task(
                        challenge_id=challenge.id,
                        title=title,
                        type=TaskType.FOUNDATION,
                        sort_order=i,
                    )
                )
            sort_base = len(FOUNDATION_TASKS)

        for i, title in enumerate(personal_tasks):
            self.db.add(
                Task(
                    challenge_id=challenge.id,
                    title=title,
                    type=TaskType.PERSONAL,
                    sort_order=sort_base + i,
                )
            )

        for day_num in range(1, duration + 1):
            self.db.add(
                ChallengeDay(
                    challenge_id=challenge.id,
                    day_number=day_num,
                    calendar_date=date.today() + timedelta(days=day_num - 1),
                )
            )

        profile.onboarding_step = 6
        await self.db.flush()
        return challenge

    async def get_today_day(self, challenge: Challenge) -> ChallengeDay:
        result = await self.db.execute(
            select(ChallengeDay).where(
                ChallengeDay.challenge_id == challenge.id,
                ChallengeDay.day_number == challenge.current_day,
            )
        )
        day = result.scalar_one_or_none()
        if not day:
            raise NotFoundError("Challenge day")
        return day

    async def complete_task(
        self, profile: Profile, challenge_id: UUID, task_id: UUID
    ) -> dict:
        result = await self.db.execute(
            select(Challenge)
            .where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
            .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
        )
        challenge = result.scalar_one_or_none()
        if not challenge:
            raise NotFoundError("Challenge")
        if challenge.status not in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            raise AppError("INVALID_STATE", "Challenge is not active")

        await self.sync_calendar_day(profile, challenge)
        if challenge.status not in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            raise AppError("INVALID_STATE", "Challenge is not active")

        task = next((t for t in challenge.tasks if t.id == task_id and t.is_active), None)
        if not task:
            raise NotFoundError("Task")

        if challenge.status == ChallengeStatus.RECOVERY and task.type != TaskType.FOUNDATION:
            raise AppError("RECOVERY_MODE", "Complete foundation tasks only during recovery")

        day = await self.get_today_day(challenge)

        existing = await self.db.execute(
            select(TaskCompletion).where(
                TaskCompletion.task_id == task_id,
                TaskCompletion.challenge_day_id == day.id,
            )
        )
        if existing.scalar_one_or_none():
            return {
                "task_id": task_id,
                "day_complete": day.is_complete,
                "hp_delta": 0,
                "new_hp": profile.hp,
                "celebration": False,
                "challenge_completed": False,
                "reward_message": None,
            }

        completion = TaskCompletion(
            task_id=task_id,
            user_id=profile.id,
            challenge_day_id=day.id,
        )
        self.db.add(completion)
        await self.db.flush()

        active_tasks = [t for t in challenge.tasks if t.is_active]
        if challenge.status == ChallengeStatus.RECOVERY:
            active_tasks = [t for t in active_tasks if t.type == TaskType.FOUNDATION]

        completed_ids = await self.db.execute(
            select(TaskCompletion.task_id).where(TaskCompletion.challenge_day_id == day.id)
        )
        done = set(completed_ids.scalars().all())
        day_complete = all(t.id in done for t in active_tasks)

        hp_delta = 0
        celebration = False

        challenge_completed = False
        if day_complete and not day.is_complete:
            day.is_complete = True
            day.completed_at = utcnow()
            # Daily completion reward: HP + streak. Score updates via recompute.
            hp_delta = 10
            celebration = True
            profile.current_streak += 1
            profile.longest_streak = max(profile.longest_streak, profile.current_streak)
            day.hp_delta = hp_delta
            await self._add_hp(profile, challenge.id, hp_delta, "daily_complete")

            if challenge.status == ChallengeStatus.RECOVERY:
                challenge.status = ChallengeStatus.ACTIVE
                challenge.recovery_started_at = None
                challenge.consecutive_missed = 0

            # Do NOT advance current_day here — wait until the next calendar day
            # (after midnight) via sync_calendar_day.
            if challenge.current_day >= challenge.duration_days and day.is_complete:
                await self._complete_challenge(profile, challenge)
                challenge_completed = True

        await self.db.flush()

        if celebration and challenge.group_id:
            from app.services.group_service import GroupService

            group_service = GroupService(self.db)
            await group_service.record_activity(
                challenge.group_id,
                "task_complete",
                f"{profile.full_name} completed today's mission",
                profile.id,
            )
            if profile.current_streak in (7, 14, 21, 30):
                await group_service.record_activity(
                    challenge.group_id,
                    "streak_milestone",
                    f"{profile.full_name} reached a {profile.current_streak}-day streak",
                    profile.id,
                    {"streak": profile.current_streak},
                )

        return {
            "task_id": task_id,
            "day_complete": day_complete,
            "hp_delta": hp_delta,
            "new_hp": profile.hp,
            "celebration": celebration,
            "challenge_completed": challenge_completed,
            "reward_message": (
                "+10 HP for completing today's tasks"
                if celebration
                else None
            ),
        }

    async def sync_calendar_day(self, profile: Profile, challenge: Challenge) -> Challenge:
        """Advance challenge days only when the calendar date moves past midnight."""
        if challenge.status not in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            return challenge
        if not challenge.start_date:
            return challenge

        today = date.today()
        expected_day = (today - challenge.start_date).days + 1
        expected_day = max(1, min(expected_day, challenge.duration_days))

        while challenge.current_day < expected_day:
            day = await self.get_today_day(challenge)
            if day and not day.is_complete:
                challenge.consecutive_missed += 1
                profile.current_streak = 0
                await self._add_hp(profile, challenge.id, -15, "missed_day")
                if challenge.consecutive_missed >= challenge.max_missed_days:
                    if challenge.status != ChallengeStatus.RECOVERY:
                        challenge.status = ChallengeStatus.RECOVERY
                        challenge.recovery_started_at = utcnow()
                    else:
                        challenge.status = ChallengeStatus.FAILED
                        challenge.failed_at = utcnow()
                        await self.db.flush()
                        return challenge

            if challenge.current_day >= challenge.duration_days:
                if day and day.is_complete:
                    await self._complete_challenge(profile, challenge)
                break

            challenge.current_day += 1

        # Final day completed and calendar is past end → complete
        if (
            challenge.current_day >= challenge.duration_days
            and challenge.status == ChallengeStatus.ACTIVE
        ):
            day = await self.get_today_day(challenge)
            if day and day.is_complete and today > day.calendar_date:
                await self._complete_challenge(profile, challenge)

        await self.db.flush()
        return challenge

    async def recovery_check_in(self, profile: Profile, challenge_id: UUID) -> Challenge:
        result = await self.db.execute(
            select(Challenge).where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
        )
        challenge = result.scalar_one_or_none()
        if not challenge:
            raise NotFoundError("Challenge")
        if challenge.status != ChallengeStatus.RECOVERY:
            raise AppError("INVALID_STATE", "Not in recovery mode")
        challenge.consecutive_missed = 0
        await self.db.flush()
        return challenge

    async def _add_hp(
        self, profile: Profile, challenge_id: UUID, delta: int, reason: str
    ) -> None:
        profile.hp = max(0, profile.hp + delta)
        self.db.add(
            HpEvent(user_id=profile.id, challenge_id=challenge_id, delta=delta, reason=reason)
        )

    async def _complete_challenge(self, profile: Profile, challenge: Challenge) -> None:
        challenge.status = ChallengeStatus.COMPLETED
        challenge.completed_at = utcnow()
        profile.challenges_completed += 1

        cert_no = f"ILM-{utcnow().year}-{secrets.token_hex(3).upper()}"
        certificate = Certificate(
            user_id=profile.id,
            challenge_id=challenge.id,
            certificate_no=cert_no,
            title=challenge.name,
            duration_days=challenge.duration_days,
        )
        self.db.add(certificate)

        await self._award_badge(profile, BadgeCode.CONSISTENCY_MASTER, challenge.id)
        if challenge.duration_days >= 30:
            await self._award_badge(profile, BadgeCode.THIRTY_DAY_LEGEND, challenge.id)
        if profile.current_streak >= 7:
            await self._award_badge(profile, BadgeCode.SEVEN_DAY_STREAK, challenge.id)

    async def _award_badge(
        self, profile: Profile, code: BadgeCode, challenge_id: UUID | None = None
    ) -> None:
        badge_result = await self.db.execute(select(Badge).where(Badge.code == code))
        badge = badge_result.scalar_one_or_none()
        if not badge:
            return
        existing = await self.db.execute(
            select(UserBadge).where(
                UserBadge.user_id == profile.id, UserBadge.badge_id == badge.id
            )
        )
        if existing.scalar_one_or_none():
            return
        self.db.add(UserBadge(user_id=profile.id, badge_id=badge.id, challenge_id=challenge_id))

    async def build_detail(self, profile: Profile, challenge: Challenge) -> dict:
        if challenge.status in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            await self.sync_calendar_day(profile, challenge)
        day = await self.get_today_day(challenge)
        completed_result = await self.db.execute(
            select(TaskCompletion.task_id).where(TaskCompletion.challenge_day_id == day.id)
        )
        completed_ids = set(completed_result.scalars().all())

        tasks = []
        for t in sorted(challenge.tasks, key=lambda x: x.sort_order):
            if not t.is_active:
                continue
            if challenge.status == ChallengeStatus.RECOVERY and t.type != TaskType.FOUNDATION:
                continue
            tasks.append(
                {
                    "id": t.id,
                    "title": t.title,
                    "type": t.type.value,
                    "sort_order": t.sort_order,
                    "is_completed": t.id in completed_ids,
                }
            )

        incomplete_any = next((t for t in tasks if not t["is_completed"]), None)
        if incomplete_any:
            today_mission = f"Complete: {incomplete_any['title']}"
        elif day.is_complete:
            today_mission = "All tasks done today — next day unlocks after midnight"
        else:
            today_mission = "All tasks done today"

        quote_idx = (profile.id.int % len(QUOTES) + challenge.current_day) % len(QUOTES)
        quote_text, quote_author = QUOTES[quote_idx]
        quote = f'"{quote_text}" — {quote_author}'

        recovery_hours = None
        if challenge.status == ChallengeStatus.RECOVERY and challenge.recovery_started_at:
            started = as_utc(challenge.recovery_started_at)
            elapsed = utcnow() - started
            recovery_hours = max(0, 24 - elapsed.total_seconds() / 3600)

        completed_days = sum(1 for d in challenge.days if d.is_complete)
        remaining = max(0, challenge.duration_days - challenge.current_day + (0 if day.is_complete else 1))
        progress = (completed_days / challenge.duration_days) * 100

        rank_result = await self.db.execute(
            select(func.count())
            .select_from(Profile)
            .where(Profile.discipline_score > profile.discipline_score, Profile.is_deleted.is_(False))
        )
        rank = (rank_result.scalar() or 0) + 1

        today = date.today()
        days_payload = []
        for d in sorted(challenge.days, key=lambda x: x.day_number):
            is_future = d.calendar_date > today
            is_missed = d.calendar_date < today and not d.is_complete
            is_locked = is_future or d.day_number > challenge.current_day
            if challenge.status in (ChallengeStatus.COMPLETED, ChallengeStatus.FAILED):
                is_locked = False
            days_payload.append(
                {
                    "day_number": d.day_number,
                    "calendar_date": d.calendar_date.isoformat(),
                    "is_complete": d.is_complete,
                    "is_missed": is_missed,
                    "is_today": d.day_number == challenge.current_day,
                    "is_locked": is_locked,
                }
            )

        return {
            "id": challenge.id,
            "name": challenge.name,
            "type": challenge.type.value,
            "duration_days": challenge.duration_days,
            "status": challenge.status.value,
            "start_date": challenge.start_date,
            "current_day": challenge.current_day,
            "consecutive_missed": challenge.consecutive_missed,
            "is_first_free": challenge.is_first_free,
            "completed_at": challenge.completed_at,
            "failed_at": challenge.failed_at,
            "progress_percent": round(progress, 1),
            "remaining_days": remaining,
            "today_mission": today_mission,
            "quote": quote,
            "leaderboard_position": rank,
            "tasks": tasks,
            "recovery_hours_left": recovery_hours,
            "days": days_payload,
            "day_complete": day.is_complete,
        }

    async def build_day_history(self, challenge: Challenge, day_number: int) -> dict:
        day = next((d for d in challenge.days if d.day_number == day_number), None)
        if not day:
            raise NotFoundError("Challenge day")

        today = date.today()
        is_locked = day.calendar_date > today or day_number > challenge.current_day
        if challenge.status == ChallengeStatus.COMPLETED:
            is_locked = False

        completed_result = await self.db.execute(
            select(TaskCompletion.task_id).where(TaskCompletion.challenge_day_id == day.id)
        )
        completed_ids = set(completed_result.scalars().all())

        tasks = []
        for t in sorted(challenge.tasks, key=lambda x: x.sort_order):
            if not t.is_active:
                continue
            tasks.append(
                {
                    "id": t.id,
                    "title": t.title,
                    "type": t.type.value,
                    "sort_order": t.sort_order,
                    "is_completed": t.id in completed_ids,
                }
            )

        return {
            "day_number": day.day_number,
            "calendar_date": day.calendar_date.isoformat(),
            "is_complete": day.is_complete,
            "is_missed": day.calendar_date < today and not day.is_complete,
            "is_today": day.day_number == challenge.current_day,
            "is_locked": is_locked,
            "tasks": [] if is_locked else tasks,
            "hp_delta": day.hp_delta,
        }


class DisciplineScoreService:
    @staticmethod
    async def recompute(db: AsyncSession, profile: Profile) -> int:
        """Score starts at 0 and is earned from real activity only."""
        result = await db.execute(
            select(func.count())
            .select_from(Challenge)
            .where(Challenge.user_id == profile.id, Challenge.status == ChallengeStatus.COMPLETED)
        )
        completed = result.scalar() or 0

        result = await db.execute(
            select(func.count())
            .select_from(Challenge)
            .where(Challenge.user_id == profile.id, Challenge.status == ChallengeStatus.FAILED)
        )
        failed = result.scalar() or 0

        # Count fully completed challenge days (daily completion reward base).
        days_result = await db.execute(
            select(func.count())
            .select_from(ChallengeDay)
            .join(Challenge, Challenge.id == ChallengeDay.challenge_id)
            .where(Challenge.user_id == profile.id, ChallengeDay.is_complete.is_(True))
        )
        completed_days = days_result.scalar() or 0

        score = 0
        score += min(completed_days * 5, 400)  # earned from finishing days
        score += min(completed * 40, 200)  # finishing whole challenges
        score += min(profile.perfect_weeks * 10, 100)
        score += min(profile.longest_streak * 3, 120)
        score -= failed * 30
        score = max(0, min(1000, score))
        profile.discipline_score = score
        return score


class PaymentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_intent(self, profile: Profile, challenge_id: UUID | None = None) -> Payment:
        key = f"{profile.id}-{challenge_id or 'new'}-{secrets.token_hex(4)}"
        payment = Payment(
            user_id=profile.id,
            amount_uzs=settings.challenge_price_uzs,
            status=PaymentStatus.PENDING,
            idempotency_key=key,
        )
        self.db.add(payment)
        await self.db.flush()

        if challenge_id:
            result = await self.db.execute(
                select(Challenge).where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
            )
            challenge = result.scalar_one_or_none()
            if challenge:
                challenge.payment_id = payment.id

        return payment

    async def complete_payment(self, payment_id: UUID, provider_ref: str) -> Payment:
        result = await self.db.execute(select(Payment).where(Payment.id == payment_id))
        payment = result.scalar_one_or_none()
        if not payment:
            raise NotFoundError("Payment")
        if payment.status == PaymentStatus.COMPLETED:
            return payment

        payment.status = PaymentStatus.COMPLETED
        payment.provider_ref = provider_ref
        payment.completed_at = utcnow()

        challenge_result = await self.db.execute(
            select(Challenge).where(Challenge.payment_id == payment.id)
        )
        challenge = challenge_result.scalar_one_or_none()
        if challenge and challenge.status == ChallengeStatus.PENDING_PAYMENT:
            challenge.status = ChallengeStatus.ACTIVE
            challenge.start_date = date.today()
            challenge.current_day = 1

        await self.db.flush()
        return payment


def generate_invite_code(length: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

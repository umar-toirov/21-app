import secrets
import string
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AppError, ConflictError, ForbiddenError, NotFoundError
from app.core.security import app_today, as_utc, utcnow
from app.models.profile import (
    Badge,
    BadgeCode,
    Certificate,
    Challenge,
    ChallengeDay,
    ChallengeStatus,
    ChallengeType,
    Goal,
    Group,
    HpEvent,
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

MAX_PERSONAL_TASKS = 10

# Points: every task earns points immediately, a perfect day adds a bonus,
# and a missed day costs points (and resets the streak).
TASK_POINTS = 5
DAY_BONUS_POINTS = 10
MISSED_DAY_PENALTY = 15
MAX_START_AHEAD_DAYS = 60

QUOTES = [
    ("Discipline is choosing between what you want now and what you want most.", "Abraham Lincoln"),
    ("We are what we repeatedly do. Excellence, then, is not an act, but a habit.", "Aristotle"),
    ("Discipline weighs ounces while regret weighs tons.", "Jim Rohn"),
    ("Habits are the compound interest of self-improvement.", "James Clear"),
    ("Motivation is what gets you started. Habit is what keeps you going.", "Jim Ryun"),
    ("We first make our habits, and then our habits make us.", "John Dryden"),
    ("Success is the sum of small efforts, repeated day in and day out.", "Robert Collier"),
    ("It does not matter how slowly you go as long as you do not stop.", "Confucius"),
]


class ChallengeService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_active_challenge(self, user_id: UUID) -> Challenge | None:
        """Return the active PERSONAL challenge (legacy / single-active callers)."""
        return await self.get_active_challenge_by_type(user_id, ChallengeType.INDIVIDUAL)

    async def get_active_challenge_by_type(
        self, user_id: UUID, challenge_type: ChallengeType
    ) -> Challenge | None:
        result = await self.db.execute(
            select(Challenge)
            .where(
                Challenge.user_id == user_id,
                Challenge.type == challenge_type,
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

    async def get_active_programs(self, user_id: UUID) -> dict:
        personal = await self.get_active_challenge_by_type(user_id, ChallengeType.INDIVIDUAL)
        group = await self.get_active_challenge_by_type(user_id, ChallengeType.GROUP)
        profile_result = await self.db.execute(select(Profile).where(Profile.id == user_id))
        profile = profile_result.scalar_one()
        return {
            "personal": await self.build_detail(profile, personal) if personal else None,
            "group": await self.build_detail(profile, group) if group else None,
        }

    async def create_from_onboarding(self, profile: Profile) -> Challenge:
        data = profile.onboarding_data or {}
        raw_start = data.get("start_date")
        return await self.create_personal_challenge(
            profile,
            name=data.get("name"),
            goal_slug=data.get("goal", "other"),
            duration_days=int(data.get("duration_days", 21)),
            personal_tasks=list(data.get("personal_tasks", [])),
            include_foundation=bool(data.get("include_foundation", True)),
            start_date=date.fromisoformat(raw_start) if raw_start else None,
        )

    async def create_personal_challenge(
        self,
        profile: Profile,
        *,
        name: str | None,
        goal_slug: str,
        duration_days: int,
        personal_tasks: list[str],
        include_foundation: bool = True,
        start_date: date | None = None,
    ) -> Challenge:
        """Create the user's personal challenge, starting today or on a later date."""
        active_result = await self.db.execute(
            select(Challenge.id)
            .where(
                Challenge.user_id == profile.id,
                Challenge.type == ChallengeType.INDIVIDUAL,
                Challenge.status.in_([ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY]),
            )
            .limit(1)
        )
        if active_result.scalar_one_or_none():
            raise ConflictError(
                "Finish or leave your current personal challenge before starting another one"
            )

        if not 7 <= duration_days <= 90:
            raise AppError("VALIDATION", "Duration must be between 7 and 90 days")

        tasks: list[str] = []
        seen: set[str] = set()
        for raw in personal_tasks:
            title = (raw or "").strip()[:255]
            if title and title.lower() not in seen:
                seen.add(title.lower())
                tasks.append(title)
        if len(tasks) < 2:
            raise AppError("VALIDATION", "Select at least 2 personal tasks")
        if len(tasks) > MAX_PERSONAL_TASKS:
            raise AppError("VALIDATION", f"Choose at most {MAX_PERSONAL_TASKS} personal tasks")

        today = app_today()
        start = start_date or today
        if start < today:
            start = today  # a client a day behind/ahead of the server clock still starts today
        if start > today + timedelta(days=MAX_START_AHEAD_DAYS):
            raise AppError(
                "VALIDATION", f"Start date can be at most {MAX_START_AHEAD_DAYS} days ahead"
            )

        existing = await self.db.execute(
            select(func.count())
            .select_from(Challenge)
            .where(Challenge.user_id == profile.id, Challenge.type == ChallengeType.INDIVIDUAL)
        )
        is_first_free = (existing.scalar() or 0) == 0

        goal_result = await self.db.execute(select(Goal).where(Goal.slug == goal_slug))
        goal = goal_result.scalar_one_or_none()

        challenge_name = (name or "").strip() or (
            f"{goal.name if goal else 'Personal'} {duration_days}-Day Discipline"
        )

        challenge = Challenge(
            user_id=profile.id,
            goal_id=goal.id if goal else None,
            name=challenge_name[:255],
            type=ChallengeType.INDIVIDUAL,
            duration_days=duration_days,
            status=ChallengeStatus.ACTIVE,
            start_date=start,
            current_day=1,
            is_first_free=is_first_free,
        )
        self.db.add(challenge)
        await self.db.flush()

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

        for i, title in enumerate(tasks):
            self.db.add(
                Task(
                    challenge_id=challenge.id,
                    title=title,
                    type=TaskType.PERSONAL,
                    sort_order=sort_base + i,
                )
            )

        for day_num in range(1, duration_days + 1):
            self.db.add(
                ChallengeDay(
                    challenge_id=challenge.id,
                    day_number=day_num,
                    calendar_date=start + timedelta(days=day_num - 1),
                )
            )

        profile.onboarding_step = 6
        await self.db.flush()
        return challenge

    async def cancel_challenge(self, profile: Profile, challenge_id: UUID) -> Challenge:
        """Stop a personal challenge. Points already earned are kept."""
        result = await self.db.execute(
            select(Challenge).where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
        )
        challenge = result.scalar_one_or_none()
        if not challenge:
            raise NotFoundError("Challenge")
        if challenge.type == ChallengeType.GROUP:
            raise AppError(
                "USE_LEAVE_GROUP", "This is a group challenge. Leave the group instead."
            )
        if challenge.status not in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            raise AppError("INVALID_STATE", "Only a running challenge can be cancelled")
        challenge.status = ChallengeStatus.ARCHIVED
        challenge.updated_at = utcnow()
        await self.db.flush()
        return challenge

    async def activity_for_month(self, user_id: UUID, year: int, month: int) -> dict:
        """Everything the user did (and missed) in a calendar month, for the home calendar."""
        first = date(year, month, 1)
        last = (date(year + (month == 12), (month % 12) + 1, 1)) - timedelta(days=1)
        today = app_today()

        done_rows = (
            await self.db.execute(
                select(
                    ChallengeDay.calendar_date,
                    Task.title,
                    Task.type,
                    Challenge.name,
                    Challenge.type,
                    TaskCompletion.completed_at,
                )
                .select_from(TaskCompletion)
                .join(ChallengeDay, ChallengeDay.id == TaskCompletion.challenge_day_id)
                .join(Task, Task.id == TaskCompletion.task_id)
                .join(Challenge, Challenge.id == ChallengeDay.challenge_id)
                .where(
                    TaskCompletion.user_id == user_id,
                    ChallengeDay.calendar_date >= first,
                    ChallengeDay.calendar_date <= last,
                )
                .order_by(ChallengeDay.calendar_date, TaskCompletion.completed_at)
            )
        ).all()

        day_rows = (
            await self.db.execute(
                select(ChallengeDay.calendar_date, ChallengeDay.is_complete)
                .join(Challenge, Challenge.id == ChallengeDay.challenge_id)
                .where(
                    Challenge.user_id == user_id,
                    Challenge.status.in_(
                        [
                            ChallengeStatus.ACTIVE,
                            ChallengeStatus.RECOVERY,
                            ChallengeStatus.COMPLETED,
                            ChallengeStatus.FAILED,
                        ]
                    ),
                    ChallengeDay.calendar_date >= first,
                    ChallengeDay.calendar_date <= last,
                )
            )
        ).all()

        days: dict[date, dict] = {}

        def entry(d: date) -> dict:
            return days.setdefault(d, {"scheduled": 0, "complete": 0, "tasks": []})

        for d, complete in day_rows:
            e = entry(d)
            e["scheduled"] += 1
            e["complete"] += 1 if complete else 0
        for d, title, task_type, challenge_name, challenge_type, completed_at in done_rows:
            entry(d)["tasks"].append(
                {
                    "title": title,
                    "kind": "group" if challenge_type == ChallengeType.GROUP else "personal",
                    "challenge": challenge_name,
                    "completed_at": as_utc(completed_at).isoformat() if completed_at else None,
                }
            )

        out = []
        for d in sorted(days):
            e = days[d]
            done = len(e["tasks"])
            if e["scheduled"] and e["complete"] == e["scheduled"]:
                status = "done"
            elif d > today:
                status = "upcoming"
            elif done > 0:
                status = "partial"
            elif d < today and e["scheduled"]:
                status = "missed"
            elif e["scheduled"]:
                status = "pending"
            else:
                status = "partial" if done else "none"
            out.append({"date": d.isoformat(), "status": status, "done": done, "tasks": e["tasks"]})

        return {
            "month": f"{year:04d}-{month:02d}",
            "days": out,
            "totals": {
                "tasks_done": len(done_rows),
                "perfect_days": sum(1 for x in out if x["status"] == "done"),
                "missed_days": sum(1 for x in out if x["status"] == "missed"),
            },
        }

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

    async def add_personal_task(
        self, profile: Profile, challenge_id: UUID, title: str
    ) -> Task:
        clean = (title or "").strip()
        if not clean:
            raise AppError("VALIDATION", "Task title is required")

        result = await self.db.execute(
            select(Challenge)
            .where(Challenge.id == challenge_id, Challenge.user_id == profile.id)
            .options(selectinload(Challenge.tasks))
        )
        challenge = result.scalar_one_or_none()
        if not challenge:
            raise NotFoundError("Challenge")
        if challenge.type != ChallengeType.GROUP:
            raise AppError("INVALID", "Only group challenges support adding personal tasks here")
        if challenge.status not in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            raise AppError("INVALID_STATE", "Challenge is not active")
        if (challenge.current_day or 0) > 1:
            raise AppError("LOCKED", "Personal tasks can only be added on Day 1")
        if not challenge.group_id:
            raise AppError("INVALID", "Challenge is not linked to a group")

        group_result = await self.db.execute(
            select(Group).where(Group.id == challenge.group_id)
        )
        group = group_result.scalar_one_or_none()
        if not group:
            raise NotFoundError("Group")
        task_mode = getattr(group, "task_mode", None) or "shared"
        if task_mode != "freedom":
            raise ForbiddenError("This group uses shared tasks only")

        max_order = max((t.sort_order for t in challenge.tasks), default=-1)
        task = Task(
            challenge_id=challenge.id,
            title=clean,
            type=TaskType.PERSONAL,
            sort_order=max_order + 1,
        )
        self.db.add(task)
        await self.db.flush()
        return task

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

        if self._days_until_start(challenge) > 0:
            raise AppError(
                "NOT_STARTED",
                f"This challenge starts on {challenge.start_date:%b} {challenge.start_date.day}",
            )

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

        # Every completed task earns points right away.
        hp_delta = TASK_POINTS
        day.hp_delta = (day.hp_delta or 0) + TASK_POINTS
        await self._add_hp(profile, challenge.id, TASK_POINTS, "task_complete")

        active_tasks = [t for t in challenge.tasks if t.is_active]
        if challenge.status == ChallengeStatus.RECOVERY:
            active_tasks = [t for t in active_tasks if t.type == TaskType.FOUNDATION]

        completed_ids = await self.db.execute(
            select(TaskCompletion.task_id).where(TaskCompletion.challenge_day_id == day.id)
        )
        done = set(completed_ids.scalars().all())
        day_complete = all(t.id in done for t in active_tasks)

        celebration = False

        challenge_completed = False
        if day_complete and not day.is_complete:
            day.is_complete = True
            day.completed_at = utcnow()
            # Perfect-day bonus + streak. Score updates via recompute.
            celebration = True
            profile.current_streak += 1
            profile.longest_streak = max(profile.longest_streak, profile.current_streak)
            hp_delta += DAY_BONUS_POINTS
            day.hp_delta = (day.hp_delta or 0) + DAY_BONUS_POINTS
            await self._add_hp(profile, challenge.id, DAY_BONUS_POINTS, "daily_complete")

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
                f"+{hp_delta} points · perfect day"
                if celebration
                else f"+{hp_delta} points"
            ),
        }

    @staticmethod
    def _days_until_start(challenge: Challenge) -> int:
        """Whole days until a personal challenge begins (0 once it has started)."""
        if challenge.type != ChallengeType.INDIVIDUAL or not challenge.start_date:
            return 0
        return max(0, (challenge.start_date - app_today()).days)

    async def sync_calendar_day(self, profile: Profile, challenge: Challenge) -> Challenge:
        """Advance challenge days only when the calendar date moves past midnight."""
        if challenge.status not in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
            return challenge
        if not challenge.start_date:
            return challenge

        today = app_today()
        expected_day = (today - challenge.start_date).days + 1
        expected_day = max(1, min(expected_day, challenge.duration_days))

        while challenge.current_day < expected_day:
            day = await self.get_today_day(challenge)
            if day and not day.is_complete:
                challenge.consecutive_missed += 1
                profile.current_streak = 0
                await self._add_hp(
                    profile, challenge.id, -MISSED_DAY_PENALTY, "missed_day"
                )
                # Transient (not stored): lets the API tell the user what just happened.
                challenge._sync_penalty = (
                    getattr(challenge, "_sync_penalty", 0) + MISSED_DAY_PENALTY
                )
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

        days_until_start = self._days_until_start(challenge)
        if days_until_start > 0:
            today_mission = (
                f"Starts {challenge.start_date:%b} {challenge.start_date.day} "
                f"(in {days_until_start} day{'s' if days_until_start != 1 else ''})"
            )

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

        today = app_today()
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
            "group_id": challenge.group_id,
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
            "days_until_start": days_until_start,
            "points_today": day.hp_delta or 0,
            "penalty_points": getattr(challenge, "_sync_penalty", 0),
        }

    async def build_day_history(self, challenge: Challenge, day_number: int) -> dict:
        day = next((d for d in challenge.days if d.day_number == day_number), None)
        if not day:
            raise NotFoundError("Challenge day")

        today = app_today()
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


def generate_invite_code(length: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

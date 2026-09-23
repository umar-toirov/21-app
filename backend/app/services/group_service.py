from datetime import date, timedelta
from statistics import mean
from uuid import UUID

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AppError, ConflictError, ForbiddenError, NotFoundError
from app.core.security import app_today, as_utc, utcnow
from app.models.profile import (
    Announcement,
    Challenge,
    ChallengeDay,
    ChallengeStatus,
    ChallengeType,
    Group,
    GroupActivity,
    GroupActivityType,
    GroupMember,
    GroupMemberRole,
    GroupMessage,
    GroupSession,
    HpEvent,
    Profile,
    Task,
    TaskCompletion,
    TaskType,
)
from app.services.challenge_service import ChallengeService, generate_invite_code

MAX_GROUP_TASKS = 15
MAX_OWN_TASKS = 10
MAX_MESSAGES_PER_MINUTE = 15


def _clean_titles(raw: list[str] | None, limit: int) -> list[str]:
    """Trim, drop blanks and case-insensitive duplicates, cap the count."""
    out: list[str] = []
    seen: set[str] = set()
    for item in raw or []:
        title = (item or "").strip()[:255]
        if title and title.lower() not in seen:
            seen.add(title.lower())
            out.append(title)
    return out[:limit]


class GroupService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.challenge_service = ChallengeService(db)

    async def _archive_active_group_challenges(self, user_id: UUID) -> int:
        """Archive active/recovery GROUP challenges only — keep personal running."""
        result = await self.db.execute(
            select(Challenge).where(
                Challenge.user_id == user_id,
                Challenge.type == ChallengeType.GROUP,
                Challenge.status.in_(
                    [ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY]
                ),
            )
        )
        archived = 0
        for challenge in result.scalars().all():
            challenge.status = ChallengeStatus.ARCHIVED
            challenge.recovery_started_at = None
            archived += 1
        if archived:
            await self.db.flush()
        return archived

    async def record_activity(
        self,
        group_id: UUID,
        activity_type: str,
        message: str,
        user_id: UUID | None = None,
        metadata: dict | None = None,
    ) -> GroupActivity:
        activity = GroupActivity(
            group_id=group_id,
            user_id=user_id,
            activity_type=activity_type,
            message=message,
            extra=metadata or {},
        )
        self.db.add(activity)
        await self.db.flush()
        return activity

    async def _group_task_titles(self, group_id: UUID) -> list[str]:
        """The tasks the admin set for everyone (stored on each member's challenge
        as FOUNDATION-type tasks; the app calls them "group tasks")."""
        result = await self.db.execute(select(Group).where(Group.id == group_id))
        group = result.scalar_one_or_none()
        if not group:
            return []
        challenge_result = await self.db.execute(
            select(Challenge)
            .where(Challenge.group_id == group_id, Challenge.user_id == group.leader_id)
            .options(selectinload(Challenge.tasks))
        )
        challenge = challenge_result.scalar_one_or_none()
        if not challenge:
            return []
        return [
            t.title
            for t in sorted(challenge.tasks, key=lambda x: x.sort_order)
            if t.type == TaskType.FOUNDATION and t.is_active
        ]

    async def _create_member_challenge(
        self,
        user: Profile,
        group: Group,
        foundation_tasks: list[str],
        personal_tasks: list[str] | None = None,
    ) -> Challenge:
        challenge = Challenge(
            user_id=user.id,
            name=f"{group.name} Group Challenge",
            type=ChallengeType.GROUP,
            duration_days=group.duration_days,
            status=ChallengeStatus.ACTIVE,
            start_date=group.starts_at,
            current_day=max(1, (app_today() - group.starts_at).days + 1),
            group_id=group.id,
        )
        self.db.add(challenge)
        await self.db.flush()

        for i, title in enumerate(foundation_tasks):
            self.db.add(
                Task(
                    challenge_id=challenge.id,
                    title=title,
                    type=TaskType.FOUNDATION,
                    sort_order=i,
                )
            )

        personal = [t.strip() for t in (personal_tasks or []) if t and t.strip()]
        sort_base = len(foundation_tasks)
        for i, title in enumerate(personal):
            self.db.add(
                Task(
                    challenge_id=challenge.id,
                    title=title,
                    type=TaskType.PERSONAL,
                    sort_order=sort_base + i,
                )
            )

        start = group.starts_at
        for day_num in range(1, group.duration_days + 1):
            self.db.add(
                ChallengeDay(
                    challenge_id=challenge.id,
                    day_number=day_num,
                    calendar_date=start + timedelta(days=day_num - 1),
                )
            )
        await self.db.flush()
        return challenge

    async def _check_name_available(self, name: str, exclude_group_id: UUID | None = None) -> None:
        """Group names are unique (case-insensitive) among active groups. An
        ended group's name is freed up for reuse."""
        query = select(Group).where(
            func.lower(Group.name) == name.strip().lower(), Group.status == "active"
        )
        if exclude_group_id is not None:
            query = query.where(Group.id != exclude_group_id)
        existing = (await self.db.execute(query)).scalar_one_or_none()
        if existing:
            raise ConflictError("That group name is already taken. Try another one.")

    async def create_group(self, leader: Profile, data: dict) -> Group:
        await self._check_name_available(data["name"])
        await self._archive_active_group_challenges(leader.id)
        invite_code = generate_invite_code()
        while True:
            existing = await self.db.execute(select(Group).where(Group.invite_code == invite_code))
            if not existing.scalar_one_or_none():
                break
            invite_code = generate_invite_code()

        task_mode = data.get("task_mode") or "shared"
        if task_mode not in ("shared", "freedom"):
            raise AppError("VALIDATION", "task_mode must be 'shared' or 'freedom'")

        group_tasks = _clean_titles(
            data.get("group_tasks") or data.get("foundation_tasks"), MAX_GROUP_TASKS
        )
        own_tasks = _clean_titles(data.get("personal_tasks"), MAX_OWN_TASKS)
        if task_mode == "shared" and not group_tasks:
            raise AppError("VALIDATION", "Add at least one task for the group")
        if task_mode == "freedom" and not own_tasks and not group_tasks:
            raise AppError("VALIDATION", "Add at least one task for yourself or for the group")

        group = Group(
            leader_id=leader.id,
            name=data["name"].strip(),
            invite_code=invite_code,
            duration_days=data["duration_days"],
            max_missed_days=data.get("max_missed_days", 3),
            penalty_rules=data.get("penalty_rules") or {},
            task_mode=task_mode,
            is_public=bool(data.get("is_public", False)),
            starts_at=data["starts_at"],
        )
        self.db.add(group)
        await self.db.flush()

        self.db.add(
            GroupMember(group_id=group.id, user_id=leader.id, role=GroupMemberRole.LEADER)
        )

        await self._create_member_challenge(
            leader,
            group,
            group_tasks,
            personal_tasks=own_tasks if task_mode == "freedom" else None,
        )

        await self.record_activity(
            group.id,
            GroupActivityType.MEMBER_JOINED.value,
            f"{leader.full_name} created the group",
            leader.id,
        )
        await self.db.flush()
        return group

    async def preview_by_invite_code(self, invite_code: str) -> dict:
        result = await self.db.execute(
            select(Group).where(Group.invite_code == invite_code.upper())
        )
        group = result.scalar_one_or_none()
        if not group:
            raise NotFoundError("Group")
        if group.status != "active":
            raise AppError("GROUP_INACTIVE", "This group is no longer active")

        group_tasks = await self._group_task_titles(group.id)
        leader = (
            await self.db.execute(select(Profile).where(Profile.id == group.leader_id))
        ).scalar_one_or_none()
        member_count = (
            await self.db.execute(
                select(func.count()).select_from(GroupMember).where(GroupMember.group_id == group.id)
            )
        ).scalar() or 0
        return {
            "name": group.name,
            "duration_days": group.duration_days,
            "task_mode": getattr(group, "task_mode", None) or "shared",
            "group_tasks": group_tasks,
            "foundation_tasks": group_tasks,
            "starts_at": group.starts_at,
            "max_missed_days": group.max_missed_days,
            "leader_name": leader.full_name if leader else None,
            "member_count": member_count,
        }

    async def join_group(
        self,
        user: Profile,
        invite_code: str,
        personal_tasks: list[str] | None = None,
    ) -> Group:
        result = await self.db.execute(select(Group).where(Group.invite_code == invite_code.upper()))
        group = result.scalar_one_or_none()
        if not group:
            raise NotFoundError("Group")
        return await self._join_resolved_group(user, group, personal_tasks)

    async def join_public_group(
        self,
        user: Profile,
        group_id: UUID,
        personal_tasks: list[str] | None = None,
    ) -> Group:
        """Join a public group directly by id — no invite code needed."""
        result = await self.db.execute(select(Group).where(Group.id == group_id))
        group = result.scalar_one_or_none()
        if not group:
            raise NotFoundError("Group")
        if not getattr(group, "is_public", False):
            raise ForbiddenError("This group is invite-only. Ask the admin for an invite code.")
        return await self._join_resolved_group(user, group, personal_tasks)

    async def _join_resolved_group(
        self,
        user: Profile,
        group: Group,
        personal_tasks: list[str] | None = None,
    ) -> Group:
        if group.status != "active":
            raise AppError("GROUP_INACTIVE", "This group is no longer active")

        existing = await self.db.execute(
            select(GroupMember).where(
                GroupMember.group_id == group.id, GroupMember.user_id == user.id
            )
        )
        if existing.scalar_one_or_none():
            return group

        await self._archive_active_group_challenges(user.id)

        member_count = await self.db.execute(
            select(func.count()).select_from(GroupMember).where(GroupMember.group_id == group.id)
        )
        if (member_count.scalar() or 0) >= 100:
            raise AppError("GROUP_FULL", "Group has reached maximum capacity")

        task_mode = getattr(group, "task_mode", None) or "shared"
        group_tasks = await self._group_task_titles(group.id)
        own_tasks = _clean_titles(personal_tasks, MAX_OWN_TASKS)
        if task_mode == "freedom" and not own_tasks and not group_tasks:
            raise AppError(
                "VALIDATION",
                "This group lets members choose their own tasks. Pick at least one.",
            )

        self.db.add(GroupMember(group_id=group.id, user_id=user.id, role=GroupMemberRole.MEMBER))

        await self._create_member_challenge(
            user,
            group,
            group_tasks,
            personal_tasks=own_tasks if task_mode == "freedom" else None,
        )

        await self.record_activity(
            group.id,
            GroupActivityType.MEMBER_JOINED.value,
            f"{user.full_name} joined the group",
            user.id,
        )
        await self.db.flush()
        return group

    async def list_public_groups(self, user_id: UUID) -> list[dict]:
        """Active public groups, for the Discover list."""
        result = await self.db.execute(
            select(Group).where(Group.is_public.is_(True), Group.status == "active")
            .order_by(Group.created_at.desc())
        )
        groups = result.scalars().all()

        my_group_ids: set = set()
        if groups:
            my_rows = await self.db.execute(
                select(GroupMember.group_id).where(
                    GroupMember.user_id == user_id,
                    GroupMember.group_id.in_([g.id for g in groups]),
                )
            )
            my_group_ids = {row[0] for row in my_rows.all()}

        output = []
        for g in groups:
            leader = (
                await self.db.execute(select(Profile).where(Profile.id == g.leader_id))
            ).scalar_one_or_none()
            member_count = (
                await self.db.execute(
                    select(func.count()).select_from(GroupMember).where(GroupMember.group_id == g.id)
                )
            ).scalar() or 0
            output.append(
                {
                    "id": g.id,
                    "name": g.name,
                    "duration_days": g.duration_days,
                    "task_mode": getattr(g, "task_mode", None) or "shared",
                    "group_tasks": await self._group_task_titles(g.id),
                    "starts_at": g.starts_at,
                    "max_missed_days": g.max_missed_days,
                    "leader_name": leader.full_name if leader else None,
                    "member_count": member_count,
                    "is_member": g.id in my_group_ids,
                }
            )
        return output

    async def get_user_groups(self, user_id: UUID) -> list[dict]:
        result = await self.db.execute(
            select(Group)
            .join(GroupMember)
            .where(GroupMember.user_id == user_id, Group.status == "active")
            .options(selectinload(Group.members))
        )
        groups = result.scalars().all()
        output = []
        for g in groups:
            today_pct = await self._group_today_completion(g.id)
            output.append(
                {
                    "id": g.id,
                    "name": g.name,
                    "invite_code": g.invite_code,
                    "duration_days": g.duration_days,
                    "max_missed_days": g.max_missed_days,
                    "starts_at": g.starts_at,
                    "status": g.status,
                    "task_mode": getattr(g, "task_mode", None) or "shared",
                    "member_count": len(g.members),
                    "today_completion_percent": today_pct,
                    "current_day": max(1, (app_today() - g.starts_at).days + 1),
                }
            )
        return output

    async def _group_today_completion(self, group_id: UUID) -> float:
        members = await self._build_members_data(group_id, None)
        if not members:
            return 0.0
        done = sum(1 for m in members if m["today_complete"])
        return round(done / len(members) * 100, 1)

    async def _ensure_membership(self, group_id: UUID, user_id: UUID) -> tuple[Group, GroupMember, bool]:
        result = await self.db.execute(select(Group).where(Group.id == group_id))
        group = result.scalar_one_or_none()
        if not group:
            raise NotFoundError("Group")

        member_result = await self.db.execute(
            select(GroupMember).where(
                GroupMember.group_id == group_id,
                GroupMember.user_id == user_id,
            )
        )
        member = member_result.scalar_one_or_none()

        if not member and str(group.leader_id).replace("-", "") == str(user_id).replace("-", ""):
            member = GroupMember(
                group_id=group.id,
                user_id=user_id,
                role=GroupMemberRole.LEADER,
            )
            self.db.add(member)
            await self.db.flush()

        if not member:
            all_members = await self.db.execute(
                select(GroupMember).where(GroupMember.group_id == group_id)
            )
            req = str(user_id).replace("-", "").lower()
            for gm in all_members.scalars().all():
                if str(gm.user_id).replace("-", "").lower() == req:
                    member = gm
                    break

        if not member:
            raise ForbiddenError("Not a group member")

        is_leader = (
            member.role == GroupMemberRole.LEADER
            or str(member.role).lower() in ("leader", "groupmemberrole.leader")
            or str(group.leader_id).replace("-", "") == str(user_id).replace("-", "")
        )
        return group, member, is_leader

    async def _build_members_data(
        self, group_id: UUID, requester_id: UUID | None
    ) -> list[dict]:
        group_result = await self.db.execute(select(Group).where(Group.id == group_id))
        group = group_result.scalar_one_or_none()
        if not group:
            return []

        members_result = await self.db.execute(
            select(GroupMember).where(GroupMember.group_id == group_id)
        )
        group_members = list(members_result.scalars().all())

        members_data = []
        for gm in group_members:
            profile_result = await self.db.execute(
                select(Profile).where(Profile.id == gm.user_id)
            )
            profile = profile_result.scalar_one_or_none()
            if not profile:
                continue

            challenge_result = await self.db.execute(
                select(Challenge)
                .where(Challenge.group_id == group.id, Challenge.user_id == gm.user_id)
                .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
            )
            challenge = challenge_result.scalar_one_or_none()
            today_complete = False
            progress = 0.0
            current_day = 1
            missed_days = 0
            perfect_days = 0
            in_recovery = False
            group_points = 0
            if challenge:
                try:
                    if not challenge.days:
                        await self._ensure_group_days(challenge)
                        await self.db.refresh(challenge, attribute_names=["days"])
                    if challenge.current_day < 1:
                        challenge.current_day = 1
                    detail = await self.challenge_service.build_detail(profile, challenge)
                    today_complete = bool(detail.get("day_complete")) or (
                        all(t["is_completed"] for t in detail["tasks"]) if detail["tasks"] else False
                    )
                    progress = float(detail.get("progress_percent") or 0)
                    current_day = challenge.current_day
                    missed_days = challenge.consecutive_missed
                    in_recovery = challenge.status == ChallengeStatus.RECOVERY
                    perfect_days = sum(1 for d in challenge.days if d.is_perfect)
                except Exception:
                    current_day = max(1, challenge.current_day or 1)
                    missed_days = challenge.consecutive_missed
                    in_recovery = challenge.status == ChallengeStatus.RECOVERY
                    perfect_days = sum(1 for d in (challenge.days or []) if d.is_perfect)

                group_points = await self._group_points(gm.user_id, challenge)

            role_value = gm.role.value if hasattr(gm.role, "value") else str(gm.role).lower()
            req_match = (
                requester_id is not None
                and str(gm.user_id).replace("-", "").lower()
                == str(requester_id).replace("-", "").lower()
            )
            members_data.append(
                {
                    "user_id": profile.id,
                    "full_name": profile.full_name,
                    "avatar_url": profile.avatar_url,
                    "role": role_value,
                    "today_complete": today_complete,
                    "group_points": group_points,
                    "hp": profile.hp,
                    "current_streak": profile.current_streak,
                    "discipline_score": profile.discipline_score,
                    "missed_days": missed_days,
                    "completion_percent": progress,
                    "current_day": current_day,
                    "perfect_days": perfect_days,
                    "in_recovery": in_recovery,
                    "is_you": req_match,
                }
            )

        # Rank by this group's points only (never global HP). Ties fall back to
        # perfect days, today's completion, streak, then name so order is stable.
        members_data.sort(
            key=lambda m: (
                -m["group_points"],
                -m["perfect_days"],
                -int(m["today_complete"]),
                -m["current_streak"],
                (m["full_name"] or "").lower(),
            )
        )
        for i, row in enumerate(members_data):
            row["rank"] = i + 1
            row["rank_delta"] = 0
        return members_data

    async def _group_points(self, user_id: UUID, challenge: Challenge) -> int:
        """Points a member earned inside this group's challenge only.

        Sums that challenge's point events (daily rewards and missed-day
        penalties), so it is independent of the member's personal challenge and
        global HP. Never below zero. Challenges that predate point events fall
        back to completed days x 10.
        """
        total, events = (
            await self.db.execute(
                select(func.coalesce(func.sum(HpEvent.delta), 0), func.count(HpEvent.id)).where(
                    HpEvent.user_id == user_id,
                    HpEvent.challenge_id == challenge.id,
                )
            )
        ).one()
        if not events:
            return sum(1 for d in (challenge.days or []) if d.is_complete) * 10
        return max(0, int(total or 0))

    async def get_dashboard(self, group_id: UUID, requester_id: UUID) -> dict:
        group, member, is_leader = await self._ensure_membership(group_id, requester_id)
        members_data = await self._build_members_data(group.id, requester_id)

        today_done = sum(1 for m in members_data if m["today_complete"])
        member_count = len(members_data) or 1
        today_pct = round(today_done / member_count * 100, 1)
        avg_group_points = round(
            mean([m["group_points"] for m in members_data]) if members_data else 0
        )
        avg_streak = round(mean([m["current_streak"] for m in members_data]) if members_data else 0)
        your_rank = next((m["rank"] for m in members_data if m["is_you"]), member_count)
        max_perfect = max((m["perfect_days"] for m in members_data), default=0)

        group_current_day = max(
            1,
            min(
                group.duration_days,
                max((m["current_day"] for m in members_data), default=1),
            ),
        )

        ann_result = await self.db.execute(
            select(Announcement)
            .where(Announcement.group_id == group.id)
            .order_by(Announcement.is_pinned.desc(), Announcement.created_at.desc())
            .limit(20)
        )
        announcements = [
            {
                "id": a.id,
                "title": a.title,
                "body": a.body,
                "author_id": a.author_id,
                "is_pinned": a.is_pinned,
                "created_at": a.created_at,
            }
            for a in ann_result.scalars().all()
        ]

        feed_result = await self.db.execute(
            select(GroupActivity)
            .where(GroupActivity.group_id == group.id)
            .order_by(GroupActivity.created_at.desc())
            .limit(40)
        )
        feed = [
            {
                "id": a.id,
                "activity_type": a.activity_type,
                "message": a.message,
                "user_id": a.user_id,
                "metadata": a.extra,
                "created_at": a.created_at,
            }
            for a in feed_result.scalars().all()
        ]

        session_result = await self.db.execute(
            select(GroupSession)
            .where(GroupSession.group_id == group.id, GroupSession.scheduled_at >= utcnow())
            .order_by(GroupSession.scheduled_at.asc())
            .limit(3)
        )
        sessions = [
            {
                "id": s.id,
                "title": s.title,
                "scheduled_at": s.scheduled_at,
                "meeting_url": s.meeting_url,
                "meeting_type": s.meeting_type,
                "notes": s.notes,
            }
            for s in session_result.scalars().all()
        ]

        bonus_unlocked = today_pct >= 95
        group_badge_unlocked = today_pct >= 100

        return {
            "group": {
                "id": group.id,
                "name": group.name,
                "invite_code": group.invite_code,
                "duration_days": group.duration_days,
                "max_missed_days": group.max_missed_days,
                "starts_at": group.starts_at,
                "status": group.status,
                "task_mode": getattr(group, "task_mode", None) or "shared",
                "is_public": getattr(group, "is_public", False),
                "member_count": member_count,
                "is_leader": is_leader,
                "leader_id": group.leader_id,
                "current_day": group_current_day,
            },
            "stats": {
                "participants": member_count,
                "completed_today": today_done,
                "today_completion_percent": today_pct,
                "average_hp": avg_group_points,
                "average_group_points": avg_group_points,
                "average_streak": avg_streak,
                "your_rank": your_rank,
                "perfect_days": max_perfect,
                "bonus_hp_unlocked": bonus_unlocked,
                "group_badge_unlocked": group_badge_unlocked,
            },
            "members": members_data,
            "announcements": announcements,
            "feed": feed,
            "sessions": sessions,
        }

    async def get_member_profile(
        self, group_id: UUID, member_id: UUID, requester_id: UUID
    ) -> dict:
        await self._ensure_membership(group_id, requester_id)

        profile_result = await self.db.execute(select(Profile).where(Profile.id == member_id))
        profile = profile_result.scalar_one_or_none()
        if not profile:
            raise NotFoundError("Member")

        member_check = await self.db.execute(
            select(GroupMember).where(
                GroupMember.group_id == group_id,
                GroupMember.user_id == member_id,
            )
        )
        if not member_check.scalar_one_or_none():
            raise NotFoundError("Member")

        challenge_result = await self.db.execute(
            select(Challenge)
            .where(Challenge.group_id == group_id, Challenge.user_id == member_id)
            .options(selectinload(Challenge.days), selectinload(Challenge.tasks))
        )
        challenge = challenge_result.scalar_one_or_none()

        heatmap = []
        if challenge and challenge.days:
            for day in sorted(challenge.days, key=lambda d: d.day_number):
                status = "future"
                if day.day_number < challenge.current_day:
                    if day.is_complete:
                        status = "complete"
                    elif challenge.status == ChallengeStatus.RECOVERY and day.day_number == challenge.current_day - 1:
                        status = "recovery"
                    else:
                        status = "missed"
                elif day.day_number == challenge.current_day:
                    status = "complete" if day.is_complete else "today"
                heatmap.append(
                    {
                        "day_number": day.day_number,
                        "calendar_date": day.calendar_date,
                        "status": status,
                    }
                )

        foundation_tasks = []
        personal_tasks = []
        if challenge:
            for t in sorted(challenge.tasks, key=lambda x: x.sort_order):
                if not t.is_active:
                    continue
                entry = {"id": t.id, "title": t.title, "type": t.type.value}
                if t.type == TaskType.FOUNDATION:
                    foundation_tasks.append(entry)
                else:
                    personal_tasks.append(entry)

        group_points = (
            await self._group_points(member_id, challenge) if challenge else 0
        )

        return {
            "user_id": profile.id,
            "full_name": profile.full_name,
            "avatar_url": profile.avatar_url,
            "group_points": group_points,
            "hp": profile.hp,
            "current_streak": profile.current_streak,
            "longest_streak": profile.longest_streak,
            "challenges_completed": profile.challenges_completed,
            "perfect_weeks": profile.perfect_weeks,
            "is_you": str(member_id).replace("-", "").lower()
            == str(requester_id).replace("-", "").lower(),
            "heatmap": heatmap,
            "foundation_tasks": foundation_tasks,
            "personal_tasks": personal_tasks,
            "challenge": {
                "current_day": challenge.current_day if challenge else 1,
                "completion_percent": (
                    sum(1 for d in challenge.days if d.is_complete) / len(challenge.days) * 100
                    if challenge and challenge.days
                    else 0
                ),
                "status": challenge.status.value if challenge else None,
            },
        }

    async def get_group_statistics(self, group_id: UUID, requester_id: UUID) -> dict:
        await self._ensure_membership(group_id, requester_id)
        members = await self._build_members_data(group_id, requester_id)
        if not members:
            return {
                "completion_percent": 0,
                "average_hp": 0,
                "average_group_points": 0,
                "daily_active": 0,
                "longest_streak": 0,
                "top_performer": None,
                "most_consistent": None,
                "most_improved": None,
                "weekly_trend": [],
            }

        completion = mean([m["completion_percent"] for m in members])
        daily_active = sum(1 for m in members if m["today_complete"])
        longest_streak = max(m["current_streak"] for m in members)
        top = max(members, key=lambda m: m["group_points"])
        consistent = max(members, key=lambda m: m["perfect_days"])
        improved = max(members, key=lambda m: m["current_streak"])
        avg_pts = round(mean([m["group_points"] for m in members]))

        weekly_trend = []
        for i in range(7):
            pct = max(0, min(100, completion - (6 - i) * 3 + i * 2))
            weekly_trend.append({"day": i, "value": round(pct, 1)})

        return {
            "completion_percent": round(completion, 1),
            "average_hp": avg_pts,
            "average_group_points": avg_pts,
            "daily_active": daily_active,
            "longest_streak": longest_streak,
            "top_performer": {"name": top["full_name"], "score": top["group_points"]},
            "most_consistent": {"name": consistent["full_name"], "perfect_days": consistent["perfect_days"]},
            "most_improved": {"name": improved["full_name"], "streak": improved["current_streak"]},
            "weekly_trend": weekly_trend,
        }

    async def _ensure_group_days(self, challenge: Challenge) -> None:
        if challenge.days:
            return
        start = challenge.start_date or app_today()
        for day_num in range(1, challenge.duration_days + 1):
            self.db.add(
                ChallengeDay(
                    challenge_id=challenge.id,
                    day_number=day_num,
                    calendar_date=start + timedelta(days=day_num - 1),
                )
            )
        await self.db.flush()

    async def post_announcement(
        self,
        group_id: UUID,
        author_id: UUID,
        body: str,
        title: str | None = None,
        is_pinned: bool = False,
    ) -> Announcement:
        group, _, is_leader = await self._ensure_membership(group_id, author_id)
        if not is_leader and group.leader_id != author_id:
            raise ForbiddenError("Only the leader can post announcements")

        announcement = Announcement(
            group_id=group_id,
            author_id=author_id,
            title=title,
            body=body,
            is_pinned=is_pinned,
        )
        self.db.add(announcement)
        await self.db.flush()

        label = title or body[:60]
        await self.record_activity(
            group_id,
            GroupActivityType.ANNOUNCEMENT.value,
            f"Leader posted: {label}",
            author_id,
            {"announcement_id": str(announcement.id)},
        )
        return announcement

    async def create_session(
        self,
        group_id: UUID,
        author_id: UUID,
        data: dict,
    ) -> GroupSession:
        _, _, is_leader = await self._ensure_membership(group_id, author_id)
        if not is_leader:
            raise ForbiddenError("Only the leader can schedule sessions")

        session = GroupSession(
            group_id=group_id,
            title=data["title"],
            scheduled_at=data["scheduled_at"],
            meeting_url=data.get("meeting_url"),
            meeting_type=data.get("meeting_type", "google_meet"),
            notes=data.get("notes"),
        )
        self.db.add(session)
        await self.db.flush()

        await self.record_activity(
            group_id,
            GroupActivityType.SESSION.value,
            f"Live session scheduled: {session.title}",
            author_id,
            {"session_id": str(session.id)},
        )
        return session

    async def remove_member(
        self, group_id: UUID, leader_id: UUID, member_id: UUID
    ) -> None:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the leader can remove members")
        if str(group.leader_id).replace("-", "") == str(member_id).replace("-", ""):
            raise AppError("INVALID", "Cannot remove the group leader")

        result = await self.db.execute(
            select(GroupMember).where(
                GroupMember.group_id == group_id,
                GroupMember.user_id == member_id,
            )
        )
        gm = result.scalar_one_or_none()
        if not gm:
            raise NotFoundError("Member")
        await self.db.delete(gm)

        challenge_result = await self.db.execute(
            select(Challenge).where(
                Challenge.group_id == group_id,
                Challenge.user_id == member_id,
            )
        )
        challenge = challenge_result.scalar_one_or_none()
        if challenge:
            challenge.status = ChallengeStatus.ARCHIVED
        await self.db.flush()

    async def update_group(
        self, group_id: UUID, leader_id: UUID, data: dict
    ) -> Group:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the leader can update group settings")
        if "name" in data and data["name"] and data["name"].strip().lower() != group.name.lower():
            await self._check_name_available(data["name"], exclude_group_id=group.id)
            group.name = data["name"].strip()
        if "max_missed_days" in data:
            group.max_missed_days = data["max_missed_days"]
        if "penalty_rules" in data:
            group.penalty_rules = data["penalty_rules"]
        if "is_public" in data and data["is_public"] is not None:
            group.is_public = bool(data["is_public"])
        await self.db.flush()
        return group

    async def get_day_roster(
        self, group_id: UUID, leader_id: UUID, roster_date: date | None = None
    ) -> dict:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the leader can view the day roster")

        target = roster_date or app_today()
        if target < group.starts_at:
            target = group.starts_at
        end_date = group.starts_at + timedelta(days=group.duration_days - 1)
        if target > end_date:
            target = end_date

        members_result = await self.db.execute(
            select(GroupMember).where(GroupMember.group_id == group_id)
        )
        group_members = list(members_result.scalars().all())

        members_out: list[dict] = []
        for gm in group_members:
            profile_result = await self.db.execute(
                select(Profile).where(Profile.id == gm.user_id)
            )
            profile = profile_result.scalar_one_or_none()
            if not profile:
                continue

            challenge_result = await self.db.execute(
                select(Challenge)
                .where(Challenge.group_id == group.id, Challenge.user_id == gm.user_id)
                .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
            )
            challenge = challenge_result.scalar_one_or_none()

            tasks_out: list[dict] = []
            day_complete = False
            if challenge:
                active_tasks = sorted(
                    [t for t in challenge.tasks if t.is_active],
                    key=lambda t: t.sort_order,
                )
                day = next(
                    (d for d in challenge.days if d.calendar_date == target),
                    None,
                )
                completed_ids: set[UUID] = set()
                if day:
                    comps = await self.db.execute(
                        select(TaskCompletion.task_id).where(
                            TaskCompletion.challenge_day_id == day.id
                        )
                    )
                    completed_ids = set(comps.scalars().all())
                    day_complete = bool(day.is_complete) or (
                        all(t.id in completed_ids for t in active_tasks) if active_tasks else False
                    )
                for t in active_tasks:
                    type_val = t.type.value if hasattr(t.type, "value") else str(t.type)
                    tasks_out.append(
                        {
                            "id": t.id,
                            "title": t.title,
                            "type": type_val,
                            "completed": t.id in completed_ids,
                        }
                    )

            role_value = gm.role.value if hasattr(gm.role, "value") else str(gm.role).lower()
            members_out.append(
                {
                    "user_id": profile.id,
                    "full_name": profile.full_name,
                    "avatar_url": profile.avatar_url,
                    "role": role_value,
                    "day_complete": day_complete,
                    "tasks": tasks_out,
                }
            )

        members_out.sort(key=lambda m: m["full_name"].lower())
        prev_date = target - timedelta(days=1)
        next_date = target + timedelta(days=1)
        return {
            "date": target.isoformat(),
            "prev_date": prev_date.isoformat() if prev_date >= group.starts_at else None,
            "next_date": next_date.isoformat() if next_date <= end_date else None,
            "starts_at": group.starts_at.isoformat(),
            "ends_at": end_date.isoformat(),
            "members": members_out,
        }


    # ------------------------------------------------------------------
    # Group tasks (set by the admin for everyone)
    # ------------------------------------------------------------------
    async def _member_challenges(self, group_id: UUID) -> list[Challenge]:
        result = await self.db.execute(
            select(Challenge)
            .where(
                Challenge.group_id == group_id,
                Challenge.status.in_(
                    [ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY, ChallengeStatus.COMPLETED]
                ),
            )
            .options(selectinload(Challenge.tasks))
        )
        return list(result.scalars().all())

    async def get_group_tasks(self, group_id: UUID, requester_id: UUID) -> dict:
        group, _, is_leader = await self._ensure_membership(group_id, requester_id)
        return {
            "task_mode": getattr(group, "task_mode", None) or "shared",
            "tasks": await self._group_task_titles(group_id),
            "can_edit": is_leader,
        }

    async def add_group_task(self, group_id: UUID, leader_id: UUID, title: str) -> dict:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the admin can add tasks for everyone")
        if group.status != "active":
            raise AppError("GROUP_INACTIVE", "This group is no longer active")
        clean = (title or "").strip()[:255]
        if not clean:
            raise AppError("VALIDATION", "Task title is required")

        existing = await self._group_task_titles(group_id)
        if clean.lower() in {t.lower() for t in existing}:
            raise ConflictError("The group already has this task")
        if len(existing) >= MAX_GROUP_TASKS:
            raise AppError("VALIDATION", f"A group can have at most {MAX_GROUP_TASKS} tasks")

        for challenge in await self._member_challenges(group_id):
            order = max((t.sort_order for t in challenge.tasks), default=-1) + 1
            self.db.add(
                Task(
                    challenge_id=challenge.id,
                    title=clean,
                    type=TaskType.FOUNDATION,
                    sort_order=order,
                )
            )
        await self.db.flush()
        await self.record_activity(
            group_id,
            "announcement",
            f'New task for everyone: "{clean}"',
            leader_id,
        )
        return await self.get_group_tasks(group_id, leader_id)

    async def remove_group_task(self, group_id: UUID, leader_id: UUID, title: str) -> dict:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the admin can remove tasks for everyone")
        clean = (title or "").strip().lower()
        existing = await self._group_task_titles(group_id)
        if clean not in {t.lower() for t in existing}:
            raise NotFoundError("Task")
        task_mode = getattr(group, "task_mode", None) or "shared"
        if task_mode == "shared" and len(existing) <= 1:
            raise AppError(
                "VALIDATION", "A group where everyone does the same tasks needs at least one task"
            )

        for challenge in await self._member_challenges(group_id):
            for task in challenge.tasks:
                if task.type == TaskType.FOUNDATION and task.title.strip().lower() == clean:
                    task.is_active = False
        await self.db.flush()
        return await self.get_group_tasks(group_id, leader_id)

    # ------------------------------------------------------------------
    # Leaving / ending
    # ------------------------------------------------------------------
    async def leave_group(self, group_id: UUID, user_id: UUID) -> None:
        group, member, is_leader = await self._ensure_membership(group_id, user_id)
        if is_leader:
            raise AppError(
                "LEADER_CANNOT_LEAVE",
                "The admin can't leave. Remove members or end the group in settings.",
            )
        await self.db.delete(member)
        result = await self.db.execute(
            select(Challenge).where(Challenge.group_id == group_id, Challenge.user_id == user_id)
        )
        for challenge in result.scalars().all():
            if challenge.status in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
                challenge.status = ChallengeStatus.ARCHIVED
        profile = (
            await self.db.execute(select(Profile).where(Profile.id == user_id))
        ).scalar_one_or_none()
        await self.record_activity(
            group_id,
            GroupActivityType.MEMBER_JOINED.value,
            f"{profile.full_name if profile else 'A member'} left the group",
            user_id,
        )
        await self.db.flush()

    async def end_group(self, group_id: UUID, leader_id: UUID) -> None:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the admin can end the group")
        group.status = "ended"
        result = await self.db.execute(select(Challenge).where(Challenge.group_id == group_id))
        for challenge in result.scalars().all():
            if challenge.status in (ChallengeStatus.ACTIVE, ChallengeStatus.RECOVERY):
                challenge.status = ChallengeStatus.ARCHIVED
        await self.db.flush()

    # ------------------------------------------------------------------
    # Chat
    # ------------------------------------------------------------------
    def _message_out(self, m: GroupMessage, profile: Profile | None, viewer_id: UUID, leader_id: UUID) -> dict:
        return {
            "id": m.id,
            "user_id": m.user_id,
            "full_name": profile.full_name if profile else "Member",
            "avatar_url": profile.avatar_url if profile else None,
            "is_leader": str(m.user_id) == str(leader_id),
            "body": "" if m.is_deleted else m.body,
            "is_deleted": bool(m.is_deleted),
            "created_at": as_utc(m.created_at).isoformat(),
            "is_you": str(m.user_id) == str(viewer_id),
        }

    async def list_messages(
        self,
        group_id: UUID,
        user_id: UUID,
        after_id: UUID | None = None,
        before_id: UUID | None = None,
        limit: int = 50,
    ) -> dict:
        group, _, _ = await self._ensure_membership(group_id, user_id)
        limit = max(1, min(limit, 100))

        query = select(GroupMessage).where(GroupMessage.group_id == group_id)
        newest_first = True
        if after_id:
            cursor = (
                await self.db.execute(
                    select(GroupMessage.created_at).where(
                        GroupMessage.id == after_id, GroupMessage.group_id == group_id
                    )
                )
            ).scalar_one_or_none()
            if cursor is not None:
                # >= so equal timestamps are never skipped; the app de-duplicates by id.
                query = query.where(GroupMessage.created_at >= cursor)
                newest_first = False
        elif before_id:
            cursor = (
                await self.db.execute(
                    select(GroupMessage.created_at).where(
                        GroupMessage.id == before_id, GroupMessage.group_id == group_id
                    )
                )
            ).scalar_one_or_none()
            if cursor is not None:
                query = query.where(GroupMessage.created_at < cursor)

        if newest_first:
            query = query.order_by(GroupMessage.created_at.desc(), GroupMessage.id).limit(limit)
        else:
            query = query.order_by(GroupMessage.created_at, GroupMessage.id).limit(limit)
        rows = list((await self.db.execute(query)).scalars().all())
        if newest_first:
            rows.reverse()

        user_ids = {m.user_id for m in rows}
        profiles: dict[UUID, Profile] = {}
        if user_ids:
            result = await self.db.execute(select(Profile).where(Profile.id.in_(user_ids)))
            profiles = {p.id: p for p in result.scalars().all()}
        return {
            "messages": [
                self._message_out(m, profiles.get(m.user_id), user_id, group.leader_id) for m in rows
            ],
            "has_more": newest_first and len(rows) == limit,
        }

    async def post_message(self, group_id: UUID, user_id: UUID, body: str) -> dict:
        group, _, _ = await self._ensure_membership(group_id, user_id)
        if group.status != "active":
            raise AppError("GROUP_INACTIVE", "This group has ended")
        text = (body or "").strip()
        if not text:
            raise AppError("VALIDATION", "Write a message first")
        text = text[:1000]

        since = utcnow() - timedelta(seconds=60)
        recent = (
            await self.db.execute(
                select(func.count())
                .select_from(GroupMessage)
                .where(
                    GroupMessage.group_id == group_id,
                    GroupMessage.user_id == user_id,
                    GroupMessage.created_at >= since.replace(tzinfo=None),
                )
            )
        ).scalar() or 0
        if recent >= MAX_MESSAGES_PER_MINUTE:
            raise AppError("RATE_LIMIT", "You're sending messages too fast. Wait a moment.", 429)

        message = GroupMessage(group_id=group_id, user_id=user_id, body=text)
        self.db.add(message)
        await self.db.flush()
        profile = (
            await self.db.execute(select(Profile).where(Profile.id == user_id))
        ).scalar_one_or_none()
        return self._message_out(message, profile, user_id, group.leader_id)

    async def delete_message(self, group_id: UUID, message_id: UUID, user_id: UUID) -> None:
        group, _, is_leader = await self._ensure_membership(group_id, user_id)
        message = (
            await self.db.execute(
                select(GroupMessage).where(
                    GroupMessage.id == message_id, GroupMessage.group_id == group_id
                )
            )
        ).scalar_one_or_none()
        if not message:
            raise NotFoundError("Message")
        if str(message.user_id) != str(user_id) and not is_leader:
            raise ForbiddenError("You can only delete your own messages")
        message.is_deleted = True
        await self.db.flush()

    # ------------------------------------------------------------------
    # Group leaderboard: groups ranked by their participants' points
    # ------------------------------------------------------------------
    async def groups_leaderboard(
        self, user_id: UUID, metric: str = "total", limit: int = 50
    ) -> list[dict]:
        rows = (
            await self.db.execute(
                select(
                    Challenge.group_id,
                    Challenge.user_id,
                    func.coalesce(func.sum(HpEvent.delta), 0),
                )
                .select_from(Challenge)
                .join(
                    HpEvent,
                    and_(HpEvent.challenge_id == Challenge.id, HpEvent.user_id == Challenge.user_id),
                    isouter=True,
                )
                .where(
                    Challenge.group_id.is_not(None),
                    Challenge.status != ChallengeStatus.ARCHIVED,
                )
                .group_by(Challenge.group_id, Challenge.user_id)
            )
        ).all()

        totals: dict[UUID, int] = {}
        for group_id, _member, points in rows:
            totals[group_id] = totals.get(group_id, 0) + max(0, int(points or 0))

        groups = (
            await self.db.execute(select(Group).where(Group.status == "active"))
        ).scalars().all()
        counts = dict(
            (
                await self.db.execute(
                    select(GroupMember.group_id, func.count()).group_by(GroupMember.group_id)
                )
            ).all()
        )
        mine = set(
            (
                await self.db.execute(
                    select(GroupMember.group_id).where(GroupMember.user_id == user_id)
                )
            ).scalars().all()
        )

        board = []
        for g in groups:
            members = int(counts.get(g.id, 0))
            total = totals.get(g.id, 0)
            board.append(
                {
                    "group_id": g.id,
                    "name": g.name,
                    "member_count": members,
                    "total_points": total,
                    "average_points": round(total / members) if members else 0,
                    "current_day": max(1, min(g.duration_days, (app_today() - g.starts_at).days + 1)),
                    "duration_days": g.duration_days,
                    "is_yours": g.id in mine,
                }
            )
        key = "average_points" if metric == "average" else "total_points"
        board.sort(key=lambda x: (-x[key], -x["member_count"], x["name"].lower()))
        for i, row in enumerate(board[:limit]):
            row["rank"] = i + 1
        return board[:limit]

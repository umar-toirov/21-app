from datetime import date, timedelta
from statistics import mean
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AppError, ConflictError, ForbiddenError, NotFoundError
from app.core.security import utcnow
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
    GroupSession,
    HpEvent,
    Profile,
    Task,
    TaskCompletion,
    TaskType,
)
from app.services.challenge_service import FOUNDATION_TASKS, ChallengeService, generate_invite_code


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

    async def _leader_foundation_tasks(self, group_id: UUID) -> list[str]:
        result = await self.db.execute(select(Group).where(Group.id == group_id))
        group = result.scalar_one_or_none()
        if not group:
            return list(FOUNDATION_TASKS)
        challenge_result = await self.db.execute(
            select(Challenge)
            .where(Challenge.group_id == group_id, Challenge.user_id == group.leader_id)
            .options(selectinload(Challenge.tasks))
        )
        challenge = challenge_result.scalar_one_or_none()
        if not challenge or not challenge.tasks:
            return list(FOUNDATION_TASKS)
        tasks = [
            t.title
            for t in sorted(challenge.tasks, key=lambda x: x.sort_order)
            if t.type == TaskType.FOUNDATION and t.is_active
        ]
        return tasks if len(tasks) >= 2 else list(FOUNDATION_TASKS)

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
            current_day=max(1, (date.today() - group.starts_at).days + 1),
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

    async def create_group(self, leader: Profile, data: dict) -> Group:
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

        personal_tasks = data.get("personal_tasks") or []
        if task_mode == "freedom" and len(personal_tasks) < 2:
            raise AppError("VALIDATION", "Freedom groups require at least 2 personal tasks")

        group = Group(
            leader_id=leader.id,
            name=data["name"],
            invite_code=invite_code,
            duration_days=data["duration_days"],
            max_missed_days=data.get("max_missed_days", 3),
            penalty_rules=data.get("penalty_rules") or {},
            task_mode=task_mode,
            starts_at=data["starts_at"],
        )
        self.db.add(group)
        await self.db.flush()

        self.db.add(
            GroupMember(group_id=group.id, user_id=leader.id, role=GroupMemberRole.LEADER)
        )

        foundation_tasks = data.get("foundation_tasks", FOUNDATION_TASKS)
        await self._create_member_challenge(
            leader,
            group,
            foundation_tasks,
            personal_tasks=personal_tasks if task_mode == "freedom" else None,
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

        foundation_tasks = await self._leader_foundation_tasks(group.id)
        return {
            "name": group.name,
            "duration_days": group.duration_days,
            "task_mode": getattr(group, "task_mode", None) or "shared",
            "foundation_tasks": foundation_tasks,
            "starts_at": group.starts_at,
            "max_missed_days": group.max_missed_days,
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
        personal = [t.strip() for t in (personal_tasks or []) if t and t.strip()]
        if task_mode == "freedom" and len(personal) < 2:
            raise AppError(
                "VALIDATION",
                "This group lets members add their own tasks — pick at least 2",
            )

        self.db.add(GroupMember(group_id=group.id, user_id=user.id, role=GroupMemberRole.MEMBER))

        foundation_tasks = await self._leader_foundation_tasks(group.id)
        await self._create_member_challenge(
            user,
            group,
            foundation_tasks,
            personal_tasks=personal if task_mode == "freedom" else None,
        )

        await self.record_activity(
            group.id,
            GroupActivityType.MEMBER_JOINED.value,
            f"{user.full_name} joined the group",
            user.id,
        )
        await self.db.flush()
        return group

    async def get_user_groups(self, user_id: UUID) -> list[dict]:
        result = await self.db.execute(
            select(Group)
            .join(GroupMember)
            .where(GroupMember.user_id == user_id)
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
                    "current_day": max(1, (date.today() - g.starts_at).days + 1),
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

                pts_result = await self.db.execute(
                    select(func.coalesce(func.sum(HpEvent.delta), 0)).where(
                        HpEvent.user_id == gm.user_id,
                        HpEvent.challenge_id == challenge.id,
                        HpEvent.delta > 0,
                    )
                )
                group_points = int(pts_result.scalar() or 0)
                if group_points == 0:
                    # Fallback when events missing: completed group days × 10
                    group_points = sum(1 for d in (challenge.days or []) if d.is_complete) * 10

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

        members_data.sort(
            key=lambda m: (
                -m["group_points"],
                -m["perfect_days"],
                -int(m["today_complete"]),
            )
        )
        for i, row in enumerate(members_data):
            row["rank"] = i + 1
            row["rank_delta"] = 0
        return members_data

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

        group_points = 0
        if challenge:
            pts_result = await self.db.execute(
                select(func.coalesce(func.sum(HpEvent.delta), 0)).where(
                    HpEvent.user_id == member_id,
                    HpEvent.challenge_id == challenge.id,
                    HpEvent.delta > 0,
                )
            )
            group_points = int(pts_result.scalar() or 0)
            if group_points == 0:
                group_points = sum(1 for d in (challenge.days or []) if d.is_complete) * 10

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
        start = challenge.start_date or date.today()
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
        if "name" in data and data["name"]:
            group.name = data["name"]
        if "max_missed_days" in data:
            group.max_missed_days = data["max_missed_days"]
        if "penalty_rules" in data:
            group.penalty_rules = data["penalty_rules"]
        await self.db.flush()
        return group

    async def get_day_roster(
        self, group_id: UUID, leader_id: UUID, roster_date: date | None = None
    ) -> dict:
        group, _, is_leader = await self._ensure_membership(group_id, leader_id)
        if not is_leader:
            raise ForbiddenError("Only the leader can view the day roster")

        target = roster_date or date.today()
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

import enum
import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class ChallengeStatus(str, enum.Enum):
    DRAFT = "draft"
    PENDING_PAYMENT = "pending_payment"
    ACTIVE = "active"
    RECOVERY = "recovery"
    COMPLETED = "completed"
    FAILED = "failed"
    ARCHIVED = "archived"


class ChallengeType(str, enum.Enum):
    INDIVIDUAL = "individual"
    GROUP = "group"


class TaskType(str, enum.Enum):
    FOUNDATION = "foundation"
    PERSONAL = "personal"


class PaymentStatus(str, enum.Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"


class GroupMemberRole(str, enum.Enum):
    LEADER = "leader"
    MEMBER = "member"


class BadgeCode(str, enum.Enum):
    MORNING_WARRIOR = "morning_warrior"
    CONSISTENCY_MASTER = "consistency_master"
    SEVEN_DAY_STREAK = "seven_day_streak"
    THIRTY_DAY_LEGEND = "thirty_day_legend"
    NEVER_MISSED = "never_missed"
    RECOVERY_CHAMPION = "recovery_champion"
    TOP_100 = "top_100"


class Profile(Base):
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    bio: Mapped[str | None] = mapped_column(Text)
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Tashkent")
    locale: Mapped[str] = mapped_column(String(8), default="en")
    onboarding_step: Mapped[int] = mapped_column(Integer, default=0)
    onboarding_data: Mapped[dict] = mapped_column(JSON, default=dict)
    hp: Mapped[int] = mapped_column(Integer, default=0)
    discipline_score: Mapped[int] = mapped_column(Integer, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    perfect_weeks: Mapped[int] = mapped_column(Integer, default=0)
    challenges_completed: Mapped[int] = mapped_column(Integer, default=0)
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    dark_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    challenges: Mapped[list["Challenge"]] = relationship(back_populates="user")
    badges: Mapped[list["UserBadge"]] = relationship(back_populates="user")
    certificates: Mapped[list["Certificate"]] = relationship(back_populates="user")
    payments: Mapped[list["Payment"]] = relationship(back_populates="user")

    __table_args__ = (
        CheckConstraint("hp >= 0", name="ck_profiles_hp_non_negative"),
        CheckConstraint(
            "discipline_score >= 0 AND discipline_score <= 1000",
            name="ck_profiles_discipline_score_range",
        ),
    )


class Goal(Base):
    __tablename__ = "goals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slug: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    icon: Mapped[str | None] = mapped_column(String(64))


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    amount_uzs: Mapped[int] = mapped_column(Integer, default=99000)
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus), default=PaymentStatus.PENDING)
    provider: Mapped[str | None] = mapped_column(String(32))
    provider_ref: Mapped[str | None] = mapped_column(String(255))
    idempotency_key: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user: Mapped["Profile"] = relationship(back_populates="payments")


class Group(Base):
    __tablename__ = "groups"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    leader_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    invite_code: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    max_missed_days: Mapped[int] = mapped_column(Integer, default=3)
    penalty_rules: Mapped[dict] = mapped_column(JSON, default=dict)
    # "shared" = foundation only for all; "freedom" = foundation + personal tasks
    task_mode: Mapped[str] = mapped_column(String(16), default="shared")
    status: Mapped[str] = mapped_column(String(32), default="active")
    starts_at: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    members: Mapped[list["GroupMember"]] = relationship(back_populates="group")
    announcements: Mapped[list["Announcement"]] = relationship(back_populates="group")
    activities: Mapped[list["GroupActivity"]] = relationship(back_populates="group")
    sessions: Mapped[list["GroupSession"]] = relationship(back_populates="group")


class Challenge(Base):
    __tablename__ = "challenges"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    goal_id: Mapped[int | None] = mapped_column(ForeignKey("goals.id"))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    type: Mapped[ChallengeType] = mapped_column(Enum(ChallengeType), default=ChallengeType.INDIVIDUAL)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[ChallengeStatus] = mapped_column(Enum(ChallengeStatus), default=ChallengeStatus.DRAFT)
    start_date: Mapped[date | None] = mapped_column(Date)
    current_day: Mapped[int] = mapped_column(Integer, default=0)
    max_missed_days: Mapped[int] = mapped_column(Integer, default=3)
    consecutive_missed: Mapped[int] = mapped_column(Integer, default=0)
    recovery_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_first_free: Mapped[bool] = mapped_column(Boolean, default=False)
    payment_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("payments.id"))
    group_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("groups.id"))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    failed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    user: Mapped["Profile"] = relationship(back_populates="challenges")
    tasks: Mapped[list["Task"]] = relationship(back_populates="challenge", cascade="all, delete-orphan")
    days: Mapped[list["ChallengeDay"]] = relationship(
        back_populates="challenge", cascade="all, delete-orphan"
    )
    certificate: Mapped["Certificate | None"] = relationship(back_populates="challenge", uselist=False)


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    challenge_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("challenges.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    type: Mapped[TaskType] = mapped_column(Enum(TaskType), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    challenge: Mapped["Challenge"] = relationship(back_populates="tasks")
    completions: Mapped[list["TaskCompletion"]] = relationship(back_populates="task")


class ChallengeDay(Base):
    __tablename__ = "challenge_days"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    challenge_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("challenges.id"), nullable=False)
    day_number: Mapped[int] = mapped_column(Integer, nullable=False)
    calendar_date: Mapped[date] = mapped_column(Date, nullable=False)
    is_complete: Mapped[bool] = mapped_column(Boolean, default=False)
    is_perfect: Mapped[bool] = mapped_column(Boolean, default=False)
    hp_delta: Mapped[int] = mapped_column(Integer, default=0)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    challenge: Mapped["Challenge"] = relationship(back_populates="days")
    completions: Mapped[list["TaskCompletion"]] = relationship(back_populates="challenge_day")

    __table_args__ = (UniqueConstraint("challenge_id", "day_number"),)


class TaskCompletion(Base):
    __tablename__ = "task_completions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    task_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tasks.id"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    challenge_day_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("challenge_days.id"), nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    is_late: Mapped[bool] = mapped_column(Boolean, default=False)

    task: Mapped["Task"] = relationship(back_populates="completions")
    challenge_day: Mapped["ChallengeDay"] = relationship(back_populates="completions")

    __table_args__ = (UniqueConstraint("task_id", "challenge_day_id"),)


class HpEvent(Base):
    __tablename__ = "hp_events"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    challenge_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("challenges.id"))
    delta: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)


class Badge(Base):
    __tablename__ = "badges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[BadgeCode] = mapped_column(Enum(BadgeCode), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    icon_url: Mapped[str | None] = mapped_column(Text)


class UserBadge(Base):
    __tablename__ = "user_badges"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), primary_key=True)
    badge_id: Mapped[int] = mapped_column(ForeignKey("badges.id"), primary_key=True)
    earned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    challenge_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("challenges.id"))

    user: Mapped["Profile"] = relationship(back_populates="badges")
    badge: Mapped["Badge"] = relationship()


class Certificate(Base):
    __tablename__ = "certificates"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    challenge_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("challenges.id"), unique=True, nullable=False)
    certificate_no: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    pdf_url: Mapped[str | None] = mapped_column(Text)

    user: Mapped["Profile"] = relationship(back_populates="certificates")
    challenge: Mapped["Challenge"] = relationship(back_populates="certificate")


class GroupMember(Base):
    __tablename__ = "group_members"

    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), primary_key=True)
    role: Mapped[GroupMemberRole] = mapped_column(
        Enum(GroupMemberRole, values_callable=lambda obj: [e.value for e in obj]),
        default=GroupMemberRole.MEMBER,
    )
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    group: Mapped["Group"] = relationship(back_populates="members")


class Announcement(Base):
    __tablename__ = "announcements"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"), nullable=False)
    author_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    title: Mapped[str | None] = mapped_column(String(255))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    group: Mapped["Group"] = relationship(back_populates="announcements")


class GroupActivityType(str, enum.Enum):
    TASK_COMPLETE = "task_complete"
    STREAK_MILESTONE = "streak_milestone"
    RANK_CHANGE = "rank_change"
    RECOVERY = "recovery"
    ANNOUNCEMENT = "announcement"
    MEMBER_JOINED = "member_joined"
    CERTIFICATE = "certificate"
    GROUP_MILESTONE = "group_milestone"
    SESSION = "session"


class GroupActivity(Base):
    __tablename__ = "group_activities"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"), nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("profiles.id"))
    activity_type: Mapped[str] = mapped_column(String(32), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    extra: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    group: Mapped["Group"] = relationship(back_populates="activities")


class GroupSession(Base):
    __tablename__ = "group_sessions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("groups.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    meeting_url: Mapped[str | None] = mapped_column(Text)
    meeting_type: Mapped[str] = mapped_column(String(32), default="google_meet")
    notes: Mapped[str | None] = mapped_column(Text)
    recording_url: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    group: Mapped["Group"] = relationship(back_populates="sessions")


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    fcm_token: Mapped[str] = mapped_column(Text, nullable=False)
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (UniqueConstraint("user_id", "fcm_token"),)


class MotivationalQuote(Base):
    __tablename__ = "motivational_quotes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str | None] = mapped_column(String(128))


class GroupMessage(Base):
    """A chat message inside a group. Soft-deleted so threads keep their shape."""

    __tablename__ = "group_messages"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, index=True
    )

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import AliasChoices, BaseModel, ConfigDict, EmailStr, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# --- Profile ---
class ProfileResponse(ORMModel):
    id: UUID
    email: str
    full_name: str
    avatar_url: str | None
    timezone: str
    locale: str
    hp: int
    discipline_score: int
    current_streak: int
    longest_streak: int
    perfect_weeks: int
    challenges_completed: int
    onboarding_step: int
    notifications_enabled: bool
    dark_mode: bool


class ProfileUpdate(BaseModel):
    full_name: str | None = None
    avatar_url: str | None = None
    timezone: str | None = None
    locale: str | None = None
    notifications_enabled: bool | None = None
    dark_mode: bool | None = None


class ProfileCreate(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str


class DeviceTokenCreate(BaseModel):
    fcm_token: str
    platform: str = Field(pattern="^(ios|android)$")


# --- Onboarding ---
class OnboardingResponse(BaseModel):
    step: int
    data: dict


class OnboardingStepUpdate(BaseModel):
    data: dict


# --- Goals ---
class GoalResponse(ORMModel):
    id: int
    slug: str
    name: str
    icon: str | None


# --- Tasks ---
class TaskResponse(ORMModel):
    id: UUID
    title: str
    type: str
    sort_order: int
    is_completed: bool = False


# --- Challenge ---
class ChallengeCreateRequest(BaseModel):
    """Start a personal challenge, optionally from a built-in framework."""

    template_id: str | None = Field(default=None, max_length=64)
    name: str | None = Field(default=None, max_length=120)
    duration_days: int = Field(default=21, ge=7, le=90)
    start_date: date | None = None
    personal_tasks: list[str] = Field(min_length=2, max_length=10)
    include_foundation: bool = True


class ChallengeResponse(ORMModel):
    id: UUID
    name: str
    type: str
    duration_days: int
    status: str
    start_date: date | None
    current_day: int
    consecutive_missed: int
    is_first_free: bool
    completed_at: datetime | None
    failed_at: datetime | None


class ChallengeDaySummary(BaseModel):
    day_number: int
    calendar_date: str
    is_complete: bool = False
    is_missed: bool = False
    is_today: bool = False
    is_locked: bool = False


class ChallengeDetailResponse(ChallengeResponse):
    progress_percent: float
    remaining_days: int
    today_mission: str | None
    quote: str | None
    leaderboard_position: int | None
    tasks: list[TaskResponse]
    recovery_hours_left: float | None = None
    days: list[ChallengeDaySummary] = []
    day_complete: bool = False
    days_until_start: int = 0
    points_today: int = 0
    penalty_points: int = 0


class CompleteTaskRequest(BaseModel):
    task_id: UUID


class CompleteTaskResponse(BaseModel):
    task_id: UUID
    day_complete: bool
    hp_delta: int
    new_hp: int
    celebration: bool
    challenge_completed: bool = False
    reward_message: str | None = None
    new_score: int | None = None


# --- HP ---
class HpEventResponse(ORMModel):
    id: UUID
    delta: int
    reason: str
    created_at: datetime


# --- Badges & Certificates ---
class BadgeResponse(ORMModel):
    id: int
    code: str
    name: str
    description: str
    earned: bool = False
    earned_at: datetime | None = None


class CertificateResponse(ORMModel):
    id: UUID
    certificate_no: str
    title: str
    duration_days: int
    issued_at: datetime
    pdf_url: str | None


# --- Statistics ---
class PersonalStatsResponse(BaseModel):
    completion_rate: float
    daily_consistency: list[dict]
    monthly_trend: list[dict]
    missed_days: int
    discipline_breakdown: dict


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    full_name: str
    avatar_url: str | None
    value: int
    is_you: bool = False


class WeeklyReportResponse(BaseModel):
    week_start: date
    completion_percent: float
    hp_delta: int
    rank_change: int
    message: str


# --- Groups ---
class GroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    duration_days: int = Field(ge=21, le=30)
    max_missed_days: int = Field(default=3, ge=1, le=7)
    starts_at: date
    # Tasks the admin sets for everyone. Old app builds sent this as
    # "foundation_tasks", so both names are accepted.
    group_tasks: list[str] = Field(
        default_factory=list,
        max_length=15,
        validation_alias=AliasChoices("group_tasks", "foundation_tasks"),
    )
    task_mode: Literal["shared", "freedom"] = "shared"
    # The creator's own tasks when members choose their own ("freedom").
    personal_tasks: list[str] = Field(default_factory=list, max_length=10)
    # Public groups are listed in Discover for anyone to join without a code.
    is_public: bool = False


class GroupJoin(BaseModel):
    invite_code: str
    personal_tasks: list[str] = Field(default_factory=list)


class PublicGroupJoin(BaseModel):
    """Body for joining a public group by id — no invite code needed."""

    personal_tasks: list[str] = Field(default_factory=list)


class GroupInvitePreview(BaseModel):
    name: str
    duration_days: int
    task_mode: str
    group_tasks: list[str] = []
    foundation_tasks: list[str] = []  # same list, kept for older app builds
    starts_at: date
    max_missed_days: int
    leader_name: str | None = None
    member_count: int = 0


class PublicGroupSummary(BaseModel):
    """One row in the public groups directory (Discover)."""

    id: UUID
    name: str
    duration_days: int
    task_mode: str
    group_tasks: list[str] = []
    starts_at: date
    max_missed_days: int
    leader_name: str | None = None
    member_count: int = 0
    is_member: bool = False


class ChallengeTaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)


class GroupResponse(ORMModel):
    id: UUID
    name: str
    invite_code: str
    duration_days: int
    max_missed_days: int
    starts_at: date
    status: str
    task_mode: str = "shared"
    is_public: bool = False
    member_count: int = 0
    today_completion_percent: float = 0
    current_day: int = 1


class GroupMemberStatus(BaseModel):
    user_id: UUID
    full_name: str
    avatar_url: str | None = None
    role: str | None = None
    today_complete: bool = False
    hp: int = 0
    group_points: int = 0
    current_streak: int = 0
    discipline_score: int = 0
    missed_days: int = 0
    completion_percent: float = 0
    current_day: int = 1
    perfect_days: int = 0
    in_recovery: bool = False
    is_you: bool = False
    rank: int = 1
    rank_delta: int = 0


class GroupStatsSummary(BaseModel):
    participants: int = 0
    completed_today: int = 0
    today_completion_percent: float = 0
    average_hp: int = 0
    average_group_points: int = 0
    average_streak: int = 0
    your_rank: int = 1
    perfect_days: int = 0
    bonus_hp_unlocked: bool = False
    group_badge_unlocked: bool = False


class GroupDashboardInfo(BaseModel):
    id: UUID
    name: str
    invite_code: str
    duration_days: int
    max_missed_days: int
    starts_at: date
    status: str
    task_mode: str = "shared"
    is_public: bool = False
    member_count: int = 0
    is_leader: bool = False
    leader_id: UUID | None = None
    current_day: int = 1


class GroupDashboardResponse(BaseModel):
    group: GroupDashboardInfo
    stats: GroupStatsSummary
    members: list[GroupMemberStatus]
    announcements: list[dict] = []
    feed: list[dict] = []
    sessions: list[dict] = []


class AnnouncementCreate(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    body: str = Field(min_length=1, max_length=2000)
    is_pinned: bool = False


class GroupSessionCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    scheduled_at: datetime
    meeting_url: str | None = None
    meeting_type: str = "google_meet"
    notes: str | None = None


class GroupUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    max_missed_days: int | None = Field(default=None, ge=1, le=7)
    penalty_rules: dict | None = None
    is_public: bool | None = None


class GroupTaskBody(BaseModel):
    title: str = Field(min_length=1, max_length=255)


class GroupMessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=1000)

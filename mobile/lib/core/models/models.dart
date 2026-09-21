class ProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final int hp;
  final int disciplineScore;
  final int currentStreak;
  final int longestStreak;
  final int perfectWeeks;
  final int challengesCompleted;
  final int onboardingStep;
  final bool notificationsEnabled;
  final bool darkMode;
  final String locale;

  ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.hp,
    required this.disciplineScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.perfectWeeks,
    required this.challengesCompleted,
    required this.onboardingStep,
    required this.notificationsEnabled,
    required this.darkMode,
    this.locale = 'en',
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        hp: json['hp'] as int? ?? 100,
        disciplineScore: json['discipline_score'] as int? ?? 100,
        currentStreak: json['current_streak'] as int? ?? 0,
        longestStreak: json['longest_streak'] as int? ?? 0,
        perfectWeeks: json['perfect_weeks'] as int? ?? 0,
        challengesCompleted: json['challenges_completed'] as int? ?? 0,
        onboardingStep: json['onboarding_step'] as int? ?? 0,
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        darkMode: json['dark_mode'] as bool? ?? false,
        locale: json['locale'] as String? ?? 'en',
      );

  bool get needsOnboarding => onboardingStep < 6;
}

class TaskModel {
  final String id;
  final String title;
  final String type;
  final bool isCompleted;

  TaskModel({
    required this.id,
    required this.title,
    required this.type,
    required this.isCompleted,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        isCompleted: json['is_completed'] as bool? ?? false,
      );

  TaskModel copyWith({bool? isCompleted}) => TaskModel(
        id: id,
        title: title,
        type: type,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

class ChallengeDayModel {
  final int dayNumber;
  final String calendarDate;
  final bool isComplete;
  final bool isMissed;
  final bool isToday;
  final bool isLocked;

  ChallengeDayModel({
    required this.dayNumber,
    required this.calendarDate,
    required this.isComplete,
    required this.isMissed,
    required this.isToday,
    required this.isLocked,
  });

  factory ChallengeDayModel.fromJson(Map<String, dynamic> json) => ChallengeDayModel(
        dayNumber: json['day_number'] as int,
        calendarDate: json['calendar_date'] as String? ?? '',
        isComplete: json['is_complete'] as bool? ?? false,
        isMissed: json['is_missed'] as bool? ?? false,
        isToday: json['is_today'] as bool? ?? false,
        isLocked: json['is_locked'] as bool? ?? false,
      );

  DateTime? get date {
    try {
      return DateTime.parse(calendarDate);
    } catch (_) {
      return null;
    }
  }
}

class ChallengeModel {
  final String id;
  final String name;
  final String status;
  final int durationDays;
  final int currentDay;
  final double progressPercent;
  final int remainingDays;
  final String? todayMission;
  final String? quote;
  final int? leaderboardPosition;
  final List<TaskModel> tasks;
  final double? recoveryHoursLeft;
  final List<ChallengeDayModel> days;
  final bool dayComplete;
  final String type;
  final String? groupId;
  final DateTime? startDate;
  final int daysUntilStart;
  final int pointsToday;
  final int penaltyPoints;

  ChallengeModel({
    required this.id,
    required this.name,
    required this.status,
    required this.durationDays,
    required this.currentDay,
    required this.progressPercent,
    required this.remainingDays,
    this.todayMission,
    this.quote,
    this.leaderboardPosition,
    required this.tasks,
    this.recoveryHoursLeft,
    this.days = const [],
    this.dayComplete = false,
    this.type = 'individual',
    this.groupId,
    this.startDate,
    this.daysUntilStart = 0,
    this.pointsToday = 0,
    this.penaltyPoints = 0,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) => ChallengeModel(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        durationDays: json['duration_days'] as int,
        currentDay: json['current_day'] as int? ?? 1,
        progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0,
        remainingDays: json['remaining_days'] as int? ?? 0,
        todayMission: json['today_mission'] as String?,
        quote: json['quote'] as String?,
        leaderboardPosition: json['leaderboard_position'] as int?,
        tasks: (json['tasks'] as List<dynamic>? ?? [])
            .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        recoveryHoursLeft: (json['recovery_hours_left'] as num?)?.toDouble(),
        days: (json['days'] as List<dynamic>? ?? [])
            .map((e) => ChallengeDayModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        dayComplete: json['day_complete'] as bool? ?? false,
        type: json['type'] as String? ?? 'individual',
        groupId: json['group_id'] as String?,
        startDate: json['start_date'] == null
            ? null
            : DateTime.tryParse(json['start_date'] as String),
        daysUntilStart: json['days_until_start'] as int? ?? 0,
        pointsToday: json['points_today'] as int? ?? 0,
        penaltyPoints: json['penalty_points'] as int? ?? 0,
      );

  /// A personal challenge whose start date is still in the future.
  bool get isScheduled => daysUntilStart > 0;

  bool get isRecovery => status == 'recovery';
  bool get isGroup => type == 'group';
  bool get allTasksComplete => tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
}

class ActiveProgramsModel {
  final ChallengeModel? personal;
  final ChallengeModel? group;

  ActiveProgramsModel({this.personal, this.group});

  factory ActiveProgramsModel.fromJson(Map<String, dynamic> json) => ActiveProgramsModel(
        personal: json['personal'] == null
            ? null
            : ChallengeModel.fromJson(json['personal'] as Map<String, dynamic>),
        group: json['group'] == null
            ? null
            : ChallengeModel.fromJson(json['group'] as Map<String, dynamic>),
      );

  bool get isEmpty => personal == null && group == null;
}

class ChallengeSummaryModel {
  final String id;
  final String name;
  final String status;
  final int durationDays;
  final int currentDay;

  ChallengeSummaryModel({
    required this.id,
    required this.name,
    required this.status,
    required this.durationDays,
    required this.currentDay,
  });

  factory ChallengeSummaryModel.fromJson(Map<String, dynamic> json) => ChallengeSummaryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        durationDays: json['duration_days'] as int,
        currentDay: json['current_day'] as int? ?? 1,
      );
}

class GoalModel {
  final int id;
  final String slug;
  final String name;
  final String? icon;

  GoalModel({required this.id, required this.slug, required this.name, this.icon});

  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
        id: json['id'] as int,
        slug: json['slug'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
      );
}

class LeaderboardEntryModel {
  final int rank;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int value;
  final bool isYou;

  LeaderboardEntryModel({
    required this.rank,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.value,
    this.isYou = false,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntryModel(
        rank: json['rank'] as int,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        value: json['value'] as int,
        isYou: json['is_you'] as bool? ?? false,
      );
}

class GroupModel {
  final String id;
  final String name;
  final String inviteCode;
  final int durationDays;
  final int maxMissedDays;
  final String startsAt;
  final String status;
  final String taskMode;
  final int memberCount;
  final double todayCompletionPercent;
  final int currentDay;

  GroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.durationDays,
    required this.maxMissedDays,
    required this.startsAt,
    required this.status,
    this.taskMode = 'shared',
    required this.memberCount,
    this.todayCompletionPercent = 0,
    this.currentDay = 1,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['invite_code'] as String,
        durationDays: json['duration_days'] as int,
        maxMissedDays: json['max_missed_days'] as int? ?? 3,
        startsAt: json['starts_at'] as String,
        status: json['status'] as String,
        taskMode: json['task_mode'] as String? ?? 'shared',
        memberCount: json['member_count'] as int? ?? 0,
        todayCompletionPercent: (json['today_completion_percent'] as num?)?.toDouble() ?? 0,
        currentDay: json['current_day'] as int? ?? 1,
      );
}

class BadgeModel {
  final int id;
  final String code;
  final String name;
  final String description;
  final bool earned;

  BadgeModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.earned,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) => BadgeModel(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        earned: json['earned'] as bool? ?? false,
      );
}

class CertificateModel {
  final String id;
  final String certificateNo;
  final String title;
  final int durationDays;
  final String issuedAt;

  CertificateModel({
    required this.id,
    required this.certificateNo,
    required this.title,
    required this.durationDays,
    required this.issuedAt,
  });

  factory CertificateModel.fromJson(Map<String, dynamic> json) => CertificateModel(
        id: json['id'] as String,
        certificateNo: json['certificate_no'] as String,
        title: json['title'] as String,
        durationDays: json['duration_days'] as int,
        issuedAt: json['issued_at'] as String,
      );
}

class ChallengeCategory {
  final String id;
  final String label;

  const ChallengeCategory({required this.id, required this.label});

  factory ChallengeCategory.fromJson(Map<String, dynamic> json) =>
      ChallengeCategory(id: json['id'] as String, label: json['label'] as String);
}

/// A ready-made challenge framework (e.g. "Social Media Detox").
class ChallengeTemplate {
  final String id;
  final String title;
  final String category;
  final String difficulty;
  final String icon;
  final String description;
  final int durationDays;
  final List<String> tasks;

  const ChallengeTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.icon,
    required this.description,
    required this.durationDays,
    required this.tasks,
  });

  factory ChallengeTemplate.fromJson(Map<String, dynamic> json) => ChallengeTemplate(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        difficulty: json['difficulty'] as String? ?? 'medium',
        icon: json['icon'] as String? ?? 'flag',
        description: json['description'] as String? ?? '',
        durationDays: json['duration_days'] as int? ?? 21,
        tasks: List<String>.from(json['tasks'] as List? ?? const []),
      );

  String get difficultyLabel =>
      difficulty.isEmpty ? '' : difficulty[0].toUpperCase() + difficulty.substring(1);
}

class ChallengeCatalog {
  final List<ChallengeCategory> categories;
  final List<ChallengeTemplate> templates;

  const ChallengeCatalog({required this.categories, required this.templates});

  factory ChallengeCatalog.fromJson(Map<String, dynamic> json) => ChallengeCatalog(
        categories: (json['categories'] as List)
            .map((e) => ChallengeCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        templates: (json['templates'] as List)
            .map((e) => ChallengeTemplate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A group in the group leaderboard.
class GroupRankModel {
  final int rank;
  final String groupId;
  final String name;
  final int memberCount;
  final int totalPoints;
  final int averagePoints;
  final int currentDay;
  final int durationDays;
  final bool isYours;

  const GroupRankModel({
    required this.rank,
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.totalPoints,
    required this.averagePoints,
    required this.currentDay,
    required this.durationDays,
    required this.isYours,
  });

  factory GroupRankModel.fromJson(Map<String, dynamic> json) => GroupRankModel(
        rank: json['rank'] as int,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        memberCount: json['member_count'] as int? ?? 0,
        totalPoints: json['total_points'] as int? ?? 0,
        averagePoints: json['average_points'] as int? ?? 0,
        currentDay: json['current_day'] as int? ?? 1,
        durationDays: json['duration_days'] as int? ?? 21,
        isYours: json['is_yours'] as bool? ?? false,
      );
}

/// One chat message in a group.
class ChatMessageModel {
  final String id;
  final String userId;
  final String fullName;
  final bool isLeader;
  final bool isYou;
  final String body;
  final bool isDeleted;
  final DateTime createdAt;

  /// Local-only: still being sent, or failed to send.
  final bool pending;
  final bool failed;

  const ChatMessageModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.isLeader,
    required this.isYou,
    required this.body,
    required this.isDeleted,
    required this.createdAt,
    this.pending = false,
    this.failed = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String? ?? 'Member',
        isLeader: json['is_leader'] as bool? ?? false,
        isYou: json['is_you'] as bool? ?? false,
        body: json['body'] as String? ?? '',
        isDeleted: json['is_deleted'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );

  ChatMessageModel copyWith({bool? pending, bool? failed}) => ChatMessageModel(
        id: id,
        userId: userId,
        fullName: fullName,
        isLeader: isLeader,
        isYou: isYou,
        body: body,
        isDeleted: isDeleted,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );
}

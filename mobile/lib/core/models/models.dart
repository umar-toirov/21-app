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
      );

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

  LeaderboardEntryModel({
    required this.rank,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.value,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntryModel(
        rank: json['rank'] as int,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        value: json['value'] as int,
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

class PaymentModel {
  final String id;
  final int amountUzs;
  final String status;
  final String? provider;
  final String createdAt;

  PaymentModel({
    required this.id,
    required this.amountUzs,
    required this.status,
    this.provider,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] as String,
        amountUzs: json['amount_uzs'] as int,
        status: json['status'] as String,
        provider: json['provider'] as String?,
        createdAt: json['created_at'] as String,
      );
}

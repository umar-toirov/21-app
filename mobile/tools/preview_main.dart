// Visual preview harness: renders key screens with sample data, no login or API.
//
//   flutter build web --debug -t tools/preview_main.dart --output build/preview
//   open  index.html?screen=<name>[&dark=1][&tab=1][&groups=1]
//
// Screens: detail, home, picker, setup, intro, group (tab=0..3), leaderboard
// (groups=1), create, join. Handy for screenshots and design review; not shipped.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ilm_mode/core/cache/app_cache.dart';
import 'package:ilm_mode/core/models/models.dart';
import 'package:ilm_mode/core/providers/providers.dart';
import 'package:ilm_mode/core/services/sound_service.dart';
import 'package:ilm_mode/core/theme/app_theme.dart';
import 'package:ilm_mode/core/widgets/brand_intro.dart';
import 'package:ilm_mode/features/challenge/presentation/screens/challenge_dashboard_screen.dart';
import 'package:ilm_mode/features/challenge/presentation/screens/challenge_detail_screen.dart';
import 'package:ilm_mode/features/challenge/presentation/screens/challenge_setup_screen.dart';
import 'package:ilm_mode/features/group_challenge/presentation/screens/create_group_screen.dart';
import 'package:ilm_mode/features/group_challenge/presentation/screens/group_home_screen.dart';
import 'package:ilm_mode/features/group_challenge/presentation/screens/join_group_screen.dart';
import 'package:ilm_mode/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:ilm_mode/features/statistics/presentation/widgets/leaderboard_tab.dart';

const _templates = [
  ChallengeTemplate(id: 'a', title: 'Social Media Detox', category: 'detox', difficulty: 'hard', icon: 'phone_off', description: 'Take back the hours social media quietly takes.', durationDays: 21, tasks: ['No social media today', 'Log out of the apps', 'Replace scrolling with a walk or a book']),
  ChallengeTemplate(id: 'b', title: '10-Minute Meditation', category: 'mind', difficulty: 'easy', icon: 'meditate', description: 'Train calm and focus.', durationDays: 21, tasks: ['Meditate for 10 minutes', 'Note how you feel']),
  ChallengeTemplate(id: 'c', title: 'No Junk Food', category: 'food', difficulty: 'medium', icon: 'food_off', description: 'Skip the fast food.', durationDays: 21, tasks: ['Skip junk food', 'Eat a real meal']),
  ChallengeTemplate(id: 'd', title: 'Study Every Day', category: 'learn', difficulty: 'medium', icon: 'book', description: 'Show up daily.', durationDays: 21, tasks: ['Study for 1 hour', 'Review notes']),
];

const _catalog = ChallengeCatalog(
  categories: [
    ChallengeCategory(id: 'health', label: 'Health & Fitness'),
    ChallengeCategory(id: 'mind', label: 'Mindfulness'),
    ChallengeCategory(id: 'learn', label: 'Learning'),
    ChallengeCategory(id: 'detox', label: 'Digital Detox'),
  ],
  templates: _templates,
);

ChallengeModel _challenge({bool group = false}) {
  final today = DateTime.now();
  return ChallengeModel(
    id: 'c1',
    name: group ? 'Study Squad Group Challenge' : 'Social Media Detox',
    status: 'active',
    durationDays: 21,
    currentDay: 4,
    progressPercent: 14,
    remainingDays: 18,
    todayMission: 'Complete: No social media today',
    quote: '"Discipline is choosing between what you want now and what you want most." — Abraham Lincoln',
    tasks: [
      TaskModel(id: 'f1', title: group ? 'Read 20 pages' : 'Wake up on time', type: 'foundation', isCompleted: true),
      TaskModel(id: 'f2', title: group ? 'Walk 30 minutes' : 'Daily planning', type: 'foundation', isCompleted: false),
      TaskModel(id: 'p1', title: group ? 'Code 1 hour' : 'No social media today', type: 'personal', isCompleted: false),
    ],
    days: [
      for (var i = 0; i < 21; i++)
        ChallengeDayModel(
          dayNumber: i + 1,
          calendarDate: today.add(Duration(days: i - 3)).toIso8601String().split('T').first,
          isComplete: i == 0 || i == 2,
          isMissed: i == 1,
          isToday: i == 3,
          isLocked: i > 3,
        ),
    ],
    pointsToday: 5,
    type: group ? 'group' : 'individual',
    groupId: group ? 'g1' : null,
  );
}

ProfileModel _profile() => ProfileModel(
      id: 'u',
      email: 'a@b.c',
      fullName: 'Muhammadumar',
      hp: 85,
      disciplineScore: 0,
      currentStreak: 1,
      longestStreak: 2,
      perfectWeeks: 0,
      challengesCompleted: 0,
      onboardingStep: 0,
      notificationsEnabled: true,
      darkMode: false,
    );

String _ago(int minutes) => DateTime.now().subtract(Duration(minutes: minutes)).toUtc().toIso8601String();

/// Sample data for every screen. Only the calls the previews make are implemented.
class _PreviewApi implements ApiRepository {
  @override
  Future<Map<String, dynamic>> getGroupDashboard(String groupId) async => {
        'group': {
          'id': 'g1', 'name': 'Study Squad', 'invite_code': 'K7QX2M', 'duration_days': 21,
          'max_missed_days': 3, 'starts_at': '2026-09-17', 'status': 'active', 'task_mode': 'shared',
          'member_count': 6, 'is_leader': true, 'current_day': 4,
        },
        'stats': {'participants': 6, 'completed_today': 3, 'average_group_points': 42},
        'members': [
          for (final (i, m) in [('Ana', 120, true), ('Ben', 95, true), ('Muhammadumar', 60, false), ('Cy', 45, true), ('Dilnoza', 30, false), ('Eldor', 5, false)].indexed)
            {
              'user_id': 'u$i', 'full_name': m.$1, 'group_points': m.$2, 'rank': i + 1,
              'current_streak': 3 - i.clamp(0, 3), 'today_complete': m.$3, 'is_you': m.$1 == 'Muhammadumar',
              'role': i == 0 ? 'leader' : 'member', 'completion_percent': 40.0, 'current_day': 4,
            }
        ],
        'announcements': [
          {'id': 'a1', 'title': 'Welcome!', 'body': 'Daily check-in closes at midnight. Keep going, team.', 'is_pinned': true},
          {'id': 'a2', 'title': null, 'body': 'New task added: Walk 30 minutes.', 'is_pinned': false},
        ],
        'feed': [
          {'id': 'f1', 'activity_type': 'task_complete', 'message': 'Ana completed today\'s mission', 'created_at': _ago(20)},
          {'id': 'f2', 'activity_type': 'member_joined', 'message': 'Dilnoza joined the group', 'created_at': _ago(240)},
        ],
        'sessions': <dynamic>[],
      };

  @override
  Future<Map<String, dynamic>> getGroupStatistics(String groupId) async => {
        'completion_percent': 64.0, 'average_group_points': 42, 'daily_active': 3, 'longest_streak': 3,
        'weekly_trend': [
          for (var i = 0; i < 7; i++) {'day': i, 'value': 30.0 + i * 8},
        ],
        'top_performer': {'name': 'Ana', 'score': 120},
      };

  @override
  Future<Map<String, dynamic>> getGroupDayRoster(String groupId, {String? date}) async => {
        'date': '2026-09-20', 'prev_date': null, 'next_date': null, 'starts_at': '2026-09-17', 'ends_at': '2026-10-07', 'members': <dynamic>[],
      };

  @override
  Future<({List<ChatMessageModel> messages, bool hasMore})> getGroupMessages(
    String groupId, {String? after, String? before, int limit = 50}) async {
    ChatMessageModel m(String id, String name, String body, int mins, {bool you = false, bool leader = false}) =>
        ChatMessageModel(
          id: id, userId: you ? 'me' : 'u-$name', fullName: name, isLeader: leader, isYou: you, body: body,
          isDeleted: false, createdAt: DateTime.now().subtract(Duration(minutes: mins)),
        );
    return (
      messages: [
        m('1', 'Ana', 'Welcome everyone! Day 1 is today, let\'s go 💪', 3000, leader: true),
        m('2', 'Ben', 'Done with reading already', 2900),
        m('3', 'Ben', 'Who is up for a walk later?', 2898),
        m('4', 'Muhammadumar', 'Me! Finishing my code hour first.', 2890, you: true),
        m('5', 'Ana', 'Nice work Ben, you are on top of the ranking now.', 40, leader: true),
        m('6', 'Muhammadumar', 'Catching up tomorrow, promise', 12, you: true),
      ],
      hasMore: false,
    );
  }

  @override
  Future<Map<String, dynamic>> getActivity(String month) async {
    final now = DateTime.now();
    String d(int day) => '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final today = now.day;
    return {
      'month': month,
      'days': [
        for (var day = 1; day <= today; day++)
          {
            'date': d(day),
            'status': day == today ? 'partial' : (day % 5 == 0 ? 'missed' : (day % 7 == 3 ? 'partial' : 'done')),
            'done': 3,
            'tasks': [
              {'title': 'Read 20 pages', 'kind': 'group', 'challenge': 'Study Squad', 'completed_at': '${d(day)}T07:40:00+00:00'},
              {'title': 'No social media today', 'kind': 'personal', 'challenge': 'Social Media Detox', 'completed_at': '${d(day)}T18:05:00+00:00'},
            ],
          },
      ],
      'totals': {'tasks_done': today * 3, 'perfect_days': today - 3, 'missed_days': 2},
    };
  }

  @override
  Future<List<LeaderboardEntryModel>> getLeaderboard(String metric) async => [
        LeaderboardEntryModel(rank: 1, userId: '1', fullName: 'Ana Karimova', value: 240),
        LeaderboardEntryModel(rank: 2, userId: '2', fullName: 'Ben Yusupov', value: 190),
        LeaderboardEntryModel(rank: 3, userId: '3', fullName: 'Cy Rakhimov', value: 155),
        LeaderboardEntryModel(rank: 4, userId: '4', fullName: 'Dilnoza', value: 120),
        LeaderboardEntryModel(rank: 5, userId: 'u', fullName: 'Muhammadumar', value: 85, isYou: true),
        LeaderboardEntryModel(rank: 6, userId: '6', fullName: 'Eldor', value: 40),
      ];

  @override
  Future<Map<String, dynamic>> getMyRank(String metric) async => {'rank': 5, 'value': 85, 'total': 48};

  @override
  Future<List<GroupRankModel>> getGroupsLeaderboard(String metric) async => [
        const GroupRankModel(rank: 1, groupId: 'x', name: 'Iron Habits', memberCount: 9, totalPoints: 640, averagePoints: 71, currentDay: 6, durationDays: 21, isYours: false),
        const GroupRankModel(rank: 2, groupId: 'g1', name: 'Study Squad', memberCount: 6, totalPoints: 355, averagePoints: 59, currentDay: 4, durationDays: 21, isYours: true),
        const GroupRankModel(rank: 3, groupId: 'y', name: 'Early Birds', memberCount: 4, totalPoints: 210, averagePoints: 52, currentDay: 9, durationDays: 30, isYours: false),
        const GroupRankModel(rank: 4, groupId: 'z', name: 'No Sugar Club', memberCount: 12, totalPoints: 180, averagePoints: 15, currentDay: 2, durationDays: 21, isYours: false),
      ];

  @override
  Future<Map<String, dynamic>> previewGroupInvite(String inviteCode) async => {
        'name': 'Study Squad', 'duration_days': 21, 'task_mode': 'shared',
        'group_tasks': ['Read 20 pages', 'Walk 30 minutes', 'No phone before bed'],
        'starts_at': '2026-10-01', 'max_missed_days': 3, 'leader_name': 'Ana Karimova', 'member_count': 6,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  final params = Uri.base.queryParameters;
  await AppCache.init();
  if (params['walk'] != '1') AppCache.setFlag('how_it_works_seen');
  final screen = params['screen'] ?? 'detail';
  final dark = params['dark'] == '1';
  final tab = int.tryParse(params['tab'] ?? '') ?? 0;
  AppColors.isDark = dark;
  SoundService.instance.enabled = false;

  final router = GoRouter(
    initialLocation: '/$screen',
    routes: [
      GoRoute(path: '/detail', builder: (_, __) => const ChallengeDetailScreen(challengeId: 'c1')),
      GoRoute(path: '/gdetail', builder: (_, __) => const ChallengeDetailScreen(challengeId: 'cg')),
      GoRoute(path: '/home', builder: (_, __) => const ChallengeDashboardScreen()),
      GoRoute(path: '/picker', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/setup', builder: (_, __) => ChallengeSetupScreen(template: _templates.first)),
      GoRoute(path: '/intro', builder: (_, __) => const BrandIntroScene()),
      GoRoute(path: '/group', builder: (_, __) => GroupHomeScreen(groupId: 'g1', initialTab: tab)),
      GoRoute(
        path: '/leaderboard',
        builder: (_, __) => Scaffold(
          body: SafeArea(child: LeaderboardTab(initialGroups: params['groups'] == '1')),
        ),
      ),
      GoRoute(path: '/create', builder: (_, __) => const CreateGroupScreen()),
      GoRoute(path: '/join', builder: (_, __) => const JoinGroupScreen(initialCode: 'K7QX2M')),
    ],
  );

  runApp(ProviderScope(
    overrides: [
      apiRepositoryProvider.overrideWithValue(_PreviewApi()),
      challengeCatalogProvider.overrideWith((ref) async => _catalog),
      challengeDetailProvider.overrideWith((ref, id) async => _challenge(group: id == 'cg')),
      profileProvider.overrideWith((ref) => Stream.value(_profile())),
      activeProgramsProvider.overrideWith(
        (ref) => Stream.value(ActiveProgramsModel(personal: _challenge(), group: _challenge(group: true))),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ),
  ));
}

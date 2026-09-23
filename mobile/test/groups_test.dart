import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ilm_mode/core/models/models.dart';
import 'package:ilm_mode/core/providers/providers.dart';
import 'package:ilm_mode/core/router/app_router.dart';
import 'package:ilm_mode/core/services/sound_service.dart';
import 'package:ilm_mode/core/theme/app_theme.dart';
import 'package:ilm_mode/core/widgets/ranking_widgets.dart';
import 'package:ilm_mode/features/challenge/presentation/widgets/activity_calendar.dart';
import 'package:ilm_mode/features/group_challenge/presentation/screens/create_group_screen.dart';
import 'package:ilm_mode/features/group_challenge/presentation/screens/discover_groups_screen.dart';
import 'package:ilm_mode/features/group_challenge/presentation/screens/join_group_screen.dart';
import 'package:ilm_mode/features/group_challenge/presentation/widgets/group_chat.dart';
import 'package:ilm_mode/features/statistics/presentation/widgets/leaderboard_tab.dart';

class _FakeApi implements ApiRepository {
  Map<String, dynamic>? createdGroup;
  Map<String, dynamic> preview = {
    'name': 'Study Squad',
    'duration_days': 21,
    'task_mode': 'shared',
    'group_tasks': ['Read 20 pages', 'Walk 30 minutes'],
    'foundation_tasks': ['Read 20 pages', 'Walk 30 minutes'],
    'starts_at': '2026-10-01',
    'max_missed_days': 3,
    'leader_name': 'Ana',
    'member_count': 4,
  };
  String? joinedCode;
  List<String>? joinedTasks;
  List<PublicGroupModel> publicGroups = [];
  String? joinedPublicGroupId;
  List<String>? joinedPublicGroupTasks;

  final sent = <String>[];
  final deleted = <String>[];
  bool failSend = false;
  Completer<void>? gate;
  List<ChatMessageModel> messages = [];

  @override
  Future<GroupModel> createGroup(Map<String, dynamic> data) async {
    createdGroup = data;
    return _group;
  }

  @override
  Future<Map<String, dynamic>> previewGroupInvite(String inviteCode) async => preview;

  @override
  Future<GroupModel> joinGroup(String inviteCode, {List<String>? personalTasks}) async {
    joinedCode = inviteCode;
    joinedTasks = personalTasks;
    return _group;
  }

  @override
  Future<List<PublicGroupModel>> getPublicGroups() async => publicGroups;

  @override
  Future<GroupModel> joinPublicGroup(String groupId, {List<String>? personalTasks}) async {
    joinedPublicGroupId = groupId;
    joinedPublicGroupTasks = personalTasks;
    return _group;
  }

  @override
  Future<({List<ChatMessageModel> messages, bool hasMore})> getGroupMessages(
    String groupId, {
    String? after,
    String? before,
    int limit = 50,
  }) async =>
      (messages: List.of(messages), hasMore: false);

  @override
  Future<ChatMessageModel> postGroupMessage(String groupId, String body) async {
    await gate?.future;
    if (failSend) throw Exception('offline');
    sent.add(body);
    return _msg('srv-${sent.length}', 'Me', body, you: true);
  }

  @override
  Future<void> deleteGroupMessage(String groupId, String messageId) async =>
      deleted.add(messageId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _group = GroupModel(
  id: 'g1',
  name: 'Study Squad',
  inviteCode: 'ABC123',
  durationDays: 21,
  maxMissedDays: 3,
  startsAt: '2026-10-01',
  status: 'active',
  memberCount: 1,
);

ChatMessageModel _msg(String id, String name, String body,
    {bool you = false, bool leader = false, DateTime? at, bool deleted = false}) {
  return ChatMessageModel(
    id: id,
    userId: you ? 'me' : 'u-$name',
    fullName: name,
    isLeader: leader,
    isYou: you,
    body: body,
    isDeleted: deleted,
    createdAt: at ?? DateTime.now(),
  );
}

ThemeData _theme(bool dark) => (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget _wrap(Widget child, {List<Override> overrides = const [], bool dark = false}) {
  AppColors.isDark = dark;
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(
        path: '/groups/:id/dashboard',
        builder: (_, __) => const Scaffold(body: Text('GROUP DASHBOARD')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: _theme(dark),
      routerConfig: router,
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SoundService.instance.enabled = false);

  // ------------------------------------------------------------------ create
  group('create group', () {
    Widget app(_FakeApi api, {bool dark = false}) => ProviderScope(
          overrides: [apiRepositoryProvider.overrideWithValue(api)],
          child: _createApp(dark),
        );

    testWidgets('has no foundation tasks and explains the two modes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(app(_FakeApi()));
      await tester.pumpAndSettle();

      expect(find.textContaining('You will be the admin'), findsOneWidget);
      await _scrollTo(tester, find.text('Same tasks for everyone'));
      expect(find.text('Same tasks for everyone'), findsOneWidget);
      expect(find.text('Members choose their own'), findsOneWidget);
      expect(find.textContaining('oundation'), findsNothing);
      // Only one editor (tasks for everyone) until members may choose.
      await _scrollTo(tester, find.text('Create group'));
      expect(find.textContaining('Your own tasks'), findsNothing);
    });

    testWidgets('needs a name and at least one task', (tester) async {
      _phone(tester);
      final api = _FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Give your group a name.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Morning Squad');
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      // The toast sits above the button, so a second tap is never blocked.
      expect(find.text('Add at least one task for the group.'), findsOneWidget);
      expect(api.createdGroup, isNull);
    });

    testWidgets('sends group tasks and opens the group', (tester) async {
      _phone(tester);
      final api = _FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Morning Squad');
      await _scrollTo(tester, find.text('Read 20 pages')); // a suggestion chip
      await tester.tap(find.text('Read 20 pages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      final sent = api.createdGroup!;
      expect(sent['name'], 'Morning Squad');
      expect(sent['task_mode'], 'shared');
      expect(sent['group_tasks'], ['Read 20 pages']);
      expect(sent['personal_tasks'], isEmpty);
      expect(sent.containsKey('foundation_tasks'), isFalse);
      expect(find.text('GROUP DASHBOARD'), findsOneWidget);
    });

    testWidgets('is private by default; Public sends is_public true', (tester) async {
      _phone(tester);
      final api = _FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Morning Squad');
      await _scrollTo(tester, find.text('Read 20 pages'));
      await tester.tap(find.text('Read 20 pages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(api.createdGroup!['is_public'], isFalse);
    });

    testWidgets('tapping Public sends is_public true', (tester) async {
      _phone(tester);
      final api = _FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Open Squad');
      await _scrollTo(tester, find.text('Public'));
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Read 20 pages'));
      await tester.tap(find.text('Read 20 pages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(api.createdGroup!['is_public'], isTrue);
    });

    testWidgets('members-choose mode also asks for the admin\'s own tasks', (tester) async {
      _phone(tester);
      final api = _FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Free Squad');
      await _scrollTo(tester, find.text('Members choose their own'));
      await tester.tap(find.text('Members choose their own'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.textContaining('Your own tasks'));
      expect(find.textContaining('Your own tasks'), findsOneWidget);

      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least one task for yourself or for the group.'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------ join
  group('join group', () {
    Widget app(_FakeApi api) => ProviderScope(
          overrides: [
            apiRepositoryProvider.overrideWithValue(api),
            activeProgramsProvider.overrideWith(
              (ref) => Stream.value(ActiveProgramsModel()),
            ),
          ],
          child: _joinApp(),
        );

    testWidgets('shows the admin\'s tasks read-only when tasks are shared', (tester) async {
      _phone(tester);
      final api = _FakeApi();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.text('Find group'));
      await tester.pumpAndSettle();

      expect(find.text('Study Squad'), findsWidgets);
      expect(find.text('Admin: Ana'), findsOneWidget);
      expect(find.text('4 members'), findsOneWidget);
      expect(find.text('Read 20 pages'), findsOneWidget);
      expect(find.text('Walk 30 minutes'), findsOneWidget);
      expect(find.textContaining('Everyone does the same tasks'), findsOneWidget);
      expect(find.textContaining('Choose your own'), findsNothing);

      await tester.tap(find.text('Join Study Squad'));
      await tester.pumpAndSettle();
      expect(api.joinedCode, 'ABC123');
      expect(api.joinedTasks, isNull);
      expect(find.text('GROUP DASHBOARD'), findsOneWidget);
    });

    testWidgets('asks members to choose tasks when the group allows it', (tester) async {
      _phone(tester);
      final api = _FakeApi()
        ..preview = {
          ...(_FakeApi().preview),
          'task_mode': 'freedom',
          'group_tasks': <String>[],
          'foundation_tasks': <String>[],
        };
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.tap(find.text('Find group'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.textContaining('Choose your own tasks'));
      await tester.tap(find.text('Join Study Squad'));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least one task for yourself.'), findsOneWidget);
      expect(api.joinedCode, isNull);

      await _scrollTo(tester, find.text('Workout 30 minutes'));
      await tester.tap(find.text('Workout 30 minutes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Study Squad'));
      await tester.pumpAndSettle();
      expect(api.joinedTasks, ['Workout 30 minutes']);
    });
  });

  // ------------------------------------------------------------------ chat
  group('group chat', () {
    Widget app(_FakeApi api, {bool dark = false}) => _wrap(
          const GroupChatTab(groupId: 'g1', isLeader: false),
          overrides: [apiRepositoryProvider.overrideWithValue(api)],
          dark: dark,
        );

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink()); // stops the polling timer
      await tester.pump();
    }

    for (final dark in [false, true]) {
      testWidgets('shows messages with names, admin badge and day separator (${dark ? 'dark' : 'light'})',
          (tester) async {
        _phone(tester);
        final api = _FakeApi()
          ..messages = [
            _msg('1', 'Ana', 'Welcome team!', leader: true),
            _msg('2', 'Ben', 'Hi all'),
            _msg('3', 'Me', 'Ready!', you: true),
          ];
        await tester.pumpWidget(app(api, dark: dark));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Welcome team!'), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
        expect(find.text('Ben'), findsOneWidget);
        expect(find.text('Ready!'), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('empty chat invites people to say hi', (tester) async {
      _phone(tester);
      await tester.pumpWidget(app(_FakeApi()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('No messages yet'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sending shows the message instantly, then confirms it', (tester) async {
      _phone(tester);
      final api = _FakeApi()..gate = Completer<void>(); // the server is slow to answer
      await tester.pumpWidget(app(api));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'See you at 6');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(); // the very next frame already shows it
      expect(find.text('See you at 6'), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);

      api.gate!.complete();
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.sent, ['See you at 6']);
      expect(find.text('Sending…'), findsNothing);
      expect(find.text('See you at 6'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a failed send can be retried', (tester) async {
      _phone(tester);
      final api = _FakeApi()..failSend = true;
      await tester.pumpWidget(app(api));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining("Couldn't send"), findsOneWidget);

      api.failSend = false;
      await tester.tap(find.text('Hello?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(api.sent, ['Hello?']);
      await unmount(tester);
    });

    testWidgets('you can delete your own message', (tester) async {
      _phone(tester);
      final api = _FakeApi()..messages = [_msg('m1', 'Me', 'oops', you: true)];
      await tester.pumpWidget(app(api));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      await tester.longPress(find.text('oops'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete message'));
      await tester.pumpAndSettle();
      expect(api.deleted, ['m1']);
      await unmount(tester);
    });
  });

  // ------------------------------------------------------------------ ranking
  group('rankings', () {
    for (final dark in [false, true]) {
      testWidgets('podium shows points for 1st, 2nd and 3rd (${dark ? 'dark' : 'light'})',
          (tester) async {
        _phone(tester);
        AppColors.isDark = dark;
        await tester.pumpWidget(MaterialApp(
          theme: _theme(dark),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RankList(entries: const [
                RankEntry(rank: 1, name: 'Ana', value: 120),
                RankEntry(rank: 2, name: 'Ben', value: 95),
                RankEntry(rank: 3, name: 'Cy', value: 60, isYou: true),
                RankEntry(rank: 4, name: 'Dee', value: 45, subtitle: '3 day streak'),
              ]),
            ),
          ),
        ));
        expect(find.text('120 pts'), findsOneWidget);
        expect(find.text('95 pts'), findsOneWidget);
        expect(find.text('60 pts'), findsOneWidget);
        expect(find.text('Cy'), findsOneWidget); // your own place keeps your name
        expect(find.text('Dee'), findsOneWidget);
        expect(find.text('45'), findsOneWidget);
        expect(find.text('3 day streak'), findsOneWidget);
      });
    }

    testWidgets('leaderboard: people by points, then groups by total and average', (tester) async {
      _phone(tester);
      AppColors.isDark = false;
      final groups = [
        const GroupRankModel(
            rank: 1, groupId: 'a', name: 'Alpha', memberCount: 2, totalPoints: 70,
            averagePoints: 35, currentDay: 4, durationDays: 21, isYours: true),
        const GroupRankModel(
            rank: 2, groupId: 'b', name: 'Beta', memberCount: 3, totalPoints: 60,
            averagePoints: 20, currentDay: 2, durationDays: 30, isYours: false),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          leaderboardProvider.overrideWith((ref, metric) async => [
                LeaderboardEntryModel(rank: 1, userId: '1', fullName: 'Ana', value: 200),
                LeaderboardEntryModel(rank: 2, userId: '2', fullName: 'Ben', value: 150),
                LeaderboardEntryModel(rank: 3, userId: '3', fullName: 'Cy', value: 90, isYou: true),
              ]),
          myRankProvider.overrideWith((ref, metric) async => {'rank': 3, 'value': 90, 'total': 12}),
          groupsLeaderboardProvider.overrideWith((ref, metric) async => groups),
        ],
        child: MaterialApp(
          theme: _theme(false),
          home: const Scaffold(body: LeaderboardTab()),
        ),
      ));
      await tester.pumpAndSettle();

      // People, ranked by points, with numbers on the podium and a personal rank card.
      expect(find.text('200 pts'), findsOneWidget);
      expect(find.text('150 pts'), findsOneWidget);
      expect(find.text('90 pts'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('of 12 people'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Discipline'), findsNothing); // the redundant metric is gone

      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('70 pts'), findsOneWidget);
      expect(find.textContaining('Day 4/21'), findsOneWidget);

      await tester.tap(find.text('Average per member'));
      await tester.pumpAndSettle();
      expect(find.text('35 avg pts'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------ calendar
  group('activity calendar', () {
    testWidgets('colours days and lists the tasks done on a day', (tester) async {
      _phone(tester);
      AppColors.isDark = false;
      final now = DateTime.now();
      String d(int day) =>
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activityProvider.overrideWith((ref, month) async => {
                'month': month,
                'days': [
                  {
                    'date': d(1),
                    'status': 'done',
                    'done': 2,
                    'tasks': [
                      {'title': 'Read 30 min', 'kind': 'personal', 'challenge': 'Read', 'completed_at': '${d(1)}T08:30:00+00:00'},
                      {'title': 'Write notes', 'kind': 'personal', 'challenge': 'Read', 'completed_at': null},
                    ],
                  },
                  {'date': d(2), 'status': 'missed', 'done': 0, 'tasks': []},
                ],
                'totals': {'tasks_done': 2, 'perfect_days': 1, 'missed_days': 1},
              }),
        ],
        child: MaterialApp(
          theme: _theme(false),
          home: const Scaffold(body: SingleChildScrollView(child: ActivityCalendarCard())),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your activity'), findsOneWidget);
      expect(find.text('2 tasks · 1 perfect days'), findsOneWidget);
      expect(find.text('All done'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      expect(find.text('Read 30 min'), findsOneWidget);
      expect(find.text('Write notes'), findsOneWidget);
      expect(find.textContaining('You finished everything'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------ discover
  group('discover groups', () {
    Widget app(_FakeApi api) => ProviderScope(
          overrides: [apiRepositoryProvider.overrideWithValue(api)],
          child: _discoverApp(),
        );

    testWidgets('lists public groups and lets you join one', (tester) async {
      _phone(tester);
      final api = _FakeApi()
        ..publicGroups = [
          PublicGroupModel(
            id: 'pg1',
            name: 'Open Study',
            durationDays: 21,
            taskMode: 'shared',
            groupTasks: const ['Read 20 pages'],
            startsAt: '2026-10-01',
            maxMissedDays: 3,
            leaderName: 'Ana',
            memberCount: 5,
          ),
        ];
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      expect(find.text('Open Study'), findsOneWidget);
      expect(find.textContaining('by Ana'), findsOneWidget);
      expect(find.textContaining('5 members'), findsOneWidget);

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();

      // No invite code field: goes straight to the confirm + tasks step.
      expect(find.text('Open Study'), findsWidgets);
      await tester.tap(find.text('Join Open Study'));
      await tester.pumpAndSettle();

      expect(api.joinedPublicGroupId, 'pg1');
      expect(find.text('GROUP DASHBOARD'), findsOneWidget);
    });

    testWidgets('a joined group shows Open instead of Join', (tester) async {
      _phone(tester);
      final api = _FakeApi()
        ..publicGroups = [
          PublicGroupModel(
            id: 'pg2',
            name: 'Already In',
            durationDays: 21,
            startsAt: '2026-10-01',
            maxMissedDays: 3,
            memberCount: 2,
            isMember: true,
          ),
        ];
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('empty state when there are no public groups', (tester) async {
      _phone(tester);
      await tester.pumpWidget(app(_FakeApi()));
      await tester.pumpAndSettle();
      expect(find.text('No public groups yet'), findsOneWidget);
    });
  });
}

Widget _createApp(bool dark) => _routerApp(const CreateGroupScreen(), dark);
Widget _joinApp() => _routerApp(const JoinGroupScreen(), false);
Widget _discoverApp() => _routerApp(const DiscoverGroupsScreen(), false);

/// The screen is pushed on top of a base route so `pushReplacement` behaves as in the app.
Widget _routerApp(Widget screen, bool dark) {
  AppColors.isDark = dark;
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/start', builder: (_, __) => screen),
      GoRoute(
        path: '/groups/:id/dashboard',
        builder: (_, __) => const Scaffold(body: Text('GROUP DASHBOARD')),
      ),
      GoRoute(
        path: AppRoutes.joinPublicGroup,
        builder: (_, state) => JoinGroupScreen(publicGroup: state.extra as PublicGroupModel),
      ),
    ],
  );
  return MaterialApp.router(
    theme: _theme(dark),
    routerConfig: router,
  );
}

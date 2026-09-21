import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ilm_mode/core/models/models.dart';
import 'package:ilm_mode/core/providers/providers.dart';
import 'package:ilm_mode/core/services/sound_service.dart';
import 'package:ilm_mode/core/theme/app_theme.dart';
import 'package:ilm_mode/core/widgets/how_it_works.dart';
import 'package:ilm_mode/features/challenge/presentation/screens/challenge_detail_screen.dart';

class _FakeApi implements ApiRepository {
  final cancelled = <String>[];
  final left = <String>[];

  @override
  Future<void> cancelChallenge(String challengeId) async => cancelled.add(challengeId);

  @override
  Future<void> leaveGroup(String groupId) async => left.add(groupId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChallengeModel _challenge({bool group = false, String status = 'active'}) {
  final today = DateTime(2026, 9, 20);
  return ChallengeModel(
    id: 'c1',
    name: group ? 'Study Squad Group Challenge' : 'Social Media Detox',
    status: status,
    durationDays: 21,
    currentDay: 3,
    progressPercent: 10,
    remainingDays: 18,
    tasks: [
      TaskModel(id: 't1', title: 'Read 20 pages', type: 'foundation', isCompleted: false),
      TaskModel(id: 't2', title: 'Code 1 hour', type: 'personal', isCompleted: false),
    ],
    days: [
      for (var i = 0; i < 21; i++)
        ChallengeDayModel(
          dayNumber: i + 1,
          calendarDate: today.add(Duration(days: i - 2)).toIso8601String().split('T').first,
          isComplete: false,
          isMissed: false,
          isToday: i == 2,
          isLocked: i > 2,
        ),
    ],
    type: group ? 'group' : 'individual',
    groupId: group ? 'g1' : null,
  );
}

Widget _app(_FakeApi api, ChallengeModel challenge) {
  AppColors.isDark = false;
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
        path: '/home/groups',
        builder: (_, __) => const Scaffold(body: Text('GROUPS TAB')),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => const ChallengeDetailScreen(challengeId: 'c1'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      apiRepositoryProvider.overrideWithValue(api),
      challengeDetailProvider.overrideWith((ref, id) async => challenge),
      profileProvider.overrideWith((ref) => const Stream.empty()),
      groupsProvider.overrideWith((ref) async => <GroupModel>[]),
      activeProgramsProvider.overrideWith((ref) => Stream.value(ActiveProgramsModel())),
      activeChallengeProvider.overrideWith((ref) async => null),
      challengesListProvider.overrideWith((ref) async => <ChallengeSummaryModel>[]),
    ],
    child: MaterialApp.router(
      theme: ThemeData.light().copyWith(
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      routerConfig: router,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SoundService.instance.enabled = false);

  testWidgets('a personal challenge can be cancelled after confirming', (tester) async {
    _phone(tester);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, _challenge()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Leave group'), findsNothing);
    await tester.tap(find.text('Cancel challenge'));
    await tester.pumpAndSettle();

    // The dialog explains what happens before anything is cancelled.
    expect(find.text('Cancel this challenge?'), findsOneWidget);
    expect(find.textContaining('points you already earned'), findsOneWidget);
    expect(api.cancelled, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel challenge'));
    await tester.pumpAndSettle();
    expect(api.cancelled, ['c1']);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Challenge cancelled. Your points are kept.'), findsOneWidget);
  });

  testWidgets('"Keep going" leaves the challenge alone', (tester) async {
    _phone(tester);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, _challenge()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel challenge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(api.cancelled, isEmpty);
    expect(find.text('Social Media Detox'), findsOneWidget);
  });

  testWidgets('a group challenge is left, not cancelled, and uses group wording', (tester) async {
    _phone(tester);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, _challenge(group: true)));
    await tester.pumpAndSettle();

    // No "Foundation" anywhere in a group.
    expect(find.textContaining('oundation'), findsNothing);
    expect(find.text('Group task'), findsOneWidget);
    expect(find.text('My task'), findsOneWidget);
    expect(find.text('Group tasks'), findsOneWidget); // filter chips
    expect(find.text('My tasks'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel challenge'), findsNothing);
    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this group?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Leave'));
    await tester.pumpAndSettle();

    expect(api.left, ['g1']);
    expect(find.text('GROUPS TAB'), findsOneWidget);
  });

  testWidgets('a finished challenge has nothing to cancel', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeApi(), _challenge(status: 'completed')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('"How it works" walks through every idea, then closes', (tester) async {
    _phone(tester);
    AppColors.isDark = false;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showHowItWorks(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('One challenge, a few tasks a day'), findsOneWidget);

    final titles = [
      'Every task earns points',
      'Keep your streak',
      'Missing a day costs you',
      'Go further with a group',
    ];
    for (final title in titles) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('lose $kMissedDayPenalty points'), findsNothing); // slide 4 is past
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Go further with a group'), findsNothing);
  });

  testWidgets('the points explanation shows the real numbers', (tester) async {
    _phone(tester);
    AppColors.isDark = false;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => showPointsInfo(context), child: const Text('info')),
        ),
      ),
    ));
    await tester.tap(find.text('info'));
    await tester.pumpAndSettle();
    expect(find.text('+$kTaskPoints'), findsOneWidget);
    expect(find.text('+$kDayBonusPoints bonus'), findsOneWidget);
    expect(find.text('-$kMissedDayPenalty'), findsOneWidget);
  });
}

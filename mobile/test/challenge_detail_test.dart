import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ilm_mode/core/models/models.dart';
import 'package:ilm_mode/core/providers/providers.dart';
import 'package:ilm_mode/core/services/sound_service.dart';
import 'package:ilm_mode/core/theme/app_theme.dart';
import 'package:ilm_mode/features/challenge/presentation/screens/challenge_detail_screen.dart';

/// Records completions; can be told to fail or to report a perfect day.
class _FakeApi implements ApiRepository {
  final completed = <String>[];
  bool fail = false;
  bool perfectDay = false;

  @override
  Future<Map<String, dynamic>> completeTask(String challengeId, String taskId) async {
    if (fail) throw Exception('offline');
    completed.add(taskId);
    return {
      'celebration': perfectDay,
      'challenge_completed': false,
      'reward_message': '+15 points · perfect day',
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChallengeModel _challenge({int daysUntilStart = 0}) {
  final today = DateTime(2026, 9, 20);
  return ChallengeModel(
    id: 'c1',
    name: 'Social Media Detox',
    status: 'active',
    durationDays: 21,
    currentDay: 3,
    progressPercent: 10,
    remainingDays: 18,
    todayMission: 'Starts Sep 23 (in 3 days)',
    quote: '"Future you is watching." — ILM Mode',
    tasks: [
      TaskModel(id: 'f1', title: 'Wake up on time', type: 'foundation', isCompleted: true),
      TaskModel(id: 'p1', title: 'No social media today', type: 'personal', isCompleted: false),
      TaskModel(id: 'p2', title: 'Log out of the apps', type: 'personal', isCompleted: false),
    ],
    days: [
      for (var i = 0; i < 21; i++)
        ChallengeDayModel(
          dayNumber: i + 1,
          calendarDate: today.add(Duration(days: i - 2)).toIso8601String().split('T').first,
          isComplete: i < 1,
          isMissed: i == 1,
          isToday: i == 2,
          isLocked: i > 2,
        ),
    ],
    daysUntilStart: daysUntilStart,
    pointsToday: 5,
  );
}

ProfileModel _profile() => ProfileModel(
      id: 'u1',
      email: 'a@b.c',
      fullName: 'Ana',
      hp: 40,
      disciplineScore: 0,
      currentStreak: 2,
      longestStreak: 2,
      perfectWeeks: 0,
      challengesCompleted: 0,
      onboardingStep: 6,
      notificationsEnabled: true,
      darkMode: false,
    );

Widget _app(_FakeApi api, {bool dark = false, int daysUntilStart = 0}) {
  AppColors.isDark = dark;
  return ProviderScope(
    overrides: [
      apiRepositoryProvider.overrideWithValue(api),
      challengeDetailProvider.overrideWith((ref, id) async => _challenge(daysUntilStart: daysUntilStart)),
      profileProvider.overrideWith((ref) => Stream.value(_profile())),
    ],
    child: MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: const ChallengeDetailScreen(challengeId: 'c1'),
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

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('shows day strip, summary, sections and filters ($mode)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_FakeApi(), dark: dark));
      await tester.pumpAndSettle();

      expect(find.text('Social Media Detox'), findsOneWidget);
      expect(find.text('Day 3 of 21'), findsOneWidget);
      expect(find.text('40'), findsOneWidget); // total points chip
      expect(find.text('2 tasks left today'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.textContaining('+5 today'), findsOneWidget);
      expect(find.textContaining('2 day streak'), findsOneWidget);
      expect(find.text('To do  ·  2'), findsOneWidget);
      expect(find.text('Done  ·  1'), findsOneWidget);
      expect(find.text('+5'), findsNWidgets(2)); // points hint on pending tasks

      // Foundation / Personal filter.
      await tester.tap(find.text('Personal').first); // the chip, not the task tags
      await tester.pumpAndSettle();
      expect(find.text('Wake up on time'), findsNothing);
      expect(find.text('No social media today'), findsOneWidget);
    });
  }

  testWidgets('ticking a task is instant and pays points via the API', (tester) async {
    _phone(tester);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No social media today'));
    await tester.pump(); // one frame: no waiting on the server
    expect(find.text('1 task left today'), findsOneWidget);
    expect(find.text('Done  ·  2'), findsOneWidget);
    expect(find.textContaining('+10 today'), findsOneWidget); // 5 + optimistic 5

    // The burst effect runs and finishes without errors.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.completed, ['p1']);
  });

  testWidgets('a perfect day shows the celebration', (tester) async {
    _phone(tester);
    final api = _FakeApi()..perfectDay = true;
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out of the apps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Day complete!'), findsOneWidget);
    expect(find.textContaining('perfect day'), findsOneWidget);
  });

  testWidgets('a failed save puts the task back and tells the user', (tester) async {
    _phone(tester);
    final api = _FakeApi()..fail = true;
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No social media today'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't save that"), findsOneWidget);
    expect(find.text('To do  ·  2'), findsOneWidget);
  });

  testWidgets('a scheduled challenge cannot be ticked early', (tester) async {
    _phone(tester);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, daysUntilStart: 3));
    await tester.pumpAndSettle();

    expect(find.text('Starts in 3 days'), findsOneWidget);
    await tester.tap(find.text('No social media today'));
    await tester.pumpAndSettle();
    expect(api.completed, isEmpty);
    expect(find.text('To do  ·  2'), findsOneWidget);
  });
}

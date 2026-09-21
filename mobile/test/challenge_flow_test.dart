import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ilm_mode/core/models/models.dart';
import 'package:ilm_mode/core/providers/providers.dart';
import 'package:ilm_mode/core/router/app_router.dart';
import 'package:ilm_mode/core/theme/app_theme.dart';
import 'package:ilm_mode/features/challenge/presentation/screens/challenge_setup_screen.dart';
import 'package:ilm_mode/features/onboarding/presentation/screens/onboarding_screen.dart';

const _catalog = ChallengeCatalog(
  categories: [
    ChallengeCategory(id: 'detox', label: 'Digital Detox'),
    ChallengeCategory(id: 'mind', label: 'Mindfulness'),
  ],
  templates: [
    ChallengeTemplate(
      id: 'social-detox',
      title: 'Social Media Detox',
      category: 'detox',
      difficulty: 'hard',
      icon: 'phone_off',
      description: 'Take back your time.',
      durationDays: 21,
      tasks: ['No social media today', 'Log out of the apps'],
    ),
    ChallengeTemplate(
      id: 'meditation',
      title: '10-Minute Meditation',
      category: 'mind',
      difficulty: 'easy',
      icon: 'meditate',
      description: 'Train calm and focus.',
      durationDays: 21,
      tasks: ['Meditate for 10 minutes', 'Note how you feel', 'Breathe slowly'],
    ),
  ],
);

ProfileModel _profile({required int step}) => ProfileModel(
      id: 'u1',
      email: 'a@b.c',
      fullName: 'Ana',
      hp: 100,
      disciplineScore: 0,
      currentStreak: 0,
      longestStreak: 0,
      perfectWeeks: 0,
      challengesCompleted: 0,
      onboardingStep: step,
      notificationsEnabled: true,
      darkMode: false,
    );

Widget _app({required int step, bool dark = false}) {
  AppColors.isDark = dark;
  final router = GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.newChallenge,
        builder: (_, state) =>
            ChallengeSetupScreen(template: state.extra as ChallengeTemplate?),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      challengeCatalogProvider.overrideWith((ref) async => _catalog),
      profileProvider.overrideWith((ref) => Stream.value(_profile(step: step))),
    ],
    child: MaterialApp.router(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      routerConfig: router,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The setup form is a lazily built list; scroll a section into view first.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('picker: browse, filter, select, continue ($mode)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(step: 0, dark: dark));
      await tester.pumpAndSettle();

      // First-time header, Skip, both frameworks and "create your own".
      expect(find.text('One last step'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Social Media Detox'), findsOneWidget);
      expect(find.text('10-Minute Meditation'), findsOneWidget);
      expect(find.text('Create your own'), findsOneWidget);

      // Nothing selected yet: the button is disabled.
      expect(find.text('Choose a challenge'), findsOneWidget);

      // Search narrows the grid; the custom card hides while searching.
      await tester.enterText(find.byType(TextField), 'detox');
      await tester.pumpAndSettle();
      expect(find.text('Social Media Detox'), findsOneWidget);
      expect(find.text('10-Minute Meditation'), findsNothing);
      expect(find.text('Create your own'), findsNothing);

      // No match shows the empty state with a way out.
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No challenges found'), findsOneWidget);
      await tester.tap(find.text('Create your own'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);

      // Category chips filter.
      await tester.ensureVisible(find.text('Mindfulness'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mindfulness'));
      await tester.pumpAndSettle();
      expect(find.text('10-Minute Meditation'), findsOneWidget);
      expect(find.text('Social Media Detox'), findsNothing);

      // Pick a template and continue to setup.
      await tester.tap(find.text('10-Minute Meditation'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set up challenge'), findsOneWidget);
      expect(find.text('Meditate for 10 minutes'), findsOneWidget);
    });

    testWidgets('picker: no Skip once onboarding is done ($mode)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(step: 6, dark: dark));
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsNothing);
      expect(find.text('New challenge'), findsOneWidget);
    });

    testWidgets('setup: tasks, duration and start date ($mode)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(step: 0, dark: dark));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Social Media Detox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Name is prefilled, there is no icon picker, and it starts today.
      expect(find.text('Social Media Detox'), findsWidgets);
      expect(find.text('PICK AN ICON'), findsNothing);
      expect(find.text('Start challenge'), findsOneWidget);
      expect(find.textContaining('Starts today'), findsOneWidget);

      // Choosing tomorrow turns it into a scheduled challenge.
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule challenge'), findsOneWidget);
      expect(find.textContaining('Day 21 on'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Start challenge'), findsOneWidget);

      // A shorter duration updates the end date summary.
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Day 7 on'), findsOneWidget);

      // Remove tasks until fewer than 2 remain: submitting is refused.
      await _scrollTo(tester, find.textContaining('Daily tasks'));
      await _scrollTo(tester, find.byTooltip('Remove').first);
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start challenge'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least 2 daily tasks.'), findsOneWidget);

      // Adding your own task works and shows in the list.
      await _scrollTo(tester, find.byTooltip('Add task'));
      await tester.enterText(find.widgetWithText(TextField, 'Add your own task'), 'Walk 20 min');
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      expect(find.text('Walk 20 min'), findsOneWidget);
    });
  }

  testWidgets('setup: create-your-own starts empty and needs 2 tasks', (tester) async {
    _phone(tester);
    AppColors.isDark = false;
    await tester.pumpWidget(_app(step: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your own'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Your own challenge'), findsOneWidget);
    await _scrollTo(tester, find.text('Add at least 2 things you will do every day.'));
    expect(find.text('Add at least 2 things you will do every day.'), findsOneWidget);
    await tester.tap(find.text('Start challenge'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least 2 daily tasks.'), findsOneWidget);
  });
}

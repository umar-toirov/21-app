import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ilm_mode/core/router/app_router.dart';
import 'package:ilm_mode/core/theme/app_theme.dart';
import 'package:ilm_mode/features/auth/presentation/screens/landing_screen.dart';

Widget _app(bool dark) {
  AppColors.isDark = dark;
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, __) => const Scaffold(body: Text('SIGN UP PAGE'))),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const Scaffold(body: Text('LOG IN PAGE'))),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      routerConfig: router,
    ),
  );
}

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  // The hero ring animates forever, so tests advance time instead of settling.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // lets delayed entrance animations start
  }

  for (final (name, w, h) in [('normal phone', 390.0, 844.0), ('small phone', 360.0, 640.0)]) {
    for (final dark in [false, true]) {
      testWidgets('sign up and log in are always visible: $name (${dark ? 'dark' : 'light'})',
          (tester) async {
        _size(tester, w, h);
        await tester.pumpWidget(_app(dark));
        await settle(tester);

        // Pinned at the bottom: visible without scrolling, fully on screen.
        for (final label in ['Sign up free', 'Log in']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.bottom, lessThanOrEqualTo(h), reason: '$label is off screen');
          expect(rect.top, greaterThan(0));
        }
        expect(find.text('Habit Zone'), findsOneWidget);
        expect(find.text('Build discipline,\none day at a time.'), findsOneWidget);
      });
    }
  }

  testWidgets('the buttons go to sign up and log in', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_app(false));
    await settle(tester);

    await tester.tap(find.text('Sign up free'));
    await settle(tester);
    expect(find.text('SIGN UP PAGE'), findsOneWidget);

    // back to the landing screen, then log in
    await tester.pumpWidget(_app(false));
    await settle(tester);
    await tester.tap(find.text('Log in'));
    await settle(tester);
    expect(find.text('LOG IN PAGE'), findsOneWidget);
  });

  testWidgets('the page scrolls to the previews and the credit without hiding the buttons',
      (tester) async {
    _size(tester, 360, 640);
    await tester.pumpWidget(_app(false));
    await settle(tester);

    await tester.scrollUntilVisible(
      find.textContaining('Made by'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Sign up free'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.textContaining('Discipline is choosing'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
  });
}

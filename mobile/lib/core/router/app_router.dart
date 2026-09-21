import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cache/app_cache.dart';
import '../../features/auth/presentation/screens/auth_callback_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/landing_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/challenge/presentation/screens/challenge_dashboard_screen.dart';
import '../../features/challenge/presentation/screens/challenge_detail_screen.dart';
import '../../features/challenge/presentation/screens/challenge_history_screen.dart';
import '../../features/challenge/presentation/screens/challenge_setup_screen.dart';
import '../../features/challenge/presentation/screens/challenge_complete_screen.dart';
import '../../features/challenge/presentation/screens/recovery_screen.dart';
import '../../features/group_challenge/presentation/screens/create_group_screen.dart';
import '../../features/group_challenge/presentation/screens/group_home_screen.dart';
import '../../features/group_challenge/presentation/screens/group_list_screen.dart';
import '../../features/group_challenge/presentation/screens/group_member_profile_screen.dart';
import '../../features/group_challenge/presentation/screens/group_settings_screen.dart';
import '../../features/group_challenge/presentation/screens/join_group_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/badges_screen.dart';
import '../../features/profile/presentation/screens/certificates_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../config/env.dart';
import '../models/models.dart';

class AppRoutes {
  static const landing = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const authCallback = AppConfig.authCallbackPath;
  static const onboarding = '/onboarding';
  static const newChallenge = '/challenge/new';
  static const home = '/home';
  static const recovery = '/recovery';
  static const challengeComplete = '/challenge-complete';
  static const challengeHistory = '/challenge-history';
  static const challengeDetail = '/home/challenge/:id';
  static const createGroup = '/groups/create';
  static const joinGroup = '/groups/join';
  static const groupDashboard = '/groups/:id/dashboard';
  static const groupMember = '/groups/:id/members/:memberId';
  static const groupSettings = '/groups/:id/settings';
  static const settings = '/settings';
  static const certificates = '/certificates';
  static const badges = '/badges';
}

/// Notifies go_router when Supabase auth session changes (e.g. Google redirect).
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter createRouter({Listenable? refreshListenable}) {
  return GoRouter(
    // Returning users skip the sign-in check that waits on the API.
    initialLocation: Supabase.instance.client.auth.currentSession != null &&
            AppCache.onboarded
        ? AppRoutes.home
        : AppRoutes.landing,
    refreshListenable: refreshListenable,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Something went wrong with navigation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(AppRoutes.landing),
                child: const Text('Back to start'),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      // Prefer full URI path — safer after OAuth returns with ?code=
      final path = state.uri.path.isEmpty ? '/' : state.uri.path;
      final hasOAuthCode = state.uri.queryParameters.containsKey('code');

      final isAuthRoute = path == AppRoutes.landing ||
          path == AppRoutes.login ||
          path == AppRoutes.signup ||
          path == AppRoutes.forgotPassword;
      final isCallback = path == AppRoutes.authCallback;

      // OAuth landed with a code on the wrong path → send to callback.
      if (hasOAuthCode && !isCallback) {
        final q = state.uri.query;
        return q.isEmpty
            ? AppRoutes.authCallback
            : '${AppRoutes.authCallback}?$q';
      }

      if (isCallback) return null;

      if (!isAuth && !isAuthRoute) {
        return AppRoutes.landing;
      }

      // Signed in on landing/login/signup → finish via callback (profile + routing).
      if (isAuth && isAuthRoute) {
        return AppCache.onboarded ? AppRoutes.home : AppRoutes.authCallback;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.landing, builder: (_, __) => const LandingScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (_, __) => const AuthCallbackScreen(),
      ),
      GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: AppRoutes.newChallenge,
        builder: (_, state) =>
            ChallengeSetupScreen(template: state.extra as ChallengeTemplate?),
      ),
      GoRoute(path: AppRoutes.recovery, builder: (_, __) => const RecoveryScreen()),
      GoRoute(
        path: AppRoutes.challengeComplete,
        builder: (_, __) => const ChallengeCompleteScreen(),
      ),
      GoRoute(
        path: AppRoutes.challengeHistory,
        builder: (_, __) => const ChallengeHistoryScreen(),
      ),
      GoRoute(path: AppRoutes.createGroup, builder: (_, __) => const CreateGroupScreen()),
      GoRoute(path: AppRoutes.joinGroup, builder: (_, __) => const JoinGroupScreen()),
      GoRoute(
        path: AppRoutes.groupDashboard,
        builder: (_, state) => GroupHomeScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.groupMember,
        builder: (_, state) => GroupMemberProfileScreen(
          groupId: state.pathParameters['id']!,
          memberId: state.pathParameters['memberId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.groupSettings,
        builder: (_, state) => GroupSettingsScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: AppRoutes.certificates, builder: (_, __) => const CertificatesScreen()),
      GoRoute(path: AppRoutes.badges, builder: (_, __) => const BadgesScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const ChallengeDashboardScreen(),
            routes: [
              GoRoute(
                path: 'challenge/:id',
                builder: (_, state) => ChallengeDetailScreen(
                  challengeId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'groups',
                builder: (_, __) => const GroupListScreen(),
              ),
              GoRoute(
                path: 'statistics',
                builder: (_, __) => const StatisticsScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

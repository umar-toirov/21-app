import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Handles post-OAuth redirect: wait for session, load profile, route to onboarding or home.
class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishAuth());
  }

  Future<void> _recoverSessionFromUrl() async {
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } catch (_) {
        // Supabase may already have exchanged the code during initialize.
      }
    }
  }

  Future<void> _finishAuth() async {
    try {
      await _recoverSessionFromUrl();

      // Give Supabase a moment to finish PKCE / parse URL tokens on web.
      for (var i = 0; i < 30; i++) {
        if (Supabase.instance.client.auth.currentSession != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (!mounted) return;
        final hint = kIsWeb
            ? 'Google sign-in did not complete.\n\n'
                'Add this Redirect URL in Supabase → Authentication → URL Configuration:\n'
                '${Uri.base.origin}${AppConfig.authCallbackPath}'
            : 'Sign-in did not complete. Please try again.';
        setState(() => _error = hint);
        return;
      }

      Object? lastError;
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          if (attempt > 0) {
            await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          }
          final profile = await ref.read(apiRepositoryProvider).getProfile();
          if (!mounted) return;
          if (profile.needsOnboarding) {
            context.go(AppRoutes.onboarding);
          } else {
            context.go(AppRoutes.home);
          }
          return;
        } catch (e) {
          lastError = e;
        }
      }

      if (!mounted) return;
      String hint;
      if (lastError is DioException) {
        final code = lastError.response?.statusCode;
        if (code == 500) {
          hint = 'Server error while loading your profile. Please retry in a moment.';
        } else if (code == 401) {
          hint = 'Session expired. Please log in again.';
        } else {
          hint = 'Cannot reach API at ${AppConfig.apiBaseUrl}. Is the backend running?';
        }
      } else {
        hint = 'Could not finish sign-in: $lastError';
      }
      setState(() => _error = hint);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not finish sign-in: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.orange),
                    SizedBox(height: 20),
                    Text(
                      'Signing you in…',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _finishAuth();
                      },
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F2),
              Color(0xFFFFFFFF),
              Color(0xFFF3F7FF),
            ],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/brand/logo_auth.png',
                    height: 36,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ).animate().fadeIn(duration: 450.ms),
                const Spacer(flex: 2),
                Text(
                  '21',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w900,
                        fontSize: 108,
                        height: 0.85,
                        letterSpacing: -4,
                      ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.72, 0.72),
                      curve: Curves.easeOutBack,
                      duration: 700.ms,
                    ),
                const SizedBox(height: 10),
                const Text(
                  '21-Day Challenge\nfor Real Discipline',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.12, end: 0),
                const SizedBox(height: 8),
                const Text(
                  'by ILM HUB',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    fontSize: 13,
                  ),
                ).animate().fadeIn(delay: 120.ms),
                const SizedBox(height: 28),
                SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/brand/mountain.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                      .animate()
                      .fadeIn(delay: 160.ms)
                      .slideY(begin: 0.14, end: 0, curve: Curves.easeOutCubic)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: 0, end: -6, duration: 2000.ms),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  label: 'Start Your Free Challenge',
                  onPressed: () => context.push(AppRoutes.signup),
                ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.18, end: 0),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.push(AppRoutes.login),
                  child: const Text(
                    'I already have an account',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

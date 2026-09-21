import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
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
        decoration: BoxDecoration(
          color: AppColors.surface,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/brand/app_icon.png',
                    width: 96,
                    height: 96,
                    filterQuality: FilterQuality.high,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      curve: Curves.easeOutBack,
                      duration: 600.ms,
                    ),
                const SizedBox(height: 14),
                Text(
                  AppConfig.appName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    letterSpacing: -0.8,
                  ),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: 12),
                Text(
                  '21-Day Challenge\nfor Real Discipline',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.12, end: 0),
                const SizedBox(height: 14),
                Text(
                  'Build daily habits, protect your streak, and finish with proof.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ).animate().fadeIn(delay: 140.ms),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'What you get',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),
                const _LandingBenefit(
                  icon: Icons.checklist_rounded,
                  color: AppColors.orange,
                  title: 'Daily mission',
                  body: 'Foundation + personal tasks every day — clear, finishable.',
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.12, end: 0),
                const SizedBox(height: 10),
                const _LandingBenefit(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.teal,
                  title: 'Streak & Points',
                  body: 'Stay consistent. Miss days and your Points take the hit.',
                ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.12, end: 0),
                const SizedBox(height: 10),
                const _LandingBenefit(
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.goldDepth,
                  title: 'Day 21 certificate',
                  body: 'Finish the program and earn a shareable completion certificate.',
                ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.12, end: 0),
                const SizedBox(height: 28),
                SoftCard(
                  color: AppColors.navy.withValues(alpha: 0.04),
                  borderColor: AppColors.navy.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      Icon(Icons.groups_rounded, color: AppColors.navy),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Or join a group: shared tasks, a ranking and a chat to keep each other going.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 320.ms),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Start Your Free Challenge',
                  onPressed: () => context.push(AppRoutes.signup),
                )
                    .animate()
                    .fadeIn(delay: 360.ms)
                    .slideY(begin: 0.18, end: 0)
                    .then(delay: 200.ms)
                    .shimmer(duration: 1200.ms, color: Colors.white24),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.push(AppRoutes.login),
                  child: Text(
                    'I already have an account',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const MadeByIlmHub(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingBenefit extends StatelessWidget {
  const _LandingBenefit({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

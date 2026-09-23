import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

/// First screen for signed-out users. Sign up / Log in are pinned at the bottom
/// so they are always visible, whatever the screen height.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _CtaBar(
        onSignUp: () => context.push(AppRoutes.signup),
        onLogIn: () => context.push(AppRoutes.login),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
              children: [
                const _Header(),
                const SizedBox(height: 36),
                const _Feature(
                  icon: Icons.checklist_rounded,
                  color: AppColors.teal,
                  title: 'Daily tasks',
                  text: 'A short list each day. Tick it off and earn points.',
                ),
                const _Feature(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.orange,
                  title: 'A streak to protect',
                  text: 'Show up every day for 21 days.',
                ),
                const _Feature(
                  icon: Icons.groups_rounded,
                  color: Color(0xFF3B82F6),
                  title: 'Groups and ranking',
                  text: 'Join friends, chat and climb the leaderboard.',
                ),
                const SizedBox(height: 28),
                const Center(child: MadeByIlmHub()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bottom bar
class _CtaBar extends StatelessWidget {
  const _CtaBar({required this.onSignUp, required this.onLogIn});

  final VoidCallback onSignUp;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(label: 'Sign up free', onPressed: onSignUp),
                  const SizedBox(height: 10),
                  PrimaryButton(label: 'Log in', outlined: true, onPressed: onLogIn),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ content
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/brand/app_icon.png', width: 84, height: 84),
          ),
        ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 18),
        Text(
          AppConfig.appName,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Build discipline,\none day at a time.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: AppColors.textPrimary,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 250.ms).fadeIn(duration: 450.ms);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/duo_components.dart';
import '../../../../core/widgets/shared_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: profileAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppColors.orange)),
            error: (e, _) => Center(child: Text('$e')),
            data: (profile) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded),
                        onPressed: () => context.push(AppRoutes.settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SoftCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.teal, AppColors.blue],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.teal.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  'LV ${(profile.hp / 50).floor().clamp(1, 99)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().scale(begin: const Offset(0.85, 0.85)),
                        const SizedBox(height: 16),
                        Text(
                          profile.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          profile.email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _GemStat(
                              icon: Icons.bolt_rounded,
                              label: 'Points',
                              value: '${profile.hp}',
                              color: AppColors.orange,
                            ),
                            _GemStat(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Streak',
                              value: '${profile.currentStreak}',
                              color: AppColors.orangeDepth,
                            ),
                            _GemStat(
                              icon: Icons.emoji_events_rounded,
                              label: 'Done',
                              value: '${profile.challengesCompleted}',
                              color: AppColors.teal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MenuTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Certificates',
                    subtitle: 'Your proof of discipline',
                    color: AppColors.gold,
                    onTap: () => context.push(AppRoutes.certificates),
                  ),
                  _MenuTile(
                    icon: Icons.history_edu_rounded,
                    title: 'Past challenges',
                    subtitle: 'Review what you completed',
                    color: AppColors.navy,
                    onTap: () => context.push(AppRoutes.challengeHistory),
                  ),
                  _MenuTile(
                    icon: Icons.military_tech_rounded,
                    title: 'Badges',
                    subtitle: 'Collection & locked rewards',
                    color: AppColors.orange,
                    onTap: () => context.push(AppRoutes.badges),
                  ),
                  _MenuTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'Payment History',
                    subtitle: 'Challenges & receipts',
                    color: AppColors.teal,
                    onTap: () => context.push(AppRoutes.payments),
                  ),
                  const SizedBox(height: 8),
                  badgesAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (badges) {
                      final earned =
                          badges.where((b) => b.earned).take(4).toList();
                      if (earned.isEmpty) return const SizedBox();
                      return SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionTitle('Recent Badges'),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: earned
                                  .map(
                                    (b) => Column(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.gold
                                                .withValues(alpha: 0.2),
                                            border: Border.all(
                                              color: AppColors.goldDepth,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.military_tech_rounded,
                                            color: AppColors.goldDepth,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: 64,
                                          child: Text(
                                            b.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GemStat extends StatelessWidget {
  const _GemStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          onTap: onTap,
        ),
      ),
    );
  }
}

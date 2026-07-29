import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

class ChallengeDashboardScreen extends ConsumerWidget {
  const ChallengeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(activeChallengeProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: challengeAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.orange)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load your challenge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString().contains('500')
                      ? 'Server error — tap retry. If it keeps failing, the backend may need a restart.'
                      : e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Retry',
                  onPressed: () {
                    ref.invalidate(activeChallengeProvider);
                    ref.invalidate(profileProvider);
                  },
                ),
              ],
            ),
          ),
        ),
        data: (challenge) {
          if (challenge == null) {
            return SafeArea(
              child: EmptyState(
                icon: Icons.flag_outlined,
                title: 'Start your 21-day path',
                subtitle: 'Discipline today, success tomorrow.',
                action: PrimaryButton(
                  label: 'Start Challenge',
                  onPressed: () => context.go(AppRoutes.onboarding),
                ),
              ),
            );
          }

          if (challenge.isRecovery) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go(AppRoutes.recovery);
            });
          }

          return profileAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.orange)),
            error: (e, _) => Center(child: Text('$e')),
            data: (profile) => _HomeContent(
              challenge: challenge,
              profile: profile,
              onRefresh: () {
                ref.invalidate(activeChallengeProvider);
                ref.invalidate(profileProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.challenge,
    required this.profile,
    required this.onRefresh,
  });

  final ChallengeModel challenge;
  final ProfileModel profile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = challenge.tasks.where((task) => task.isCompleted).length;
    final total = challenge.tasks.length;
    final progress = (challenge.progressPercent / 100).clamp(0.0, 1.0);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/brand/logo_auth.png',
                  height: 34,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                GestureDetector(
                  onTap: () => context.go('${AppRoutes.home}/profile'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                    child: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.12, end: 0),
            const SizedBox(height: 18),
            HomeGreetingHero(name: profile.fullName),
            const SizedBox(height: 22),
            Text(
              'Your challenge',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            IlmChallengeCard(
              title: challenge.name,
              subtitle: '21-day discipline challenge',
              dayLabel:
                  'Day ${challenge.currentDay} / ${challenge.durationDays}',
              progress: progress,
              message: challenge.dayComplete
                  ? 'Day complete — next day unlocks after midnight'
                  : (challenge.todayMission ??
                      "Keep going! You're doing great."),
              onTap: () =>
                  context.push('/home/challenge/${challenge.id}'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  "Today's tasks",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      context.push('/home/challenge/${challenge.id}'),
                  child: const Text('View day'),
                ),
              ],
            ),
            ...challenge.tasks.take(3).map(
                  (task) => TaskTile(
                    title: task.title,
                    isCompleted: task.isCompleted,
                    isFoundation: task.type == 'foundation',
                    onChanged: (_) =>
                        context.push('/home/challenge/${challenge.id}'),
                  ),
                ),
            const SizedBox(height: 8),
            Row(
              children: [
                TasksRingCard(done: done, total: total),
                const SizedBox(width: 12),
                StreakCard(streak: profile.currentStreak),
              ],
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 18),
            SoftCard(
              child: Column(
                children: [
                  AnimatedRing(
                    progress: progress,
                    size: 132,
                    stroke: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Day ${challenge.currentDay}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          '/ ${challenge.durationDays}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Challenge progress',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                StatTile3D(
                  icon: Icons.favorite_rounded,
                  label: 'HP',
                  value: '${profile.hp}',
                  color: AppColors.hp,
                  delay: 0.ms,
                ),
                StatTile3D(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak',
                  value: '${profile.currentStreak}',
                  color: AppColors.orange,
                  delay: 60.ms,
                ),
                StatTile3D(
                  icon: Icons.bolt_rounded,
                  label: 'Score',
                  value: '${profile.disciplineScore}',
                  color: AppColors.goldDepth,
                  delay: 120.ms,
                ),
                StatTile3D(
                  icon: Icons.emoji_events_rounded,
                  label: 'Rank',
                  value: challenge.leaderboardPosition != null
                      ? '#${challenge.leaderboardPosition}'
                      : '—',
                  color: AppColors.teal,
                  delay: 180.ms,
                ),
              ],
            ),
            if (challenge.quote != null) ...[
              const SizedBox(height: 18),
              SoftCard(
                color: const Color(0xFFFFF7F0),
                borderColor: AppColors.orange.withValues(alpha: 0.2),
                child: Text(
                  challenge.quote!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

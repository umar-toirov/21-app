import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class ChallengeHistoryScreen extends ConsumerWidget {
  const ChallengeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(challengesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Past challenges')),
      body: listAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.orange)),
        error: (e, _) => Center(child: Text('$e')),
        data: (challenges) {
          final past = challenges
              .where((c) => c.status == 'completed' || c.status == 'failed')
              .toList();
          if (past.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No past challenges yet',
              subtitle: 'Finish your first 21-day path to see achievements here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: past.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final c = past[i];
              final done = c.status == 'completed';
              return SoftCard(
                child: InkWell(
                  onTap: () => context.push('/home/challenge/${c.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (done ? AppColors.gold : AppColors.danger)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          done ? Icons.emoji_events_rounded : Icons.flag_rounded,
                          color: done ? AppColors.goldDepth : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              done
                                  ? 'Completed · Day ${c.currentDay}/${c.durationDays}'
                                  : 'Failed · Day ${c.currentDay}/${c.durationDays}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: done ? AppColors.success : AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (60 * i).ms);
            },
          );
        },
      ),
    );
  }
}

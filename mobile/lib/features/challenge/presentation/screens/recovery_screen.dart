import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(activeChallengeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Mode')),
      body: challengeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (challenge) {
          if (challenge == null || !challenge.isRecovery) {
            return const Center(child: Text('Not in recovery mode'));
          }

          final hoursLeft = challenge.recoveryHoursLeft ?? 24;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.healing, size: 64, color: AppColors.accent),
                const SizedBox(height: 24),
                Text(
                  'Discipline isn\'t perfection.\nGet back in.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${hoursLeft.toStringAsFixed(0)} hours remaining',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete your foundation tasks to recover your challenge.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ...challenge.tasks.where((t) => t.type == 'foundation').map(
                      (t) => TaskTile(
                        title: t.title,
                        isCompleted: t.isCompleted,
                        isFoundation: true,
                        onChanged: t.isCompleted
                            ? null
                            : (_) async {
                                await ref.read(apiRepositoryProvider).completeTask(challenge.id, t.id);
                                ref.invalidate(activeChallengeProvider);
                              },
                      ),
                    ),
                const Spacer(),
                PrimaryButton(
                  label: 'Return to Dashboard',
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

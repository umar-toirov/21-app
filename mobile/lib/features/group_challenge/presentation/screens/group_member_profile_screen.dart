import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../widgets/group_widgets.dart';

final groupMemberProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String groupId, String memberId})>((ref, params) {
  return ref.watch(apiRepositoryProvider).getGroupMemberProfile(params.groupId, params.memberId);
});

class GroupMemberProfileScreen extends ConsumerWidget {
  const GroupMemberProfileScreen({
    super.key,
    required this.groupId,
    required this.memberId,
  });

  final String groupId;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      groupMemberProfileProvider((groupId: groupId, memberId: memberId)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Member Profile')),
      body: profileAsync.when(
        loading: () => const GroupLoadingState(),
        error: (e, _) => GroupErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(
            groupMemberProfileProvider((groupId: groupId, memberId: memberId)),
          ),
        ),
        data: (data) {
          final name = data['full_name'] as String? ?? 'Member';
          final isYou = data['is_you'] == true;
          final challenge = data['challenge'] as Map<String, dynamic>? ?? {};
          final foundation = data['foundation_tasks'] as List<dynamic>? ?? [];
          final personal = data['personal_tasks'] as List<dynamic>? ?? [];
          final heatmap = data['heatmap'] as List<dynamic>? ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$name${isYou ? ' (you)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat('Points', '${data['group_points'] ?? 0}', AppColors.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat('Streak', '${data['current_streak'] ?? 0}', AppColors.teal),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      'Done',
                      '${(challenge['completion_percent'] as num?)?.toStringAsFixed(0) ?? 0}%',
                      AppColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Challenge Progress', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Day ${challenge['current_day'] ?? 1} · '
                      '${(challenge['completion_percent'] as num?)?.toStringAsFixed(0) ?? 0}% complete',
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    AnimatedFillBar(
                      value: (((challenge['completion_percent'] as num?) ?? 0) / 100).clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AttendanceHeatmap(days: heatmap),
              const SizedBox(height: 24),
              if (foundation.isNotEmpty) ...[
                const Text('Foundation Tasks', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                ...foundation.map((t) {
                  final map = t as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const GlossyIcon(icon: Icons.star_rounded, size: 32, color: AppColors.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              map['title'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (personal.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Personal Tasks', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                ...personal.map((t) {
                  final map = t as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const GlossyIcon(icon: Icons.check_circle_outline_rounded, size: 32, color: AppColors.teal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              map['title'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              SoftCard(
                child: Column(
                  children: [
                    _AchievementRow('Longest streak', '${data['longest_streak'] ?? 0} days'),
                    const Divider(height: 20),
                    _AchievementRow('Challenges completed', '${data['challenges_completed'] ?? 0}'),
                    const Divider(height: 20),
                    _AchievementRow('Perfect weeks', '${data['perfect_weeks'] ?? 0}'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy)),
      ],
    );
  }
}

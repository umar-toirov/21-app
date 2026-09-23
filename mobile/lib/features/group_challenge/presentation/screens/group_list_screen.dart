import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cache/app_cache.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Text('Groups', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Discover public groups',
                    icon: const Icon(Icons.public_rounded, color: AppColors.teal, size: 26),
                    onPressed: () => context.push(AppRoutes.discoverGroups),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 30),
                    onPressed: () => context.push(AppRoutes.createGroup),
                  ),
                ],
              ),
            ),
            const _GroupsIntroCard(),
            Expanded(
              child: groupsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.orange)),
                error: (e, _) => Center(child: Text('$e')),
                data: (groups) {
                  if (groups.isEmpty) {
                    return EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No group challenges',
                      subtitle: 'Join a group or create one as a leader',
                      action: Column(
                        children: [
                          PrimaryButton(
                            label: 'Discover Public Groups',
                            onPressed: () => context.push(AppRoutes.discoverGroups),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Join with Invite Code',
                            outlined: true,
                            onPressed: () => context.push(AppRoutes.joinGroup),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Create Group',
                            outlined: true,
                            onPressed: () => context.push(AppRoutes.createGroup),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: groups.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PrimaryButton(
                            label: 'Join with invite code',
                            outlined: true,
                            icon: Icons.group_add_rounded,
                            onPressed: () => context.push(AppRoutes.joinGroup),
                          ),
                        );
                      }
                      final g = groups[i - 1];
                      final pct = g.todayCompletionPercent;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SoftCard(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => context.push('/groups/${g.id}/dashboard'),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const GlossyIcon(
                                    icon: Icons.groups_rounded,
                                    size: 48,
                                    color: AppColors.orange,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${g.memberCount} members · Day ${g.currentDay}/${g.durationDays}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: (pct / 100).clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: AppColors.border,
                                            valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${pct.toStringAsFixed(0)}% completed today',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: (i * 40).ms);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-time explanation of how groups work. Hides itself once dismissed.
class _GroupsIntroCard extends StatefulWidget {
  const _GroupsIntroCard();

  @override
  State<_GroupsIntroCard> createState() => _GroupsIntroCardState();
}

class _GroupsIntroCardState extends State<_GroupsIntroCard> {
  static const _flag = 'groups_intro_seen';
  late bool _visible = !AppCache.flag(_flag);

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How groups work',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover a public group, join with an invite code, or create your own. '
                  'The admin sets the tasks '
                  '(or lets members choose theirs). Everyone earns points, the group has '
                  'a ranking, and you can chat to keep each other going.',
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Got it',
            onPressed: () {
              AppCache.setFlag(_flag);
              setState(() => _visible = false);
            },
            icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

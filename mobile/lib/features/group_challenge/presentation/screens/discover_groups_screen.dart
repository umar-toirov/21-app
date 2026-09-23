import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

/// Public groups anyone can join without an invite code.
class DiscoverGroupsScreen extends ConsumerWidget {
  const DiscoverGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(publicGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Discover groups')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () async => ref.invalidate(publicGroupsProvider),
          child: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.orange)),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text('$e')),
              ],
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 40),
                    EmptyState(
                      icon: Icons.public_rounded,
                      title: 'No public groups yet',
                      subtitle: 'When someone creates a public group, it will show up here '
                          'for anyone to join.',
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final g = groups[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const GlossyIcon(
                            icon: Icons.public_rounded,
                            size: 46,
                            color: AppColors.teal,
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
                                  [
                                    if (g.leaderName != null) 'by ${g.leaderName}',
                                    '${g.memberCount} members',
                                    '${g.durationDays} days',
                                    g.taskMode == 'freedom' ? 'choose your own tasks' : 'shared tasks',
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (g.isMember)
                            OutlinedButton(
                              onPressed: () => context.push('/groups/${g.id}/dashboard'),
                              child: const Text('Open'),
                            )
                          else
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                              onPressed: () => context.push(
                                AppRoutes.joinPublicGroup,
                                extra: g,
                              ),
                              child: const Text('Join'),
                            ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (i * 40).ms);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

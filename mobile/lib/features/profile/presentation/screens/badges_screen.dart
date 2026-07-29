import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: badgesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.orange)),
        error: (e, _) => Center(child: Text('$e')),
        data: (badges) {
          final earned = badges.where((b) => b.earned).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SoftCard(
                  child: Row(
                    children: [
                      const Icon(Icons.military_tech_rounded,
                          color: AppColors.goldDepth, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$earned of ${badges.length} badges earned',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (_, i) {
                    final b = badges[i];
                    final colors = [
                      AppColors.orange,
                      AppColors.teal,
                      AppColors.blue,
                      AppColors.goldDepth,
                    ];
                    final color = colors[i % colors.length];
                    return SoftCard(
                      color: b.earned
                          ? AppColors.surface
                          : AppColors.background,
                      borderColor: b.earned
                          ? color.withValues(alpha: 0.35)
                          : AppColors.border,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (b.earned ? color : AppColors.muted)
                                  .withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              b.earned
                                  ? Icons.military_tech_rounded
                                  : Icons.lock_rounded,
                              size: 32,
                              color: b.earned ? color : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            b.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: b.earned
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.description,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (40 * i).ms).fadeIn().scale(
                          begin: const Offset(0.94, 0.94),
                        );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

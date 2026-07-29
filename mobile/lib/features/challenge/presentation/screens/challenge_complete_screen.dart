import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class ChallengeCompleteScreen extends ConsumerWidget {
  const ChallengeCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificatesProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4E0), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const BrandMascot(size: 130, variant: BrandLogoVariant.gold)
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      curve: Curves.elasticOut,
                      duration: 900.ms,
                    )
                    .rotate(begin: -0.15, end: 0),
                const SizedBox(height: 20),
                Text(
                  'Challenge Complete!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You built real discipline with ILM HUB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                certsAsync.when(
                  loading: () => const CircularProgressIndicator(color: AppColors.teal),
                  error: (_, __) => const SizedBox(),
                  data: (certs) {
                    if (certs.isEmpty) return const SizedBox();
                    final latest = certs.first;
                    return SoftCard(
                      borderColor: AppColors.gold,
                      child: Column(
                        children: [
                          Text(
                            latest.title,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Certificate #${latest.certificateNo}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${latest.durationDays}-day program',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'View Certificates',
                  color: AppColors.gold,
                  depthColor: AppColors.goldDepth,
                  textColor: AppColors.navy,
                  onPressed: () => context.push(AppRoutes.certificates),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'View Past Challenges',
                  outlined: true,
                  onPressed: () => context.push(AppRoutes.challengeHistory),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Back to Home',
                  outlined: true,
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

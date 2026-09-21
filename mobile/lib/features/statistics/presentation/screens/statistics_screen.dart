import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../widgets/leaderboard_tab.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text('Statistics',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  const GlossyIcon(
                    icon: Icons.insights_rounded,
                    size: 36,
                    color: AppColors.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Personal'),
                    Tab(text: 'Leaderboard'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _PersonalStatsTab(),
                  LeaderboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalStatsTab extends ConsumerWidget {
  const _PersonalStatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(personalStatsProvider);
    final profileAsync = ref.watch(profileProvider);

    return statsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      error: (e, _) => Center(child: Text('$e')),
      data: (stats) {
        final breakdown =
            stats['discipline_breakdown'] as Map<String, dynamic>? ?? {};
        final rate = ((stats['completion_rate'] as num?) ?? 0).toDouble();
        final days = stats['daily_consistency'] as List<dynamic>? ?? [];
        final chartValues = List<double>.generate(7, (i) {
          if (i < days.length && days[i]['complete'] == true) return 1;
          if (i < days.length && days[i]['value'] != null) {
            return (days[i]['value'] as num).toDouble();
          }
          return (i + 1) * 0.12 + (rate / 200);
        });

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            profileAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (p) => Row(
                children: [
                  _OverviewCard(
                    title: 'Completion',
                    value: '${rate.toStringAsFixed(0)}%',
                    color: AppColors.teal,
                    icon: Icons.check_circle_rounded,
                  ),
                  const SizedBox(width: 10),
                  _OverviewCard(
                    title: 'Streak',
                    value: '${p.currentStreak}',
                    color: AppColors.orange,
                    icon: Icons.local_fire_department_rounded,
                  ),
                  const SizedBox(width: 10),
                  _OverviewCard(
                    title: 'Score',
                    value: '${p.disciplineScore}',
                    color: AppColors.goldDepth,
                    icon: Icons.bolt_rounded,
                  ),
                ],
              ).animate().fadeIn().slideY(begin: 0.08, end: 0),
            ),
            const SizedBox(height: 18),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Progress Overview'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: AnimatedLineChart(values: chartValues),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 18),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Completion Rate'),
                  const SizedBox(height: 12),
                  AnimatedFillBar(
                    value: rate / 100,
                    color: AppColors.teal,
                    background: AppColors.borderStrong,
                    height: 14,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${rate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 18),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Discipline Breakdown'),
                    const SizedBox(height: 8),
                    ...breakdown.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key
                                  .replaceAll('_', ' ')
                                  .replaceAll('base', 'Starting score')
                                  .replaceAll('completed days', 'Daily completions')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              e.key == 'base' ? '${e.value}' : '+${e.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Weekly Consistency'),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final complete =
                          i < days.length && days[i]['complete'] == true;
                      return Column(
                        children: [
                          AnimatedContainer(
                            duration: 300.ms,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: complete ? AppColors.success : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: complete
                                    ? const Color(0xFF16A34A)
                                    : AppColors.borderStrong,
                                width: 3,
                              ),
                            ),
                            child: complete
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          )
                              .animate(delay: (60 * i).ms)
                              .scale(begin: const Offset(0.5, 0.5)),
                          const SizedBox(height: 6),
                          Text(
                            (i < days.length && days[i]['label'] != null)
                                ? '${days[i]['label']}'
                                : 'D${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            GlossyIcon(icon: icon, color: color, size: 34),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
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

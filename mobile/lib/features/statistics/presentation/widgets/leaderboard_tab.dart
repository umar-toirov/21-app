import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/how_it_works.dart';
import '../../../../core/widgets/ranking_widgets.dart';
import '../../../../core/widgets/slow_loading_hint.dart';

/// Leaderboards: people ranked by points/streak/completed, or groups ranked by
/// the points of their participants.
class LeaderboardTab extends ConsumerStatefulWidget {
  const LeaderboardTab({super.key, this.initialGroups = false});

  final bool initialGroups;

  @override
  ConsumerState<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<LeaderboardTab> {
  late bool _groups = widget.initialGroups;
  String _metric = 'hp';
  String _groupMetric = 'total';

  static const _peopleMetrics = [
    ('hp', 'Points', 'pts'),
    ('longest_streak', 'Best streak', 'days'),
    ('challenges_completed', 'Completed', 'done'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.person_rounded, size: 18),
                      label: Text('People'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.groups_rounded, size: 18),
                      label: Text('Groups'),
                    ),
                  ],
                  selected: {_groups},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _groups = s.first);
                  },
                ),
              ),
              IconButton(
                tooltip: 'How points work',
                onPressed: () => showPointsInfo(context),
                icon: Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(child: _groups ? _groupsBoard() : _peopleBoard()),
      ],
    );
  }

  Widget _chips(List<(String, String)> items, String selected, ValueChanged<String> onSelect) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final (value, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: selected == value ? AppColors.orange : AppColors.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected == value ? AppColors.orange : AppColors.borderStrong,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(value);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: selected == value ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ people
  Widget _peopleBoard() {
    final unit = _peopleMetrics.firstWhere((m) => m.$1 == _metric).$3;
    final board = ref.watch(leaderboardProvider(_metric));
    final mine = ref.watch(myRankProvider(_metric));

    return Column(
      children: [
        const SizedBox(height: 12),
        _chips([for (final m in _peopleMetrics) (m.$1, m.$2)], _metric,
            (v) => setState(() => _metric = v)),
        const SizedBox(height: 8),
        Expanded(
          child: board.when(
            loading: () => const SlowLoadingHint(),
            error: (e, _) => _Error(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(leaderboardProvider(_metric)),
            ),
            data: (entries) => RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () async {
                ref.invalidate(leaderboardProvider(_metric));
                ref.invalidate(myRankProvider(_metric));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  mine.maybeWhen(
                    data: (m) => _MyRankCard(
                      rank: m['rank'] as int? ?? 0,
                      total: m['total'] as int? ?? 0,
                      value: m['value'] as int? ?? 0,
                      unit: unit,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  RankList(
                    emptyText: 'No one on the board yet. Finish a task to be first!',
                    entries: [
                      for (final e in entries)
                        RankEntry(
                          rank: e.rank,
                          name: e.fullName,
                          value: e.value,
                          unit: unit,
                          isYou: e.isYou,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ groups
  Widget _groupsBoard() {
    final board = ref.watch(groupsLeaderboardProvider(_groupMetric));
    final average = _groupMetric == 'average';

    return Column(
      children: [
        const SizedBox(height: 12),
        _chips(
          const [('total', 'Total points'), ('average', 'Average per member')],
          _groupMetric,
          (v) => setState(() => _groupMetric = v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              average
                  ? 'Groups ranked by the average points of their members.'
                  : "Groups ranked by all their members' points added together.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ),
        Expanded(
          child: board.when(
            loading: () => const SlowLoadingHint(),
            error: (e, _) => _Error(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(groupsLeaderboardProvider(_groupMetric)),
            ),
            data: (groups) => RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () async => ref.invalidate(groupsLeaderboardProvider(_groupMetric)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  RankList(
                    emptyText: 'No groups yet. Create one from the Groups tab!',
                    entries: [
                      for (final g in groups)
                        RankEntry(
                          rank: g.rank,
                          name: g.name,
                          value: average ? g.averagePoints : g.totalPoints,
                          unit: average ? 'avg pts' : 'pts',
                          isYou: g.isYours,
                          subtitle: '${g.memberCount} member${g.memberCount == 1 ? '' : 's'}'
                              ' · Day ${g.currentDay}/${g.durationDays}'
                              '${average ? ' · ${g.totalPoints} total' : ''}',
                          onTap: g.isYours
                              ? () => context.push('/groups/${g.groupId}/dashboard')
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.rank,
    required this.total,
    required this.value,
    required this.unit,
  });

  final int rank;
  final int total;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your rank',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Text(
                  'of $total people',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
              Text(unit, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One row in any leaderboard (people or groups).
class RankEntry {
  const RankEntry({
    required this.rank,
    required this.name,
    required this.value,
    this.unit = 'pts',
    this.subtitle,
    this.isYou = false,
    this.onTap,
  });

  final int rank;
  final String name;
  final int value;
  final String unit;
  final String? subtitle;
  final bool isYou;
  final VoidCallback? onTap;
}

Color rankColor(int rank) => switch (rank) {
      1 => const Color(0xFFF5B301),
      2 => const Color(0xFF9CA3AF),
      3 => const Color(0xFFD9822B),
      _ => AppColors.textSecondary,
    };

/// A leaderboard: podium for the top 3 (with their points), then a list.
class RankList extends StatelessWidget {
  const RankList({super.key, required this.entries, this.emptyText = 'Nothing here yet.'});

  final List<RankEntry> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(emptyText, style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final top = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    return Column(
      children: [
        RankPodium(top: top),
        if (rest.isNotEmpty) const SizedBox(height: 16),
        for (final e in rest) RankRow(entry: e),
      ],
    );
  }
}

/// 2nd, 1st, 3rd side by side, each showing name and points.
class RankPodium extends StatelessWidget {
  const RankPodium({super.key, required this.top});

  final List<RankEntry> top;

  @override
  Widget build(BuildContext context) {
    RankEntry? at(int place) => top.length >= place ? top[place - 1] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumColumn(entry: at(2), place: 2, height: 70)),
          Expanded(child: _PodiumColumn(entry: at(1), place: 1, height: 100)),
          Expanded(child: _PodiumColumn(entry: at(3), place: 3, height: 52)),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({required this.entry, required this.place, required this.height});

  final RankEntry? entry;
  final int place;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = rankColor(place);
    final e = entry;
    final first = place == 1;
    final initial = (e?.name.isNotEmpty ?? false) ? e!.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: e?.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              e!.onTap!();
            },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (first)
            Icon(Icons.workspace_premium_rounded, color: color, size: 26)
          else
            const SizedBox(height: 26),
          Container(
            width: first ? 60 : 50,
            height: first ? 60 : 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: e == null ? AppColors.border : color.withValues(alpha: 0.16),
              border: Border.all(
                color: e == null ? AppColors.border : color,
                width: e?.isYou == true ? 3 : 2,
              ),
            ),
            child: Text(
              e == null ? '' : initial,
              style: TextStyle(
                fontSize: first ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: Text(
              e == null ? '' : e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: e?.isYou == true ? AppColors.orange : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // The number people want to see: the points this place has.
          Text(
            e == null ? '' : '${e.value} ${e.unit}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: e == null ? AppColors.muted : AppColors.orange,
            ),
          ),
          SizedBox(
            height: 30,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                e?.subtitle ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, height: 1.25, color: AppColors.textSecondary),
              ),
            ),
          ),
          Container(
            height: height,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: e == null ? 0.06 : 0.16),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              '$place',
              style: TextStyle(
                fontSize: first ? 26 : 22,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: e == null ? 0.4 : 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single ranked row (4th place and below, or any list).
class RankRow extends StatelessWidget {
  const RankRow({super.key, required this.entry});

  final RankEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final initial = e.name.isNotEmpty ? e.name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: e.isYou ? AppColors.orangeSoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: e.isYou ? AppColors.orange : AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: e.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${e.rank}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: rankColor(e.rank),
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.orange.withValues(alpha: 0.14),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (e.isYou) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (e.subtitle != null)
                        Text(
                          e.subtitle!,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${e.value}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                    Text(
                      e.unit,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

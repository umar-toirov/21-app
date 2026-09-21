import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';

/// A month calendar on Home showing everything the user did: perfect days,
/// partial days and missed days. Tap a day to see the exact tasks.
class ActivityCalendarCard extends ConsumerStatefulWidget {
  const ActivityCalendarCard({super.key});

  @override
  ConsumerState<ActivityCalendarCard> createState() => _ActivityCalendarCardState();
}

class _ActivityCalendarCardState extends ConsumerState<ActivityCalendarCard> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activityProvider(_key));
    final data = async.valueOrNull;
    final byDate = <String, Map<String, dynamic>>{
      for (final d in (data?['days'] as List? ?? const []))
        (d as Map<String, dynamic>)['date'] as String: d,
    };
    final totals = data?['totals'] as Map<String, dynamic>?;

    final first = _month;
    final daysInMonth = DateUtils.getDaysInMonth(first.year, first.month);
    final leading = first.weekday - 1; // Monday first
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM y').format(_month),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _isCurrentMonth ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: () {
                      final n = r * 7 + c - leading + 1;
                      if (n < 1 || n > daysInMonth) return const SizedBox(height: 44);
                      final date = DateTime(first.year, first.month, n);
                      final id = DateFormat('yyyy-MM-dd').format(date);
                      return _DayCell(
                        day: n,
                        status: byDate[id]?['status'] as String?,
                        isToday: date.year == now.year && date.month == now.month && date.day == now.day,
                        onTap: () => _openDay(date, byDate[id]),
                      );
                    }(),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          if (async.hasError && data == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Couldn't load your activity.",
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(activityProvider(_key)),
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _Legend(color: AppColors.teal, label: 'All done'),
                const _Legend(color: AppColors.orange, label: 'Some done'),
                const _Legend(color: AppColors.danger, label: 'Missed'),
                if (totals != null)
                  Text(
                    '${totals['tasks_done']} tasks · ${totals['perfect_days']} perfect days',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _openDay(DateTime date, Map<String, dynamic>? entry) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DaySheet(date: date, entry: entry),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final String? status;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? fill;
    Color text = AppColors.textPrimary;
    Color? border;
    switch (status) {
      case 'done':
        fill = AppColors.teal;
        text = Colors.white;
      case 'partial':
        fill = AppColors.orangeSoft;
        border = AppColors.orange;
      case 'missed':
        fill = AppColors.dangerSoft;
        text = AppColors.danger;
      case 'upcoming' || 'pending':
        text = AppColors.textSecondary;
      default:
        text = AppColors.muted;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: isToday ? AppColors.orange : (border ?? Colors.transparent),
                width: isToday ? 2 : 1.2,
              ),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isToday || status == 'done' ? FontWeight.w700 : FontWeight.w500,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.date, required this.entry});

  final DateTime date;
  final Map<String, dynamic>? entry;

  @override
  Widget build(BuildContext context) {
    final tasks = (entry?['tasks'] as List? ?? const []).cast<Map<String, dynamic>>();
    final status = entry?['status'] as String?;
    final summary = switch (status) {
      'done' => 'You finished everything. +10 bonus.',
      'partial' => '${tasks.length} task${tasks.length == 1 ? '' : 's'} done.',
      'missed' => 'You missed this day. It cost 15 points and reset your streak.',
      'pending' => 'Nothing done yet today.',
      'upcoming' => 'This day has not started yet.',
      _ => 'Nothing recorded for this day.',
    };

    // Group by challenge so it reads like a diary.
    final byChallenge = <String, List<Map<String, dynamic>>>{};
    for (final t in tasks) {
      byChallenge.putIfAbsent(t['challenge'] as String? ?? 'Challenge', () => []).add(t);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(date),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(summary, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              for (final e in byChallenge.entries) ...[
                Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final t in e.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t['title'] as String? ?? '',
                            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                          ),
                        ),
                        if (t['completed_at'] != null)
                          Text(
                            DateFormat('HH:mm').format(
                              DateTime.parse(t['completed_at'] as String).toLocal(),
                            ),
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

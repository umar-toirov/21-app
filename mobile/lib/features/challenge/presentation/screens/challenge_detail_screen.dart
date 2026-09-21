import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/how_it_works.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/slow_loading_hint.dart';

/// Points shown next to a task. The server decides the real amount.
const _taskPointsHint = kTaskPoints;

enum _Filter { all, foundation, personal }

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  int? _selectedDay;
  bool _showCelebration = false;
  String _celebrationSubtitle = 'Next day unlocks after midnight';
  List<TaskModel>? _dayTasks;
  bool _loadingDay = false;
  _Filter _filter = _Filter.all;

  /// Tasks ticked locally before the server confirms, so taps feel instant.
  final Set<String> _pendingDone = {};

  Future<void> _loadDay(ChallengeModel challenge, int dayNumber) async {
    HapticFeedback.selectionClick();
    if (dayNumber == challenge.currentDay &&
        challenge.status != 'completed' &&
        challenge.status != 'failed') {
      setState(() {
        _selectedDay = dayNumber;
        _dayTasks = null;
      });
      return;
    }
    setState(() {
      _selectedDay = dayNumber;
      _loadingDay = true;
    });
    try {
      final data = await ref
          .read(apiRepositoryProvider)
          .getChallengeDay(challenge.id, dayNumber);
      final tasks = (data['tasks'] as List<dynamic>? ?? [])
          .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _dayTasks = tasks;
        _loadingDay = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dayTasks = const [];
        _loadingDay = false;
      });
    }
  }

  Future<void> _toggleTask(ChallengeModel challenge, TaskModel task) async {
    if (task.isCompleted || _pendingDone.contains(task.id)) return;
    if (_selectedDay != null && _selectedDay != challenge.currentDay) return;
    setState(() => _pendingDone.add(task.id));
    try {
      final result = await ref.read(apiRepositoryProvider).completeTask(
            challenge.id,
            task.id,
          );
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(activeProgramsProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(personalStatsProvider);
      if (result['challenge_completed'] == true && mounted) {
        SoundService.instance.playDay();
        context.go(AppRoutes.challengeComplete);
        return;
      }
      if (result['celebration'] == true && mounted) {
        SoundService.instance.playDay();
        HapticFeedback.heavyImpact();
        setState(() {
          _showCelebration = true;
          _celebrationSubtitle =
              (result['reward_message'] as String?) ?? 'Next day unlocks after midnight';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pendingDone.remove(task.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that. Check your connection and try again.")),
        );
      }
    }
  }

  bool _isDone(TaskModel t) => t.isCompleted || _pendingDone.contains(t.id);

  Future<void> _cancelChallenge(ChallengeModel challenge) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this challenge?'),
        content: const Text(
          'It stops right away and moves to your history. The points you already earned '
          'stay, and you can start a new challenge whenever you like.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel challenge', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiRepositoryProvider).cancelChallenge(challenge.id);
      _refreshEverything();
      if (!mounted) return;
      context.go(AppRoutes.home);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge cancelled. Your points are kept.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _leaveGroup(ChallengeModel challenge) async {
    final groupId = challenge.groupId;
    if (groupId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text(
          'Your group challenge ends and you leave the ranking. You can join again later '
          'with the invite code.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiRepositoryProvider).leaveGroup(groupId);
      ref.invalidate(groupsProvider);
      _refreshEverything();
      if (!mounted) return;
      context.go('${AppRoutes.home}/groups');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  void _refreshEverything() {
    ref.invalidate(challengeDetailProvider(widget.challengeId));
    ref.invalidate(activeChallengeProvider);
    ref.invalidate(activeProgramsProvider);
    ref.invalidate(challengesListProvider);
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(challengeDetailProvider(widget.challengeId));
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const SlowLoadingHint(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Couldn't load this challenge.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(challengeDetailProvider(widget.challengeId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (challenge) => _buildData(context, challenge, profile),
      ),
    );
  }

  Widget _buildData(BuildContext context, ChallengeModel challenge, ProfileModel? profile) {
    final selected = _selectedDay ?? challenge.currentDay;
    final isToday = selected == challenge.currentDay &&
        challenge.status != 'completed' &&
        challenge.status != 'failed';
    ChallengeDayModel? dayMeta;
    for (final d in challenge.days) {
      if (d.dayNumber == selected) {
        dayMeta = d;
        break;
      }
    }
    final allTasks = isToday ? challenge.tasks : (_dayTasks ?? const <TaskModel>[]);
    final hasBothTypes = allTasks.any((t) => t.type == 'foundation') &&
        allTasks.any((t) => t.type != 'foundation');
    final filter = hasBothTypes ? _filter : _Filter.all;
    final shown = allTasks.where((t) {
      return switch (filter) {
        _Filter.all => true,
        _Filter.foundation => t.type == 'foundation',
        _Filter.personal => t.type != 'foundation',
      };
    }).toList();
    final todo = shown.where((t) => !_isDone(t)).toList();
    final done = shown.where(_isDone).toList();

    final totalToday = challenge.tasks.length;
    final doneToday = challenge.tasks.where(_isDone).length;
    final pointsToday = challenge.pointsToday +
        challenge.tasks
                .where((t) => _pendingDone.contains(t.id) && !t.isCompleted)
                .length *
            _taskPointsHint;
    final isPast = challenge.status == 'completed' || challenge.status == 'failed';
    final locked = !isToday && dayMeta?.isLocked == true;

    return Stack(
      children: [
        SafeArea(
          child: RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async =>
                ref.invalidate(challengeDetailProvider(widget.challengeId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _Header(
                  challenge: challenge,
                  points: profile?.hp,
                  onCancel: !isPast && !challenge.isGroup ? () => _cancelChallenge(challenge) : null,
                  onLeave: !isPast && challenge.isGroup ? () => _leaveGroup(challenge) : null,
                ),
                const SizedBox(height: 16),
                if (isPast) ...[
                  _Banner(
                    icon: challenge.status == 'completed'
                        ? Icons.emoji_events_rounded
                        : Icons.flag_rounded,
                    color: challenge.status == 'completed' ? AppColors.gold : AppColors.danger,
                    text: challenge.status == 'completed'
                        ? 'Challenge completed. Review what you achieved day by day.'
                        : 'This challenge ended early. Missed days and completed tasks are below.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (challenge.isScheduled) ...[
                  _Banner(
                    icon: Icons.event_rounded,
                    color: AppColors.orange,
                    text: challenge.todayMission ?? 'This challenge has not started yet.',
                  ),
                  const SizedBox(height: 12),
                ],
                _DayStrip(
                  days: challenge.days.isNotEmpty
                      ? challenge.days
                      : [
                          ChallengeDayModel(
                            dayNumber: challenge.currentDay,
                            calendarDate: DateTime.now().toIso8601String().split('T').first,
                            isComplete: challenge.dayComplete,
                            isMissed: false,
                            isToday: true,
                            isLocked: false,
                          ),
                        ],
                  selected: selected,
                  onSelect: (day) => _loadDay(challenge, day),
                ),
                const SizedBox(height: 16),
                if (isToday && !challenge.isScheduled && totalToday > 0)
                  _SummaryCard(
                    done: doneToday,
                    total: totalToday,
                    points: pointsToday,
                    streak: profile?.currentStreak,
                  ).animate().fadeIn(duration: 200.ms),
                if (isToday && !challenge.isScheduled && totalToday > 0)
                  const SizedBox(height: 18),
                if (!isToday)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      locked
                          ? 'This day unlocks after midnight.'
                          : dayMeta?.isMissed == true
                              ? 'Day $selected · Missed'
                              : 'Day $selected${dayMeta?.isComplete == true ? ' · Completed' : ''}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: dayMeta?.isMissed == true
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (hasBothTypes) ...[
                  _Filters(
                    group: challenge.isGroup,
                    value: filter,
                    onChanged: (f) {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = f);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (_loadingDay)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
                  )
                else if (locked)
                  const SizedBox.shrink()
                else if (allTasks.isEmpty)
                  SoftCard(
                    child: Text(
                      'No task records for this day.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else ...[
                  if (todo.isNotEmpty) ...[
                    _SectionHeader(isToday ? 'To do' : 'Not done', todo.length),
                    for (final t in todo)
                      TaskTile(
                        title: t.title,
                        isCompleted: false,
                        isFoundation: t.type == 'foundation',
                        groupTask: challenge.isGroup,
                        points: isToday ? _taskPointsHint : null,
                        onChanged: (!isToday || challenge.isScheduled)
                            ? null
                            : (_) => _toggleTask(challenge, t),
                      ),
                  ],
                  if (done.isNotEmpty) ...[
                    _SectionHeader('Done', done.length),
                    for (final t in done)
                      TaskTile(
                        title: t.title,
                        isCompleted: true,
                        isFoundation: t.type == 'foundation',
                        groupTask: challenge.isGroup,
                        onChanged: null,
                      ),
                  ],
                  if (isToday && !challenge.isScheduled && totalToday > 0 && doneToday == totalToday)
                    _Banner(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      text: 'All done for today. The next day unlocks after midnight.',
                    ).animate().fadeIn(duration: 250.ms),
                ],
                if (challenge.quote != null && isToday) ...[
                  const SizedBox(height: 20),
                  Text(
                    challenge.quote!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_showCelebration)
          CelebrationOverlay(
            title: 'Day complete!',
            subtitle: _celebrationSubtitle,
            onDismiss: () => setState(() => _showCelebration = false),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.challenge, this.points, this.onCancel, this.onLeave});

  final ChallengeModel challenge;
  final int? points;
  final VoidCallback? onCancel;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.pop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                challenge.isScheduled
                    ? 'Starts in ${challenge.daysUntilStart} day${challenge.daysUntilStart == 1 ? '' : 's'}'
                    : 'Day ${challenge.currentDay} of ${challenge.durationDays}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (points != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: AppColors.orange),
                const SizedBox(width: 4),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
        if (onCancel != null || onLeave != null)
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            onSelected: (v) {
              if (v == 'cancel') onCancel?.call();
              if (v == 'leave') onLeave?.call();
            },
            itemBuilder: (_) => [
              if (onCancel != null)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel challenge', style: TextStyle(color: AppColors.danger)),
                ),
              if (onLeave != null)
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave group', style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of the challenge's days, like a week calendar.
class _DayStrip extends StatefulWidget {
  const _DayStrip({required this.days, required this.selected, required this.onSelect});

  final List<ChallengeDayModel> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const _itemWidth = 58.0;
  static const _gap = 8.0;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected(animate: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerSelected({bool animate = true}) {
    if (!_controller.hasClients) return;
    final index = widget.days.indexWhere((d) => d.dayNumber == widget.selected);
    if (index < 0) return;
    final target = (index * (_itemWidth + _gap) -
            (_controller.position.viewportDimension - _itemWidth) / 2)
        .clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final d = widget.days[i];
          return _DayPill(
            day: d,
            selected: d.dayNumber == widget.selected,
            onTap: () => widget.onSelect(d.dayNumber),
          );
        },
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.selected, required this.onTap});

  final ChallengeDayModel day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(day.calendarDate);
    final weekday = date == null ? '' : DateFormat('E').format(date);
    final number = date == null ? '${day.dayNumber}' : '${date.day}';

    final Color bg;
    final Color fg;
    if (selected) {
      bg = AppColors.orange;
      fg = Colors.white;
    } else if (day.isComplete) {
      bg = AppColors.tealSoft;
      fg = AppColors.textPrimary;
    } else if (day.isMissed) {
      bg = AppColors.dangerSoft;
      fg = AppColors.textPrimary;
    } else {
      bg = AppColors.surface;
      fg = day.isLocked ? AppColors.muted : AppColors.textPrimary;
    }

    Widget status;
    if (day.isComplete) {
      status = Icon(Icons.check_circle_rounded,
          size: 14, color: selected ? Colors.white : AppColors.teal);
    } else if (day.isMissed) {
      status = Icon(Icons.close_rounded,
          size: 14, color: selected ? Colors.white : AppColors.danger);
    } else if (day.isToday) {
      status = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white : AppColors.orange,
        ),
      );
    } else if (day.isLocked) {
      status = Icon(Icons.lock_outline_rounded,
          size: 12, color: selected ? Colors.white70 : AppColors.muted);
    } else {
      status = const SizedBox(height: 14);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.orange
                : (day.isToday ? AppColors.orange.withValues(alpha: 0.6) : AppColors.border),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: fg.withValues(alpha: selected ? 0.9 : 0.7),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              number,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: fg,
              ),
            ),
            const SizedBox(height: 5),
            status,
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.done,
    required this.total,
    required this.points,
    this.streak,
  });

  final int done;
  final int total;
  final int points;
  final int? streak;

  @override
  Widget build(BuildContext context) {
    final all = total > 0 && done == total;
    final progress = total == 0 ? 0.0 : done / total;
    final accent = all ? AppColors.success : AppColors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AnimatedRing(
            progress: progress,
            size: 64,
            stroke: 7,
            color: accent,
            child: Text(
              '$done/$total',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  all ? 'All done for today' : "${total - done} task${total - done == 1 ? '' : 's'} left today",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    GestureDetector(
                      onTap: () => showPointsInfo(context),
                      child: _MiniStat(
                        icon: Icons.bolt_rounded,
                        color: AppColors.orange,
                        text: '+$points today  ⓘ',
                      ),
                    ),
                    if (streak != null)
                      _MiniStat(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.orange,
                        text: '$streak day streak',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.value, required this.onChanged, this.group = false});

  final bool group;
  final _Filter value;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = {
      _Filter.all: 'All',
      _Filter.foundation: group ? 'Group tasks' : 'Foundation',
      _Filter.personal: group ? 'My tasks' : 'Personal',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      children: [
        for (final f in _Filter.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: value == f ? AppColors.orange : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: value == f ? AppColors.orange : AppColors.borderStrong,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(f),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(
                    labels[f]!,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: value == f ? Colors.white : AppColors.textPrimary,
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Text(
        '$title  ·  $count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

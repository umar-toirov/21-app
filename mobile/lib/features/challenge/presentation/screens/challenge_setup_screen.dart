import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/challenge_icons.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

enum _StartChoice { today, tomorrow, pick }

/// Customise a challenge (from a framework or from scratch) and choose when it starts.
class ChallengeSetupScreen extends ConsumerStatefulWidget {
  const ChallengeSetupScreen({super.key, this.template});

  /// `null` means "create your own".
  final ChallengeTemplate? template;

  @override
  ConsumerState<ChallengeSetupScreen> createState() => _ChallengeSetupScreenState();
}

class _ChallengeSetupScreenState extends ConsumerState<ChallengeSetupScreen> {
  static const _durations = [7, 14, 21, 30, 60];
  static const _maxTasks = 10;
  static const _foundation = ['Wake up on time', 'Daily planning', 'Evening review'];

  late final TextEditingController _name;
  final _taskField = TextEditingController();
  final _taskFocus = FocusNode();
  late final List<String> _tasks;
  late int _duration;
  bool _includeFoundation = true;
  bool _saving = false;

  _StartChoice _choice = _StartChoice.today;
  late DateTime _start;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(text: t?.title ?? '');
    _tasks = [...?t?.tasks];
    _duration = t?.durationDays ?? 21;
    _start = _dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _name.dispose();
    _taskField.dispose();
    _taskFocus.dispose();
    super.dispose();
  }

  DateTime get _today => _dateOnly(DateTime.now());
  bool get _isScheduled => _start.isAfter(_today);
  DateTime get _end => _start.add(Duration(days: _duration - 1));
  String _fmt(DateTime d) => DateFormat('EEE, MMM d').format(d);

  void _addTask() {
    final text = _taskField.text.trim();
    if (text.isEmpty) return;
    if (_tasks.any((t) => t.toLowerCase() == text.toLowerCase())) {
      _taskField.clear();
      return;
    }
    if (_tasks.length >= _maxTasks) {
      _toast('You can add up to $_maxTasks tasks.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _tasks.add(text));
    _taskField.clear();
    _taskFocus.requestFocus();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      ));
  }

  Future<void> _setStart(_StartChoice choice) async {
    HapticFeedback.selectionClick();
    switch (choice) {
      case _StartChoice.today:
        setState(() {
          _choice = choice;
          _start = _today;
        });
      case _StartChoice.tomorrow:
        setState(() {
          _choice = choice;
          _start = _today.add(const Duration(days: 1));
        });
      case _StartChoice.pick:
        final picked = await showDatePicker(
          context: context,
          initialDate: _start,
          firstDate: _today,
          lastDate: _today.add(const Duration(days: 60)),
          helpText: 'Choose a start date',
        );
        if (picked == null || !mounted) return;
        setState(() {
          _choice = choice;
          _start = _dateOnly(picked);
        });
    }
  }

  Future<void> _submit() async {
    // Pick up a task the user typed but did not add yet.
    if (_taskField.text.trim().isNotEmpty) _addTask();
    if (_tasks.length < 2) {
      _toast('Add at least 2 daily tasks.');
      return;
    }
    final name = _name.text.trim().isEmpty
        ? (widget.template?.title ?? 'My $_duration-day challenge')
        : _name.text.trim();

    setState(() => _saving = true);
    try {
      await ref.read(apiRepositoryProvider).createChallenge(
            templateId: widget.template?.id,
            name: name,
            durationDays: _duration,
            startDate: _start,
            tasks: _tasks,
            includeFoundation: _includeFoundation,
          );
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(activeProgramsProvider);
      ref.invalidate(challengesListProvider);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      final scheduled = _isScheduled;
      final startLabel = _fmt(_start);
      context.go(AppRoutes.home);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            scheduled
                ? 'Challenge scheduled for $startLabel.'
                : 'Challenge started. Day 1 is today!',
          ),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final color = challengeCategoryColor(t?.category ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(t == null ? 'Your own challenge' : 'Set up challenge')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      _hero(t, color),
                      const SizedBox(height: 24),
                      const _Label('Challenge name'),
                      TextField(
                        controller: _name,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Read every day',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _Label('Duration'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in _durations)
                            _Pill(
                              label: '$d days',
                              selected: _duration == d,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _duration = d);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _Label('Start date'),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_StartChoice>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: _StartChoice.today, label: Text('Today')),
                            ButtonSegment(value: _StartChoice.tomorrow, label: Text('Tomorrow')),
                            ButtonSegment(
                              value: _StartChoice.pick,
                              icon: Icon(Icons.calendar_month_rounded, size: 18),
                              label: Text('Pick'),
                            ),
                          ],
                          selected: {_choice},
                          onSelectionChanged: (s) => _setStart(s.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StartSummary(
                        scheduled: _isScheduled,
                        start: _fmt(_start),
                        end: _fmt(_end),
                        days: _duration,
                      ),
                      const SizedBox(height: 22),
                      _Label('Daily tasks  ·  ${_tasks.length} of $_maxTasks'),
                      if (_tasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Add at least 2 things you will do every day.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      for (var i = 0; i < _tasks.length; i++)
                        _TaskRow(
                          title: _tasks[i],
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tasks.removeAt(i));
                          },
                        ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _taskField,
                        focusNode: _taskFocus,
                        maxLength: 120,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addTask(),
                        decoration: InputDecoration(
                          hintText: 'Add your own task',
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange),
                            onPressed: _addTask,
                            tooltip: 'Add task',
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SoftCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: const Text('Add daily basics'),
                          subtitle: Text(
                            _foundation.join(' · '),
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          value: _includeFoundation,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _includeFoundation = v);
                          },
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: PrimaryButton(
                    label: _isScheduled ? 'Schedule challenge' : 'Start challenge',
                    isLoading: _saving,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(ChallengeTemplate? t, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          GlossyIcon(
            icon: t == null ? Icons.add_rounded : challengeIcon(t.icon),
            color: t == null ? AppColors.orange : color,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t?.title ?? 'Create your own',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t?.description ?? 'Choose your tasks and make it yours.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.orange : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.orange : AppColors.borderStrong),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StartSummary extends StatelessWidget {
  const _StartSummary({
    required this.scheduled,
    required this.start,
    required this.end,
    required this.days,
  });

  final bool scheduled;
  final String start;
  final String end;
  final int days;

  @override
  Widget build(BuildContext context) {
    final accent = scheduled ? AppColors.orange : AppColors.teal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            scheduled ? Icons.event_rounded : Icons.play_circle_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              scheduled
                  ? 'Starts $start. Day $days on $end.'
                  : 'Starts today. Day $days on $end.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.title, required this.onRemove});

  final String title;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                title,
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove',
            icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

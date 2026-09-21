import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/task_list_editor.dart';

const groupTaskSuggestions = [
  'Read 20 pages',
  'Workout 30 minutes',
  'Study 1 hour',
  'Wake up before 7',
  'No phone before bed',
  'Journal for 5 minutes',
  'Walk 8,000 steps',
  'Deep work 2 hours',
];

enum _Start { today, tomorrow, pick }

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  int _duration = 21;
  int _maxMissed = 3;
  bool _saving = false;

  /// 'shared' = everyone does the admin's tasks. 'freedom' = members also pick their own.
  String _mode = 'shared';
  final List<String> _groupTasks = [];
  final List<String> _ownTasks = [];

  _Start _startChoice = _Start.today;
  late DateTime _start = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime get _today => _dateOnly(DateTime.now());

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _setStart(_Start choice) async {
    HapticFeedback.selectionClick();
    switch (choice) {
      case _Start.today:
        setState(() {
          _startChoice = choice;
          _start = _today;
        });
      case _Start.tomorrow:
        setState(() {
          _startChoice = choice;
          _start = _today.add(const Duration(days: 1));
        });
      case _Start.pick:
        final picked = await showDatePicker(
          context: context,
          initialDate: _start,
          firstDate: _today,
          lastDate: _today.add(const Duration(days: 60)),
          helpText: 'Choose a start date',
        );
        if (picked == null || !mounted) return;
        setState(() {
          _startChoice = choice;
          _start = _dateOnly(picked);
        });
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      ));
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Give your group a name.');
      return;
    }
    if (_mode == 'shared' && _groupTasks.isEmpty) {
      _toast('Add at least one task for the group.');
      return;
    }
    if (_mode == 'freedom' && _groupTasks.isEmpty && _ownTasks.isEmpty) {
      _toast('Add at least one task for yourself or for the group.');
      return;
    }

    setState(() => _saving = true);
    try {
      String two(int n) => n.toString().padLeft(2, '0');
      final group = await ref.read(apiRepositoryProvider).createGroup({
        'name': name,
        'duration_days': _duration,
        'max_missed_days': _maxMissed,
        'starts_at': '${_start.year}-${two(_start.month)}-${two(_start.day)}',
        'task_mode': _mode,
        'group_tasks': _groupTasks,
        'personal_tasks': _mode == 'freedom' ? _ownTasks : <String>[],
      });
      ref.invalidate(groupsProvider);
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(activeProgramsProvider);
      if (!mounted) return;
      context.pushReplacement('/groups/${group.id}/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a group')),
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
                      const _Note(
                        icon: Icons.admin_panel_settings_rounded,
                        text: 'You will be the admin. You set the tasks, invite people '
                            'with a code, and can add or remove tasks for everyone at any time.',
                      ),
                      const SizedBox(height: 20),
                      const _Label('Group name'),
                      TextField(
                        controller: _name,
                        maxLength: 60,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Morning Discipline Squad',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _Label('How long?'),
                      Row(
                        children: [
                          for (final d in const [21, 30])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Pill(
                                label: '$d days',
                                selected: _duration == d,
                                onTap: () => setState(() => _duration = d),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _Label('Start date'),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_Start>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: _Start.today, label: Text('Today')),
                            ButtonSegment(value: _Start.tomorrow, label: Text('Tomorrow')),
                            ButtonSegment(
                              value: _Start.pick,
                              icon: Icon(Icons.calendar_month_rounded, size: 18),
                              label: Text('Pick'),
                            ),
                          ],
                          selected: {_startChoice},
                          onSelectionChanged: (s) => _setStart(s.first),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _start == _today
                            ? 'Starts today.'
                            : 'Starts ${DateFormat('EEE, MMM d').format(_start)}.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 22),
                      const _Label('Allowed missed days in a row'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final n in const [1, 2, 3, 4, 5])
                            _Pill(
                              label: '$n',
                              selected: _maxMissed == n,
                              onTap: () => setState(() => _maxMissed = n),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A member who misses this many days in a row goes into recovery.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 26),
                      const _Label('How do tasks work?'),
                      _ModeCard(
                        selected: _mode == 'shared',
                        icon: Icons.groups_rounded,
                        title: 'Same tasks for everyone',
                        body: 'You choose the tasks. Every member does exactly these.',
                        onTap: () => setState(() => _mode = 'shared'),
                      ),
                      const SizedBox(height: 10),
                      _ModeCard(
                        selected: _mode == 'freedom',
                        icon: Icons.tune_rounded,
                        title: 'Members choose their own',
                        body: 'Each member picks their own tasks when they join. You can '
                            'still add tasks that everyone must do.',
                        onTap: () => setState(() => _mode = 'freedom'),
                      ),
                      const SizedBox(height: 26),
                      _Label(_mode == 'shared'
                          ? 'Tasks for everyone  ·  ${_groupTasks.length} of 15'
                          : 'Tasks for everyone (optional)  ·  ${_groupTasks.length} of 15'),
                      TaskListEditor(
                        tasks: _groupTasks,
                        max: 15,
                        suggestions: groupTaskSuggestions,
                        hint: 'Add a task for everyone',
                        emptyText: _mode == 'shared'
                            ? 'Add at least one task. Everyone will do it every day.'
                            : 'Nothing required. Add one if you want everyone to share it.',
                        onAdd: (t) => setState(() => _groupTasks.add(t)),
                        onRemove: (t) => setState(() => _groupTasks.remove(t)),
                      ),
                      if (_mode == 'freedom') ...[
                        const SizedBox(height: 26),
                        _Label('Your own tasks  ·  ${_ownTasks.length} of 10'),
                        TaskListEditor(
                          tasks: _ownTasks,
                          suggestions: groupTaskSuggestions,
                          hint: 'Add a task for yourself',
                          emptyText: 'You are a member too. Choose what you will do.',
                          onAdd: (t) => setState(() => _ownTasks.add(t)),
                          onRemove: (t) => setState(() => _ownTasks.remove(t)),
                        ),
                      ],
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
                    label: 'Create group',
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
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
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

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ],
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
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.orangeSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppColors.orange : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.orange, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

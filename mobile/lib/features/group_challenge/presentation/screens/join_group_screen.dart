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
import 'create_group_screen.dart' show groupTaskSuggestions;

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, this.initialCode});

  /// Pre-fills and looks up this invite code (e.g. from a shared link).
  final String? initialCode;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  bool _joining = false;
  bool _looking = false;
  Map<String, dynamic>? _preview;
  final List<String> _ownTasks = [];

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null && code.isNotEmpty) {
      _code.text = code.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  bool get _freedom => (_preview?['task_mode'] as String?) == 'freedom';
  List<String> get _groupTasks =>
      List<String>.from((_preview?['group_tasks'] ?? _preview?['foundation_tasks'] ?? const []) as List);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
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

  Future<void> _lookup() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _looking = true;
      _preview = null;
      _ownTasks.clear();
    });
    try {
      final preview = await ref.read(apiRepositoryProvider).previewGroupInvite(code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (mounted) {
        _toast(apiErrorMessage(e).contains('Something went wrong')
            ? 'We could not find a group with that code.'
            : apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _join() async {
    if (_preview == null) return;
    if (_freedom && _ownTasks.isEmpty && _groupTasks.isEmpty) {
      _toast('Choose at least one task for yourself.');
      return;
    }

    final inGroup = ref.read(activeProgramsProvider).valueOrNull?.group != null;
    if (inGroup) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Leave your current group?'),
          content: const Text(
            "You can be in one group challenge at a time. Joining this group "
            "ends your current group challenge. Your personal challenge keeps running.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join anyway')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _joining = true);
    try {
      final group = await ref.read(apiRepositoryProvider).joinGroup(
            _code.text.trim().toUpperCase(),
            personalTasks: _freedom ? _ownTasks : null,
          );
      ref.invalidate(groupsProvider);
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(activeProgramsProvider);
      if (!mounted) return;
      context.pushReplacement('/groups/${group.id}/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      _toast(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Join a group')),
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
                      Text(
                        'Enter the invite code the group admin shared with you.',
                        style: TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        maxLength: 12,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                          TextInputFormatter.withFunction(
                            (_, v) => v.copyWith(text: v.text.toUpperCase()),
                          ),
                        ],
                        onChanged: (_) {
                          if (_preview != null) setState(() => _preview = null);
                        },
                        onSubmitted: (_) => _lookup(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                        decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
                      ),
                      const SizedBox(height: 12),
                      if (p == null)
                        PrimaryButton(
                          label: 'Find group',
                          isLoading: _looking,
                          onPressed: _lookup,
                        ),
                      if (p != null) ...[
                        const SizedBox(height: 8),
                        _GroupCard(preview: p),
                        const SizedBox(height: 22),
                        _section(
                          _groupTasks.isEmpty
                              ? 'Tasks'
                              : (_freedom ? 'Tasks everyone does' : 'Your tasks'),
                        ),
                        if (_groupTasks.isNotEmpty)
                          for (final t in _groupTasks) _ReadOnlyTask(title: t)
                        else
                          Text(
                            'The admin has not set tasks for everyone. You choose your own.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        if (!_freedom)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Everyone does the same tasks. You will find them in Today '
                              'after you join, and the admin can add more later.',
                              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                            ),
                          ),
                        if (_freedom) ...[
                          const SizedBox(height: 22),
                          _section('Choose your own tasks  ·  ${_ownTasks.length} of 10'),
                          TaskListEditor(
                            tasks: _ownTasks,
                            suggestions: groupTaskSuggestions,
                            hint: 'Add a task for yourself',
                            emptyText: _groupTasks.isEmpty
                                ? 'This group lets you choose. Pick at least one.'
                                : 'Optional. Add tasks on top of the ones above.',
                            onAdd: (t) => setState(() => _ownTasks.add(t)),
                            onRemove: (t) => setState(() => _ownTasks.remove(t)),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (p != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: PrimaryButton(
                      label: 'Join ${p['name']}',
                      isLoading: _joining,
                      onPressed: _join,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.preview});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final starts = DateTime.tryParse(preview['starts_at'] as String? ?? '');
    final members = preview['member_count'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.groups_rounded, color: AppColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview['name'] as String? ?? 'Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (preview['leader_name'] != null)
                      Text(
                        'Admin: ${preview['leader_name']}',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Fact(Icons.people_alt_rounded, '$members member${members == 1 ? '' : 's'}'),
              _Fact(Icons.calendar_today_rounded, '${preview['duration_days']} days'),
              if (starts != null)
                _Fact(Icons.play_circle_outline_rounded, 'Starts ${DateFormat('MMM d').format(starts)}'),
              _Fact(Icons.warning_amber_rounded,
                  '${preview['max_missed_days']} missed days allowed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ReadOnlyTask extends StatelessWidget {
  const _ReadOnlyTask({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_rounded, size: 20, color: AppColors.goldDepth),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

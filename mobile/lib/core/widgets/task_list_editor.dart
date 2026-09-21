import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A list of task titles with "add your own" and quick suggestions.
/// Works for local lists (create/join) and for server-backed ones (group
/// settings): [onAdd] / [onRemove] may be async and the parent updates [tasks].
class TaskListEditor extends StatefulWidget {
  const TaskListEditor({
    super.key,
    required this.tasks,
    required this.onAdd,
    required this.onRemove,
    this.suggestions = const [],
    this.max = 10,
    this.hint = 'Add a task',
    this.emptyText = 'No tasks yet.',
    this.busy = false,
  });

  final List<String> tasks;
  final FutureOr<void> Function(String title) onAdd;
  final FutureOr<void> Function(String title) onRemove;
  final List<String> suggestions;
  final int max;
  final String hint;
  final String emptyText;
  final bool busy;

  @override
  State<TaskListEditor> createState() => _TaskListEditorState();
}

class _TaskListEditorState extends State<TaskListEditor> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _has(String title) =>
      widget.tasks.any((t) => t.trim().toLowerCase() == title.trim().toLowerCase());

  Future<void> _add(String raw) async {
    final title = raw.trim();
    if (title.isEmpty || _has(title)) {
      _field.clear();
      return;
    }
    if (widget.tasks.length >= widget.max) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('You can add up to ${widget.max} tasks.')));
      return;
    }
    HapticFeedback.selectionClick();
    _field.clear();
    await widget.onAdd(title);
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.suggestions.where((s) => !_has(s)).take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.emptyText, style: TextStyle(color: AppColors.textSecondary)),
          ),
        for (final t in widget.tasks)
          Container(
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
                    child: Text(t, style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: widget.busy ? null : () => widget.onRemove(t),
                  icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        if (open.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in open)
                ActionChip(
                  label: Text(s),
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  onPressed: widget.busy ? null : () => _add(s),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _field,
          focusNode: _focus,
          maxLength: 120,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: _add,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            suffixIcon: IconButton(
              tooltip: 'Add task',
              onPressed: widget.busy ? null : () => _add(_field.text),
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange),
            ),
          ),
        ),
      ],
    );
  }
}

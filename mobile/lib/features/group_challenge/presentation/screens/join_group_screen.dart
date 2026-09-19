import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  final _customPersonal = TextEditingController();
  bool _loading = false;
  bool _previewLoading = false;
  Map<String, dynamic>? _preview;

  final _personalOptions = const [
    'Study 1 hour',
    'Workout 30 min',
    'Journal',
    'Read 30 pages',
    'Deep work 2 hours',
    'No phone before bed',
  ];
  final Set<String> _selectedPersonal = {};

  bool get _isFreedom => (_preview?['task_mode'] as String?) == 'freedom';

  String _friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map && detail['message'] is String) {
          return detail['message'] as String;
        }
        if (detail is String) return detail;
      }
      if (e.response?.statusCode == 404) return 'Invite code not found.';
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach the server. Is the backend running?';
      }
    }
    return e.toString();
  }

  void _addCustomPersonal() {
    final text = _customPersonal.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedPersonal.add(text);
      _customPersonal.clear();
    });
  }

  Future<void> _lookup() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _previewLoading = true;
      _preview = null;
      _selectedPersonal.clear();
    });
    try {
      final preview = await ref.read(apiRepositoryProvider).previewGroupInvite(code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e)), backgroundColor: AppColors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (_preview == null) {
      await _lookup();
      return;
    }

    if (_isFreedom && _selectedPersonal.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least 2 personal tasks for this group')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join group challenge?'),
        content: Text(
          _isFreedom
              ? 'You will get the group foundation tasks plus your personal tasks. '
                  'Your individual challenge can keep running alongside this group.'
              : 'Your individual challenge can keep running alongside this group '
                  '(one personal + one group at a time).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final group = await ref.read(apiRepositoryProvider).joinGroup(
            code,
            personalTasks: _isFreedom ? _selectedPersonal.toList() : null,
          );
      ref.invalidate(groupsProvider);
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(activeProgramsProvider);
      if (!mounted) return;
      context.pushReplacement('/groups/${group.id}/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: AppColors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = (_preview?['foundation_tasks'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Invite Code'),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (_preview != null) setState(() => _preview = null);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _previewLoading ? null : _lookup,
              child: _previewLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Look up group'),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 20),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _preview!['name'] as String? ?? 'Group',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_preview!['duration_days']} days · '
                      '${_isFreedom ? 'Add your own tasks' : 'Same tasks for all'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (foundation.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Foundation tasks', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...foundation.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $t'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isFreedom) ...[
                const SizedBox(height: 20),
                Text(
                  'Your personal tasks (${_selectedPersonal.length}/2+)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _personalOptions.map((task) {
                    final selected = _selectedPersonal.contains(task);
                    return FilterChip(
                      label: Text(task),
                      selected: selected,
                      selectedColor: AppColors.teal.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.teal,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedPersonal.add(task);
                          } else {
                            _selectedPersonal.remove(task);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customPersonal,
                        decoration: const InputDecoration(hintText: 'Custom personal task'),
                        onSubmitted: (_) => _addCustomPersonal(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addCustomPersonal,
                    ),
                  ],
                ),
                if (_selectedPersonal.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._selectedPersonal.map(
                    (t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(t),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedPersonal.remove(t)),
                      ),
                    ),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: _preview == null ? 'Continue' : 'Join Group',
              onPressed: _join,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _customPersonal.dispose();
    super.dispose();
  }
}

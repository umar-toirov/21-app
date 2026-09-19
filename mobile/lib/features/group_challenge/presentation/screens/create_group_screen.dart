import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final _customPersonal = TextEditingController();
  int _duration = 21;
  int _maxMissed = 3;
  bool _loading = false;
  String _taskMode = 'shared';

  final _foundationOptions = const [
    'Wake up before 7',
    'Daily planning',
    'Evening reflection',
    'Read 20 minutes',
    'Exercise 30 minutes',
  ];
  final Set<String> _selectedFoundation = {
    'Wake up before 7',
    'Daily planning',
    'Evening reflection',
  };

  final _personalOptions = const [
    'Study 1 hour',
    'Workout 30 min',
    'Journal',
    'Read 30 pages',
    'Deep work 2 hours',
    'No phone before bed',
  ];
  final Set<String> _selectedPersonal = {};

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
      if (e.response?.statusCode == 409) {
        return 'Finish or leave your current challenge before starting a group.';
      }
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

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    if (_selectedFoundation.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least 2 foundation tasks')),
      );
      return;
    }
    if (_taskMode == 'freedom' && _selectedPersonal.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 of your personal tasks')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start group challenge?'),
        content: const Text(
          'Your personal challenge can keep running. Starting this group creates a '
          'separate group program (one group challenge at a time).',
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
      final group = await ref.read(apiRepositoryProvider).createGroup({
        'name': _name.text.trim(),
        'duration_days': _duration,
        'max_missed_days': _maxMissed,
        'starts_at': DateTime.now().toIso8601String().split('T').first,
        'foundation_tasks': _selectedFoundation.toList(),
        'task_mode': _taskMode,
        if (_taskMode == 'freedom') 'personal_tasks': _selectedPersonal.toList(),
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Group Name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: const [
                DropdownMenuItem(value: 21, child: Text('21 Days')),
                DropdownMenuItem(value: 30, child: Text('30 Days')),
              ],
              onChanged: (v) => setState(() => _duration = v ?? 21),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _maxMissed,
              decoration: const InputDecoration(labelText: 'Max Missed Days (penalty)'),
              items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
              onChanged: (v) => setState(() => _maxMissed = v ?? 3),
            ),
            const SizedBox(height: 20),
            const Text('Task mode', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'shared', label: Text('Same for all')),
                ButtonSegment(value: 'freedom', label: Text('Add own tasks')),
              ],
              selected: {_taskMode},
              onSelectionChanged: (s) => setState(() => _taskMode = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _taskMode == 'shared'
                  ? 'Everyone uses the foundation tasks you pick below.'
                  : 'Everyone gets your foundation tasks, plus their own personal tasks.',
              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Foundation tasks (shared with the group)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foundationOptions.map((task) {
                final selected = _selectedFoundation.contains(task);
                return FilterChip(
                  label: Text(task),
                  selected: selected,
                  selectedColor: AppColors.orange.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.orange,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedFoundation.add(task);
                      } else {
                        _selectedFoundation.remove(task);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_taskMode == 'freedom') ...[
              const SizedBox(height: 24),
              Text(
                'Your personal tasks (${_selectedPersonal.length}/2+)',
                style: const TextStyle(fontWeight: FontWeight.w800),
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
            const SizedBox(height: 28),
            PrimaryButton(label: 'Create Group', onPressed: _create, isLoading: _loading),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _customPersonal.dispose();
    super.dispose();
  }
}

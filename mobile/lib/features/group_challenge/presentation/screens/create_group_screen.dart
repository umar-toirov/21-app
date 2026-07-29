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
  int _duration = 21;
  int _maxMissed = 3;
  bool _loading = false;

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

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    if (_selectedFoundation.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least 2 foundation tasks')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start group challenge?'),
        content: const Text(
          'If you already have an active personal challenge, it will be archived '
          'so this group challenge can start (one challenge at a time).',
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
      });
      ref.invalidate(groupsProvider);
      ref.invalidate(activeChallengeProvider);
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
            const Text('Foundation tasks (leader picks, cannot be removed)', style: TextStyle(fontWeight: FontWeight.w800)),
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
    super.dispose();
  }
}

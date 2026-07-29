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
  bool _loading = false;

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

  Future<void> _join() async {
    if (_code.text.trim().isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join group challenge?'),
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
      final group = await ref.read(apiRepositoryProvider).joinGroup(_code.text.trim().toUpperCase());
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
      appBar: AppBar(title: const Text('Join Group')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Invite Code'),
              textCapitalization: TextCapitalization.characters,
            ),
            const Spacer(),
            PrimaryButton(label: 'Join Group', onPressed: _join, isLoading: _loading),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/task_list_editor.dart';
import '../../../../core/router/app_router.dart';
import 'create_group_screen.dart' show groupTaskSuggestions;
import 'group_home_screen.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName(Map<String, dynamic> group) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiRepositoryProvider).updateGroup(widget.groupId, {
        'name': _nameCtrl.text.trim(),
      });
      ref.invalidate(groupDashboardProvider(widget.groupId));
      ref.invalidate(groupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _tasksBusy = false;

  Future<void> _changeTasks(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _tasksBusy = true);
    try {
      await action();
      ref.invalidate(groupTasksProvider(widget.groupId));
      ref.invalidate(activeProgramsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _tasksBusy = false);
    }
  }

  Future<void> _endGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this group?'),
        content: const Text(
          'The group challenge ends for everyone and the group stops appearing in rankings. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End group', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiRepositoryProvider).endGroup(widget.groupId);
      ref.invalidate(groupsProvider);
      ref.invalidate(activeProgramsProvider);
      ref.invalidate(activeChallengeProvider);
      if (mounted) context.go('${AppRoutes.home}/groups');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _removeMember(String memberId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove $name from this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiRepositoryProvider).removeGroupMember(widget.groupId, memberId);
      ref.invalidate(groupDashboardProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name removed')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final group = extra?['group'] as Map<String, dynamic>? ?? {};
    final members = extra?['members'] as List<dynamic>? ?? [];
    final invite = group['invite_code'] as String? ?? '';

    if (_nameCtrl.text.isEmpty && group['name'] != null) {
      _nameCtrl.text = group['name'] as String;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Group Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Group Name', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'ILM MODE S5'),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Save changes',
            isLoading: _saving,
            onPressed: () => _saveName(group),
          ),
          const SizedBox(height: 28),
          const Text('Tasks for everyone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Anything you add or remove here changes every member\'s day right away.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ref.watch(groupTasksProvider(widget.groupId)).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
                ),
                error: (e, _) => Text(apiErrorMessage(e)),
                data: (data) => TaskListEditor(
                  tasks: List<String>.from(data['tasks'] as List),
                  max: 15,
                  busy: _tasksBusy,
                  suggestions: groupTaskSuggestions,
                  hint: 'Add a task for everyone',
                  emptyText: 'No shared tasks. Members choose their own.',
                  onAdd: (t) => _changeTasks(
                    () => ref.read(apiRepositoryProvider).addGroupTask(widget.groupId, t),
                  ),
                  onRemove: (t) => _changeTasks(
                    () => ref.read(apiRepositoryProvider).removeGroupTask(widget.groupId, t),
                  ),
                ),
              ),
          const SizedBox(height: 28),
          const Text('Invite Members', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              children: [
                QrImageView(data: 'ilmmode://join/$invite', size: 140),
                const SizedBox(height: 12),
                Text(
                  invite,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: 3, color: AppColors.navy),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Copy invite code',
                  outlined: true,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: invite));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text('Participants', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ...members.map((m) {
            final map = m as Map<String, dynamic>;
            final isLeader = map['role'] == 'leader';
            final isYou = map['is_you'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Text((map['full_name'] as String? ?? '?').substring(0, 1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${map['full_name']}${isYou ? ' (you)' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (isLeader)
                            const Text('Leader', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!isLeader && !isYou)
                      IconButton(
                        icon: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                        onPressed: () => _removeMember(
                          map['user_id'] as String,
                          map['full_name'] as String? ?? 'Member',
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _endGroup,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End group'),
          ),
        ],
      ),
    );
  }
}

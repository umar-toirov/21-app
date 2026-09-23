import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/models/models.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/how_it_works.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/ranking_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../widgets/group_chat.dart';
import '../widgets/group_widgets.dart';

final groupDashboardProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, groupId) {
  return ref.watch(apiRepositoryProvider).getGroupDashboard(groupId);
});

final groupStatisticsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, groupId) {
  return ref.watch(apiRepositoryProvider).getGroupStatistics(groupId);
});

final groupDayRosterProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String groupId, String date})>((ref, args) {
  return ref.watch(apiRepositoryProvider).getGroupDayRoster(
        args.groupId,
        date: args.date,
      );
});

class GroupHomeScreen extends ConsumerStatefulWidget {
  const GroupHomeScreen({super.key, required this.groupId, this.initialTab = 0});

  final String groupId;

  /// 0 Today, 1 Ranking, 2 Chat, 3 Stats.
  final int initialTab;

  @override
  ConsumerState<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends ConsumerState<GroupHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    final text = '$e';
    if (text.contains('403')) return 'You do not have access to this group.';
    if (text.contains('404')) return 'This group was not found.';
    return apiErrorMessage(e);
  }

  void _openMember(String userId) {
    context.push('/groups/${widget.groupId}/members/$userId');
  }

  void _showInviteSheet(Map<String, dynamic> group) {
    final code = group['invite_code'] as String? ?? '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invite to group', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(data: 'ilmmode://join/$code', size: 160),
              ),
              const SizedBox(height: 16),
              Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: 5,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share this code. People join from Groups → Join.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Copy invite code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Copied!')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _postAnnouncement(bool isLeader) async {
    if (!isLeader) return;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var pinned = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Post announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                CheckboxListTile(
                  value: pinned,
                  onChanged: (v) => setLocal(() => pinned = v ?? false),
                  title: const Text('Pin to top'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
          ],
        ),
      ),
    );

    final body = bodyCtrl.text.trim();
    final title = titleCtrl.text.trim();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    if (ok != true || body.isEmpty) return;

    try {
      await ref.read(apiRepositoryProvider).postGroupAnnouncement(
            widget.groupId,
            body: body,
            title: title.isEmpty ? null : title,
            isPinned: pinned,
          );
      ref.invalidate(groupDashboardProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement posted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text(
          'Your group challenge will end and you will lose your place in the ranking. '
          'You can join again later with the invite code.',
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
      await ref.read(apiRepositoryProvider).leaveGroup(widget.groupId);
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

  Future<void> _openTasks() async {
    final programs = await ref.read(activeProgramsProvider.future);
    if (!mounted) return;
    final group = programs.group;
    if (group != null) {
      context.push('/home/challenge/${group.id}');
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(groupDashboardProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const GroupLoadingState(),
          error: (e, _) => GroupErrorState(
            message: _friendlyError(e),
            onRetry: () => ref.invalidate(groupDashboardProvider(widget.groupId)),
          ),
          data: (data) {
            final group = data['group'] as Map<String, dynamic>;
            final members = data['members'] as List<dynamic>? ?? [];
            final announcements = data['announcements'] as List<dynamic>? ?? [];
            final feed = data['feed'] as List<dynamic>? ?? [];
            final sessions = data['sessions'] as List<dynamic>? ?? [];
            final isLeader = group['is_leader'] == true;

            return Column(
              children: [
                _GroupHeader(
                  group: group,
                  isLeader: isLeader,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('${AppRoutes.home}/groups'),
                  onInvite: () => _showInviteSheet(group),
                  onSettings: () => context.push(
                    '/groups/${widget.groupId}/settings',
                    extra: {'group': group, 'members': members},
                  ),
                  onLeave: _leave,
                  onHelp: () => showHowItWorks(context),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.orange,
                  indicatorWeight: 3,
                  dividerColor: AppColors.border,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Today'),
                    Tab(text: 'Ranking'),
                    Tab(text: 'Chat'),
                    Tab(text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _TodayTab(
                        groupId: widget.groupId,
                        group: group,
                        members: members,
                        announcements: announcements,
                        feed: feed,
                        sessions: sessions,
                        isLeader: isLeader,
                        onOpenTasks: _openTasks,
                        onPostAnnouncement: () => _postAnnouncement(isLeader),
                        onRefresh: () async {
                          ref.invalidate(groupDashboardProvider(widget.groupId));
                          ref.invalidate(activeProgramsProvider);
                        },
                        onTapMember: _openMember,
                      ),
                      _RankingTab(
                        members: members,
                        onTapMember: _openMember,
                        onRefresh: () async => ref.invalidate(groupDashboardProvider(widget.groupId)),
                      ),
                      GroupChatTab(groupId: widget.groupId, isLeader: isLeader),
                      _StatisticsTab(groupId: widget.groupId),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.isLeader,
    required this.onBack,
    required this.onInvite,
    required this.onSettings,
    required this.onLeave,
    required this.onHelp,
  });

  final Map<String, dynamic> group;
  final bool isLeader;
  final VoidCallback onBack;
  final VoidCallback onInvite;
  final VoidCallback onSettings;
  final VoidCallback onLeave;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final day = group['current_day'] as int? ?? 1;
    final total = group['duration_days'] as int? ?? 21;
    final members = group['member_count'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'] as String? ?? 'Group',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Day $day of $total · $members member${members == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Invite',
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'settings':
                  onSettings();
                case 'leave':
                  onLeave();
                case 'help':
                  onHelp();
              }
            },
            itemBuilder: (_) => [
              if (isLeader)
                const PopupMenuItem(value: 'settings', child: Text('Group settings')),
              const PopupMenuItem(value: 'help', child: Text('How it works')),
              if (!isLeader)
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave group', style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab({
    required this.groupId,
    required this.group,
    required this.members,
    required this.announcements,
    required this.feed,
    required this.sessions,
    required this.isLeader,
    required this.onOpenTasks,
    required this.onPostAnnouncement,
    required this.onRefresh,
    required this.onTapMember,
  });

  final String groupId;
  final Map<String, dynamic> group;
  final List<dynamic> members;
  final List<dynamic> announcements;
  final List<dynamic> feed;
  final List<dynamic> sessions;
  final bool isLeader;
  final VoidCallback onOpenTasks;
  final VoidCallback onPostAnnouncement;
  final Future<void> Function() onRefresh;
  final void Function(String userId) onTapMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = members.cast<Map<String, dynamic>>().where((m) => m['is_you'] == true).firstOrNull;
    final doneCount = members.where((m) => (m as Map)['today_complete'] == true).length;
    final program = ref.watch(activeProgramsProvider).valueOrNull?.group;
    final starts = DateTime.tryParse(group['starts_at'] as String? ?? '');
    final notStarted = starts != null && starts.isAfter(DateTime.now());

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (notStarted)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, color: AppColors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This group starts on ${DateFormat('EEE, MMM d').format(starts)}.',
                      style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          _MyDayCard(me: me, program: program, onOpenTasks: onOpenTasks),
          const SizedBox(height: 20),
          _DoneToday(members: members, doneCount: doneCount, onTap: onTapMember),
          if (isLeader) ...[
            const SizedBox(height: 22),
            _LeaderDayRosterSectionHost(groupId: groupId, onTapMember: onTapMember),
          ],
          if (announcements.isNotEmpty || isLeader) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (isLeader)
                  TextButton.icon(
                    onPressed: onPostAnnouncement,
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Post'),
                  ),
              ],
            ),
            if (announcements.isEmpty)
              Text(
                'Share news or reminders with everyone in the group.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
              )
            else
              _AnnouncementList(announcements: announcements),
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 22),
            LiveSessionCard(sessions: sessions),
          ],
          if (feed.isNotEmpty) ...[
            const SizedBox(height: 22),
            GroupActivityFeed(feed: feed.take(8).toList()),
          ],
        ],
      ),
    );
  }
}

/// Holds the roster date so the leader can browse days.
class _LeaderDayRosterSectionHost extends StatefulWidget {
  const _LeaderDayRosterSectionHost({required this.groupId, required this.onTapMember});

  final String groupId;
  final void Function(String userId) onTapMember;

  @override
  State<_LeaderDayRosterSectionHost> createState() => _LeaderDayRosterSectionHostState();
}

class _LeaderDayRosterSectionHostState extends State<_LeaderDayRosterSectionHost> {
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LeaderDayRosterSection(
      groupId: widget.groupId,
      date: _date,
      onSelectDate: (d) => setState(() => _date = d),
      onPickDate: _pick,
      onTapMember: widget.onTapMember,
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.announcements});

  final List<dynamic> announcements;

  @override
  Widget build(BuildContext context) {
    final items = announcements.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (b['is_pinned'] == true ? 1 : 0) - (a['is_pinned'] == true ? 1 : 0));
    return Column(
      children: [
        for (final a in items.take(3))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: a['is_pinned'] == true
                    ? AppColors.orange.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a['is_pinned'] == true ? Icons.push_pin_rounded : Icons.campaign_rounded,
                  size: 20,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((a['title'] as String?)?.isNotEmpty == true)
                        Text(
                          a['title'] as String,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      Text(
                        a['body'] as String? ?? '',
                        style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MyDayCard extends StatelessWidget {
  const _MyDayCard({required this.me, required this.program, required this.onOpenTasks});

  final Map<String, dynamic>? me;
  final ChallengeModel? program;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final total = program?.tasks.length ?? 0;
    final done = program?.tasks.where((t) => t.isCompleted).length ?? 0;
    final all = total > 0 && done == total;
    final rank = me?['rank'];
    final points = me?['group_points'] ?? 0;
    final streak = me?['current_streak'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (total > 0)
                AnimatedRing(
                  progress: done / total,
                  size: 60,
                  stroke: 7,
                  color: all ? AppColors.success : AppColors.orange,
                  child: Text(
                    '$done/$total',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.orangeSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.checklist_rounded, color: AppColors.orange),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? "Today's tasks"
                          : (all ? 'All done for today' : '${total - done} task${total - done == 1 ? '' : 's'} left'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      all ? 'Great work. See you tomorrow.' : 'Finish them to earn points for the group.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: 'Rank', value: rank == null ? '–' : '#$rank', color: AppColors.orange),
              _Stat(label: 'Points', value: '$points', color: AppColors.textPrimary),
              _Stat(label: 'Streak', value: '$streak', color: AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: all ? 'Review today' : "Open today's tasks",
              onPressed: onOpenTasks,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _DoneToday extends StatelessWidget {
  const _DoneToday({required this.members, required this.doneCount, required this.onTap});

  final List<dynamic> members;
  final int doneCount;
  final void Function(String userId) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$doneCount of ${members.length} finished today',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final m = members[i] as Map<String, dynamic>;
              final done = m['today_complete'] == true;
              final name = (m['full_name'] as String? ?? '?');
              final first = name.split(' ').first;
              return GestureDetector(
                onTap: () => onTap(m['user_id'] as String),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? AppColors.teal.withValues(alpha: 0.16)
                                  : AppColors.border,
                              border: Border.all(
                                color: done ? AppColors.teal : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (done)
                            const Positioned(
                              right: -2,
                              bottom: -2,
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: AppColors.teal,
                                child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['is_you'] == true ? 'You' : first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RankingTab extends StatelessWidget {
  const _RankingTab({
    required this.members,
    required this.onTapMember,
    required this.onRefresh,
  });

  final List<dynamic> members;
  final void Function(String userId) onTapMember;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final raw in members)
        () {
          final m = raw as Map<String, dynamic>;
          final streak = m['current_streak'] ?? 0;
          return RankEntry(
            rank: m['rank'] as int? ?? 0,
            name: m['full_name'] as String? ?? 'Member',
            value: m['group_points'] as int? ?? 0,
            isYou: m['is_you'] == true,
            subtitle: '$streak day streak${m['today_complete'] == true ? ' · done today' : ''}',
            onTap: () => onTapMember(m['user_id'] as String),
          );
        }(),
    ];
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ranked by the points each member earned in this group.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                tooltip: 'How points work',
                onPressed: () => showPointsInfo(context),
                icon: Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RankList(entries: entries, emptyText: 'No members yet.'),
        ],
      ),
    );
  }
}

class _LeaderDayRosterSection extends ConsumerWidget {
  const _LeaderDayRosterSection({
    required this.groupId,
    required this.date,
    required this.onSelectDate,
    required this.onPickDate,
    required this.onTapMember,
  });

  final String groupId;
  final DateTime date;
  final void Function(DateTime date) onSelectDate;
  final VoidCallback onPickDate;
  final void Function(String userId) onTapMember;

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateKey = _ymd(date);
    final async = ref.watch(groupDayRosterProvider((groupId: groupId, date: dateKey)));

    return async.when(
      loading: () => const SoftCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
        ),
      ),
      error: (e, _) => SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Member actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Could not load roster: $e',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => ref.invalidate(groupDayRosterProvider((groupId: groupId, date: dateKey))),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (roster) => GroupMemberActionsRoster(
        roster: roster,
        selectedDate: date,
        onSelectDate: onSelectDate,
        onPickDate: onPickDate,
        onTapMember: onTapMember,
      ),
    );
  }
}

class _StatisticsTab extends ConsumerWidget {
  const _StatisticsTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(groupStatisticsProvider(groupId));

    return statsAsync.when(
      loading: () => const GroupLoadingState(),
      error: (e, _) => GroupErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(groupStatisticsProvider(groupId)),
      ),
      data: (stats) {
        final trend = stats['weekly_trend'] as List<dynamic>? ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text('Group Statistics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatHighlight(
                    label: 'Completion',
                    value: '${(stats['completion_percent'] as num?)?.toStringAsFixed(0) ?? 0}%',
                    icon: Icons.pie_chart_rounded,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatHighlight(
                    label: 'Avg Points',
                    value: '${stats['average_group_points'] ?? 0}',
                    icon: Icons.bolt_rounded,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatHighlight(
                    label: 'Active Today',
                    value: '${stats['daily_active'] ?? 0}',
                    icon: Icons.people_rounded,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatHighlight(
                    label: 'Longest Streak',
                    value: '${stats['longest_streak'] ?? 0}',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.goldDepth,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Trend', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: trend.map((t) {
                        final map = t as Map<String, dynamic>;
                        final val = ((map['value'] as num?) ?? 0) / 100;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                AnimatedFillBar(
                                  value: val.clamp(0.0, 1.0),
                                  height: 80 * val.clamp(0.05, 1.0),
                                  color: AppColors.orange,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (stats['top_performer'] != null)
              _PersonHighlight(
                title: 'Top Performer',
                name: (stats['top_performer'] as Map)['name'] as String? ?? '',
                detail: '${(stats['top_performer'] as Map)['score'] ?? 0} pts',
                icon: Icons.emoji_events_rounded,
                color: AppColors.gold,
              ),
            if (stats['most_consistent'] != null) ...[
              const SizedBox(height: 10),
              _PersonHighlight(
                title: 'Most Consistent',
                name: (stats['most_consistent'] as Map)['name'] as String? ?? '',
                detail: '${(stats['most_consistent'] as Map)['perfect_days']} perfect days',
                icon: Icons.verified_rounded,
                color: AppColors.teal,
              ),
            ],
            if (stats['most_improved'] != null) ...[
              const SizedBox(height: 10),
              _PersonHighlight(
                title: 'Most Improved',
                name: (stats['most_improved'] as Map)['name'] as String? ?? '',
                detail: '${(stats['most_improved'] as Map)['streak']} day streak',
                icon: Icons.trending_up_rounded,
                color: AppColors.orange,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatHighlight extends StatelessWidget {
  const _StatHighlight({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlossyIcon(icon: icon, size: 32, color: color),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PersonHighlight extends StatelessWidget {
  const _PersonHighlight({
    required this.title,
    required this.name,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String name;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GlossyIcon(icon: icon, size: 40, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(detail, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

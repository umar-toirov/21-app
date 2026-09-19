import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';
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
  const GroupHomeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends ConsumerState<GroupHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    final text = '$e';
    if (text.contains('403')) {
      return 'You do not have access to this group.';
    }
    if (text.contains('404')) {
      return 'This group was not found.';
    }
    if (text.contains('SocketException') || text.contains('connection')) {
      return 'Cannot reach the server. Make sure the backend is running.';
    }
    return text;
  }

  void _openMember(String userId) {
    context.push('/groups/${widget.groupId}/members/$userId');
  }

  void _showInviteSheet(Map<String, dynamic> group) {
    final code = group['invite_code'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invite to Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(height: 16),
            QrImageView(data: 'ilmmode://join/$code', size: 160),
            const SizedBox(height: 16),
            Text(
              code,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: 4, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Share code or QR with participants',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
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

    if (ok != true || bodyCtrl.text.trim().isEmpty) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }

    try {
      await ref.read(apiRepositoryProvider).postGroupAnnouncement(
            widget.groupId,
            body: bodyCtrl.text.trim(),
            title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
            isPinned: pinned,
          );
      ref.invalidate(groupDashboardProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement posted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(groupDashboardProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashboardAsync.when(
        loading: () => const GroupLoadingState(),
        error: (e, _) => GroupErrorState(
          message: _friendlyError(e),
          onRetry: () => ref.invalidate(groupDashboardProvider(widget.groupId)),
        ),
        data: (data) {
          final group = data['group'] as Map<String, dynamic>;
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final members = data['members'] as List<dynamic>? ?? [];
          final announcements = data['announcements'] as List<dynamic>? ?? [];
          final feed = data['feed'] as List<dynamic>? ?? [];
          final sessions = data['sessions'] as List<dynamic>? ?? [];
          final isLeader = group['is_leader'] == true;

          return NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppColors.background,
                title: Text(
                  group['name'] as String? ?? 'Group',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: () => _showInviteSheet(group),
                  ),
                  if (isLeader)
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () => context.push(
                        '/groups/${widget.groupId}/settings',
                        extra: {'group': group, 'members': members},
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Home'),
                        Tab(text: 'Leaderboard'),
                        Tab(text: 'Statistics'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _HomeTab(
                  groupId: widget.groupId,
                  group: group,
                  stats: stats,
                  announcements: announcements,
                  feed: feed,
                  sessions: sessions,
                  isLeader: isLeader,
                  onCta: () async {
                    final programs = await ref.read(activeProgramsProvider.future);
                    if (!context.mounted) return;
                    final groupChallenge = programs.group;
                    if (groupChallenge != null) {
                      context.go('/home/challenge/${groupChallenge.id}');
                    } else {
                      context.go(AppRoutes.home);
                    }
                  },
                  onPostAnnouncement: () => _postAnnouncement(isLeader),
                  onRefresh: () async => ref.invalidate(groupDashboardProvider(widget.groupId)),
                  onTapMember: _openMember,
                ),
                _LeaderboardTab(
                  members: members,
                  onTapMember: _openMember,
                  onRefresh: () async => ref.invalidate(groupDashboardProvider(widget.groupId)),
                ),
                _StatisticsTab(groupId: widget.groupId),
              ],
            ),
          );
        },
      ),
      floatingActionButton: dashboardAsync.maybeWhen(
        data: (data) {
          final isLeader = (data['group'] as Map)['is_leader'] == true;
          if (!isLeader) return null;
          return FloatingActionButton.extended(
            backgroundColor: AppColors.orange,
            onPressed: () => _postAnnouncement(true),
            icon: const Icon(Icons.campaign_rounded, color: Colors.white),
            label: const Text('Announce', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.groupId,
    required this.group,
    required this.stats,
    required this.announcements,
    required this.feed,
    required this.sessions,
    required this.isLeader,
    required this.onCta,
    required this.onPostAnnouncement,
    required this.onRefresh,
    required this.onTapMember,
  });

  final String groupId;
  final Map<String, dynamic> group;
  final Map<String, dynamic> stats;
  final List<dynamic> announcements;
  final List<dynamic> feed;
  final List<dynamic> sessions;
  final bool isLeader;
  final VoidCallback onCta;
  final VoidCallback onPostAnnouncement;
  final Future<void> Function() onRefresh;
  final void Function(String userId) onTapMember;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late DateTime _rosterDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rosterDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final startsAt = DateTime.tryParse(widget.group['starts_at'] as String? ?? '');
    final duration = widget.group['duration_days'] as int? ?? 21;
    final first = startsAt ?? DateTime.now().subtract(const Duration(days: 30));
    final last = first.add(Duration(days: duration - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _rosterDate,
      firstDate: first,
      lastDate: last.isAfter(DateTime.now()) ? DateTime.now() : last,
    );
    if (picked != null) {
      setState(() => _rosterDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayPct = (widget.stats['today_completion_percent'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          GroupHeroCard(
            name: widget.group['name'] as String? ?? 'Group',
            currentDay: widget.group['current_day'] as int? ?? 1,
            durationDays: widget.group['duration_days'] as int? ?? 21,
            memberCount: widget.group['member_count'] as int? ?? 0,
            todayCompletionPercent: todayPct,
            onCta: widget.onCta,
          ),
          const SizedBox(height: 24),
          GroupStatGrid(stats: widget.stats),
          const SizedBox(height: 24),
          GroupProgressCard(percent: todayPct, stats: widget.stats),
          if (widget.isLeader) ...[
            const SizedBox(height: 24),
            _LeaderDayRosterSection(
              groupId: widget.groupId,
              date: _rosterDate,
              onSelectDate: (d) => setState(() => _rosterDate = d),
              onPickDate: _pickDate,
              onTapMember: widget.onTapMember,
            ),
          ],
          const SizedBox(height: 24),
          LiveSessionCard(sessions: widget.sessions),
          if (widget.sessions.isNotEmpty) const SizedBox(height: 24),
          PinnedAnnouncements(announcements: widget.announcements),
          if (widget.announcements.any((a) => a['is_pinned'] == true)) const SizedBox(height: 20),
          GroupActivityFeed(feed: widget.feed),
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

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({
    required this.members,
    required this.onTapMember,
    required this.onRefresh,
  });

  final List<dynamic> members;
  final void Function(String userId) onTapMember;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Team Leaderboard',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Ranked by group points from this program’s tasks',
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          GroupPodium(
            members: members,
            onTap: onTapMember,
          ),
          const SizedBox(height: 16),
          ...members.map((m) => GroupLeaderboardTile(
                member: m as Map<String, dynamic>,
                onTap: () => onTapMember(m['user_id'] as String),
              )),
        ],
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

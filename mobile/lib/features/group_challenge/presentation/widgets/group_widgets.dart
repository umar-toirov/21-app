import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

/// Premium group UI building blocks — ILM HUB accountability platform.
class GroupHeroCard extends StatelessWidget {
  const GroupHeroCard({
    super.key,
    required this.name,
    required this.currentDay,
    required this.durationDays,
    required this.memberCount,
    required this.todayCompletionPercent,
    this.onCta,
  });

  final String name;
  final int currentDay;
  final int durationDays;
  final int memberCount;
  final double todayCompletionPercent;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final progress = (todayCompletionPercent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                Icons.terrain_rounded,
                size: 160,
                color: AppColors.orange.withValues(alpha: 0.8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const GlossyIcon(
                      icon: Icons.flag_rounded,
                      size: 44,
                      color: AppColors.orange,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$memberCount members',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Day $currentDay / $durationDays',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      "Today's completion",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${todayCompletionPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedFillBar(
                  value: progress,
                  height: 14,
                  color: AppColors.orange,
                  background: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 22),
                if (onCta != null)
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: "Complete Today's Mission",
                      onPressed: onCta,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0);
  }
}

class GroupStatGrid extends StatelessWidget {
  const GroupStatGrid({super.key, required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Participants', '${stats['participants'] ?? 0}',
          Icons.groups_rounded, AppColors.navy),
      _StatItem('Completed Today', '${stats['completed_today'] ?? 0}',
          Icons.check_circle_rounded, AppColors.teal),
      _StatItem(
          'Average Points',
          '${stats['average_group_points'] ?? stats['average_hp'] ?? 0}',
          Icons.bolt_rounded,
          AppColors.orange),
      _StatItem('Your Rank', '#${stats['your_rank'] ?? '-'}',
          Icons.emoji_events_rounded, AppColors.goldDepth),
      _StatItem('Perfect Days', '${stats['perfect_days'] ?? 0}',
          Icons.star_rounded, AppColors.gold),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Group Status",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: (MediaQuery.sizeOf(context).width - 50) / 2,
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlossyIcon(icon: item.icon, size: 36, color: item.color),
                    const SizedBox(height: 12),
                    Text(
                      item.value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (items.indexOf(item) * 60).ms),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class GroupProgressCard extends StatelessWidget {
  const GroupProgressCard(
      {super.key, required this.percent, required this.stats});

  final double percent;
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final bonus = stats['bonus_hp_unlocked'] == true;
    final badge = stats['group_badge_unlocked'] == true;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GlossyIcon(
                  icon: Icons.rocket_launch_rounded,
                  size: 40,
                  color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Group Progress',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      '${percent.toStringAsFixed(0)}% completed today',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedFillBar(value: percent / 100, height: 12),
          const SizedBox(height: 14),
          if (bonus)
            const _RewardChip(
              icon: Icons.bolt_rounded,
              label: '95% reached — Bonus Points for everyone!',
              color: AppColors.orange,
            ),
          if (badge) ...[
            const SizedBox(height: 8),
            const _RewardChip(
              icon: Icons.military_tech_rounded,
              label: '100% — Group Badge unlocked!',
              color: AppColors.goldDepth,
            ),
          ],
          if (!bonus && !badge) ...[
            const SizedBox(height: 4),
            Text(
              'Reach 95% for bonus Points · 100% unlocks a group badge',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack);
  }
}

class PinnedAnnouncements extends StatelessWidget {
  const PinnedAnnouncements({super.key, required this.announcements});

  final List<dynamic> announcements;

  @override
  Widget build(BuildContext context) {
    final pinned = announcements.where((a) => a['is_pinned'] == true).toList();
    if (pinned.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pinned',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        ...pinned.map((a) {
          final map = a as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.push_pin_rounded,
                          size: 16, color: AppColors.goldDepth),
                      const SizedBox(width: 6),
                      Text(
                        map['title'] as String? ?? 'Announcement',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    map['body'] as String? ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class GroupActivityFeed extends StatelessWidget {
  const GroupActivityFeed({super.key, required this.feed});

  final List<dynamic> feed;

  IconData _iconFor(String type) {
    switch (type) {
      case 'task_complete':
        return Icons.check_circle_outline_rounded;
      case 'streak_milestone':
        return Icons.local_fire_department_rounded;
      case 'rank_change':
        return Icons.trending_up_rounded;
      case 'recovery':
        return Icons.healing_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'member_joined':
        return Icons.person_add_alt_1_rounded;
      case 'certificate':
        return Icons.workspace_premium_rounded;
      case 'session':
        return Icons.videocam_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'task_complete':
        return AppColors.teal;
      case 'streak_milestone':
        return AppColors.orange;
      case 'recovery':
        return AppColors.goldDepth;
      case 'announcement':
        return AppColors.navy;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (feed.isEmpty) {
      return SoftCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Activity will appear here as your team completes missions.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Team Activity',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        ...feed.take(15).map((item) {
          final map = item as Map<String, dynamic>;
          final type = map['activity_type'] as String? ?? '';
          final created = map['created_at'];
          String timeLabel = '';
          if (created != null) {
            try {
              timeLabel = DateFormat.jm()
                  .format(DateTime.parse(created.toString()).toLocal());
            } catch (_) {}
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  GlossyIcon(
                      icon: _iconFor(type), size: 36, color: _colorFor(type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          map['message'] as String? ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class GroupPodium extends StatelessWidget {
  const GroupPodium({super.key, required this.members, this.onTap});

  final List<dynamic> members;
  final void Function(String userId)? onTap;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final top3 = members.take(3).toList();

    Widget podiumSlot(
        Map<String, dynamic> m, int place, double height, Color medal) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap != null ? () => onTap!(m['user_id'] as String) : null,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: place == 1 ? 36 : 30,
                    backgroundColor: medal.withValues(alpha: 0.2),
                    child: Text(
                      (m['full_name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: place == 1 ? 22 : 18,
                        color: medal,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -6,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration:
                          BoxDecoration(color: medal, shape: BoxShape.circle),
                      child: Text(
                        '#$place',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                m['full_name'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Text(
                '${m['group_points'] ?? m['hp'] ?? 0} pts',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: medal.withValues(alpha: 0.25),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final order = top3.length >= 3
        ? [top3[1], top3[0], top3[2]]
        : top3.length == 2
            ? [top3[1], top3[0]]
            : top3;

    final medals = [AppColors.muted, AppColors.gold, const Color(0xFFCD7F32)];
    final heights = [56.0, 80.0, 44.0];
    final places = top3.length >= 3
        ? [2, 1, 3]
        : top3.length == 2
            ? [2, 1]
            : [1];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(order.length, (i) {
          final m = order[i] as Map<String, dynamic>;
          final medal = medals[i.clamp(0, medals.length - 1)];
          return podiumSlot(
              m, places[i], heights[i.clamp(0, heights.length - 1)], medal);
        }),
      ),
    );
  }
}

class GroupLeaderboardTile extends StatelessWidget {
  const GroupLeaderboardTile({
    super.key,
    required this.member,
    this.onTap,
  });

  final Map<String, dynamic> member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rank = member['rank'] as int? ?? 0;
    final delta = member['rank_delta'] as int? ?? 0;
    final done = member['today_complete'] == true;
    final isYou = member['is_you'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: rank <= 3
                        ? AppColors.goldDepth
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                child: Text(
                  (member['full_name'] as String? ?? '?')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.teal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${member['full_name']}${isYou ? ' (you)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${member['group_points'] ?? 0} pts · '
                      'Streak ${member['current_streak']}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != 0)
                Icon(
                  delta > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: delta > 0 ? AppColors.teal : AppColors.danger,
                ),
              const SizedBox(width: 6),
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done ? AppColors.success : AppColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceHeatmap extends StatelessWidget {
  const AttendanceHeatmap({super.key, required this.days});

  final List<dynamic> days;

  Color _color(String status) {
    switch (status) {
      case 'complete':
        return AppColors.success;
      case 'recovery':
        return AppColors.orange;
      case 'missed':
        return AppColors.muted;
      case 'today':
        return AppColors.teal;
      default:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text('No attendance data yet.',
          style: TextStyle(color: AppColors.textSecondary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Attendance',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: days.map((d) {
            final map = d as Map<String, dynamic>;
            final status = map['status'] as String? ?? 'future';
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _color(status),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _legend(AppColors.success, 'Done'),
            const SizedBox(width: 12),
            _legend(AppColors.orange, 'Recovery'),
            const SizedBox(width: 12),
            _legend(AppColors.muted, 'Missed'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      ],
    );
  }
}

class LiveSessionCard extends StatelessWidget {
  const LiveSessionCard({super.key, required this.sessions});

  final List<dynamic> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final s = sessions.first as Map<String, dynamic>;
    final scheduled = DateTime.tryParse(s['scheduled_at']?.toString() ?? '');

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlossyIcon(
                  icon: Icons.videocam_rounded,
                  size: 40,
                  color: AppColors.navy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upcoming Session',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      s['title'] as String? ?? 'Live session',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (scheduled != null) ...[
            const SizedBox(height: 10),
            Text(
              DateFormat('EEE, MMM d · h:mm a').format(scheduled.toLocal()),
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            ),
          ],
          if (s['meeting_url'] != null) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Join Session',
              onPressed: () async {
                final uri = Uri.tryParse('${s['meeting_url']}');
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class GroupLoadingState extends StatelessWidget {
  const GroupLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.orange),
          SizedBox(height: 16),
          Text('Loading your team…',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class GroupErrorState extends StatelessWidget {
  const GroupErrorState(
      {super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlossyIcon(
                icon: Icons.cloud_off_rounded,
                size: 56,
                color: AppColors.muted),
            const SizedBox(height: 16),
            const Text('Could not load group',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Try again', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

/// Leader-only day roster: Today / Yesterday / pick date + per-member task status.
class GroupMemberActionsRoster extends StatelessWidget {
  const GroupMemberActionsRoster({
    super.key,
    required this.roster,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onPickDate,
    this.onTapMember,
  });

  final Map<String, dynamic> roster;
  final DateTime selectedDate;
  final void Function(DateTime date) onSelectDate;
  final VoidCallback onPickDate;
  final void Function(String userId)? onTapMember;

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = _ymd(DateTime(today.year, today.month, today.day));
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    final yesterdayKey = _ymd(yesterday);
    final selectedKey = _ymd(selectedDate);
    final members = (roster['members'] as List<dynamic>?) ?? [];
    final label = DateFormat('EEE, MMM d').format(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Member actions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: selectedKey == todayKey,
              selectedColor: AppColors.orange.withValues(alpha: 0.18),
              onSelected: (_) =>
                  onSelectDate(DateTime(today.year, today.month, today.day)),
            ),
            ChoiceChip(
              label: const Text('Yesterday'),
              selected: selectedKey == yesterdayKey,
              selectedColor: AppColors.orange.withValues(alpha: 0.18),
              onSelected: (_) => onSelectDate(yesterday),
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text('Pick date'),
              onPressed: onPickDate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (members.isEmpty)
          SoftCard(
            child: Text(
              'No members yet.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          )
        else
          ...members.map((raw) {
            final m = raw as Map<String, dynamic>;
            final tasks = (m['tasks'] as List<dynamic>?) ?? [];
            final done =
                tasks.where((t) => (t as Map)['completed'] == true).length;
            final dayComplete = m['day_complete'] == true;
            final userId = m['user_id'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: onTapMember != null && userId.isNotEmpty
                    ? () => onTapMember!(userId)
                    : null,
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.orange.withValues(alpha: 0.15),
                            child: Text(
                              ((m['full_name'] as String?) ?? '?').isNotEmpty
                                  ? (m['full_name'] as String)[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['full_name'] as String? ?? 'Member',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  tasks.isEmpty
                                      ? 'No tasks'
                                      : '$done/${tasks.length} tasks${dayComplete ? ' · day complete' : ''}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            dayComplete
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color:
                                dayComplete ? AppColors.teal : AppColors.muted,
                          ),
                        ],
                      ),
                      if (tasks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...tasks.map((rawTask) {
                          final t = rawTask as Map<String, dynamic>;
                          final completed = t['completed'] == true;
                          final type = t['type'] as String? ?? 'personal';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  completed
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 20,
                                  color: completed
                                      ? AppColors.teal
                                      : AppColors.muted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t['title'] as String? ?? 'Task',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: completed
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (type == 'foundation')
                                  const Text(
                                    'F',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gold,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
  }
}

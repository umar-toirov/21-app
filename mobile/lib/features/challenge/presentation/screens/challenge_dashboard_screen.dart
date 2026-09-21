import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/how_it_works.dart';
import '../../../../core/widgets/slow_loading_hint.dart';
import '../widgets/activity_calendar.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

bool _walkthroughQueued = false;

/// Missed-day notices already shown this session (they must not repeat).
final Set<String> _shownPenalties = {};

void _showPenaltyNotice(BuildContext context, ActiveProgramsModel programs) {
  for (final c in [programs.personal, programs.group]) {
    if (c == null || c.penaltyPoints <= 0) continue;
    final key = '${c.id}:${c.penaltyPoints}';
    if (!_shownPenalties.add(key)) continue;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.trending_down_rounded, color: AppColors.danger, size: 32),
        title: const Text('You missed a day'),
        content: Text(
          '-${c.penaltyPoints} points, and your streak was reset. '
          'Finish today\'s tasks to start earning again.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
    break; // one dialog at a time
  }
}

class ChallengeDashboardScreen extends ConsumerWidget {
  const ChallengeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(activeProgramsProvider);
    final profileAsync = ref.watch(profileProvider);

    if (!_walkthroughQueued && !howItWorksSeen && programsAsync.hasValue) {
      _walkthroughQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showHowItWorks(context);
      });
    }

    ref.listen<AsyncValue<ActiveProgramsModel>>(activeProgramsProvider, (prev, next) {
      final programs = next.valueOrNull;
      if (programs != null) _showPenaltyNotice(context, programs);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: programsAsync.when(
        loading: () => const SlowLoadingHint(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load your programs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString().contains('500')
                      ? 'Server error — tap retry. If it keeps failing, the backend may need a restart.'
                      : e.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Retry',
                  onPressed: () {
                    ref.invalidate(activeProgramsProvider);
                    ref.invalidate(activeChallengeProvider);
                    ref.invalidate(profileProvider);
                  },
                ),
              ],
            ),
          ),
        ),
        data: (programs) {
          if (programs.personal?.isRecovery == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go(AppRoutes.recovery);
            });
          }

          return profileAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.orange)),
            error: (e, _) => Center(child: Text('$e')),
            data: (profile) => _HomeContent(
              programs: programs,
              profile: profile,
              onRefresh: () {
                ref.invalidate(activeProgramsProvider);
                ref.invalidate(activeChallengeProvider);
                ref.invalidate(profileProvider);
                ref.invalidate(groupsProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.programs,
    required this.profile,
    required this.onRefresh,
  });

  final ActiveProgramsModel programs;
  final ProfileModel profile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final personal = programs.personal;
    final group = programs.group;
    final focus = (personal != null && !personal.dayComplete)
        ? personal
        : (group != null && !group.dayComplete)
            ? group
            : personal ?? group;
    final hasAny = personal != null || group != null;
    final showBothTaskStrips = personal != null && group != null;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                const AppWordmark(size: 26),
                const Spacer(),
                IconButton(
                  tooltip: 'How it works',
                  onPressed: () => showHowItWorks(context),
                  icon: const Icon(Icons.help_outline_rounded),
                ),
                IconButton(
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
                GestureDetector(
                  onTap: () => context.go('${AppRoutes.home}/profile'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                    child: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.12, end: 0),
            const SizedBox(height: 18),
            HomeGreetingHero(name: profile.fullName),
            const SizedBox(height: 20),
            Row(
              children: [
                StatTile3D(
                  icon: Icons.bolt_rounded,
                  label: 'Points',
                  value: '${profile.hp}',
                  color: AppColors.orange,
                  delay: 0.ms,
                ),
                StatTile3D(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak',
                  value: '${profile.currentStreak}',
                  color: AppColors.orangeDepth,
                  delay: 60.ms,
                ),
                StatTile3D(
                  icon: Icons.emoji_events_rounded,
                  label: 'Programs',
                  value:
                      '${(personal != null ? 1 : 0) + (group != null ? 1 : 0)}',
                  color: AppColors.teal,
                  delay: 120.ms,
                ),
              ],
            ),
            if (hasAny) ...[
              if (showBothTaskStrips) ...[
                const SizedBox(height: 22),
                _TodayTaskStrip(
                  label: "Personal · Today's tasks",
                  challenge: personal,
                  taskLimit: 2,
                ),
                const SizedBox(height: 14),
                _TodayTaskStrip(
                  label: "Group · Today's tasks",
                  challenge: group,
                  taskLimit: 2,
                ),
              ] else ...[
                const SizedBox(height: 22),
                _TodayTaskStrip(
                  label: focus!.isGroup
                      ? "Group · Today's tasks"
                      : "Personal · Today's tasks",
                  challenge: focus,
                  taskLimit: 3,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TasksRingCard(
                    done: focus!.tasks.where((t) => t.isCompleted).length,
                    total: focus.tasks.length,
                  ),
                  const SizedBox(width: 12),
                  StreakCard(streak: profile.currentStreak),
                ],
              ).animate().fadeIn(delay: 100.ms),
            ],
            const SizedBox(height: 24),
            const ActivityCalendarCard(),
            const SizedBox(height: 24),
            Text(
              'Programs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 12),
            _PersonalProgramCard(
              challenge: personal,
              onStart: () => context.push(AppRoutes.onboarding),
              onOpen: personal == null
                  ? null
                  : () => context.push('/home/challenge/${personal.id}'),
              onTasks: personal == null
                  ? null
                  : () => context.push('/home/challenge/${personal.id}'),
            ).animate().fadeIn(delay: 40.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 12),
            _GroupProgramCard(
              challenge: group,
              onBrowse: () => context.go('${AppRoutes.home}/groups'),
              onOpen: group == null
                  ? null
                  : () {
                      if (group.groupId != null) {
                        context.push('/groups/${group.groupId}/dashboard');
                      } else {
                        context.push('/home/challenge/${group.id}');
                      }
                    },
              onTasks: group == null
                  ? null
                  : () => context.push('/home/challenge/${group.id}'),
            ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08, end: 0),
            if (focus?.quote != null) ...[
              const SizedBox(height: 18),
              SoftCard(
                color: AppColors.orangeSoft,
                borderColor: AppColors.orange.withValues(alpha: 0.2),
                child: Text(
                  focus!.quote!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayTaskStrip extends StatelessWidget {
  const _TodayTaskStrip({
    required this.label,
    required this.challenge,
    this.taskLimit = 3,
  });

  final String label;
  final ChallengeModel challenge;
  final int taskLimit;

  @override
  Widget build(BuildContext context) {
    if (challenge.isScheduled) {
      final d = challenge.startDate;
      final when = d == null ? '' : ' on ${DateFormat('EEE, MMM d').format(d)}';
      return SoftCard(
        child: Row(
          children: [
            const GlossyIcon(icon: Icons.event_rounded, color: AppColors.orange, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starts$when',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your ${challenge.tasks.length} tasks unlock on day one.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/home/challenge/${challenge.id}'),
              child: const Text('View day'),
            ),
          ],
        ),
        ...challenge.tasks.take(taskLimit).map(
              (task) => TaskTile(
                title: task.title,
                isCompleted: task.isCompleted,
                isFoundation: task.type == 'foundation',
                groupTask: challenge.isGroup,
                onChanged: (_) =>
                    context.push('/home/challenge/${challenge.id}'),
              ),
            ),
      ],
    );
  }
}

class _PersonalProgramCard extends StatelessWidget {
  const _PersonalProgramCard({
    required this.challenge,
    required this.onStart,
    this.onOpen,
    this.onTasks,
  });

  final ChallengeModel? challenge;
  final VoidCallback onStart;
  final VoidCallback? onOpen;
  final VoidCallback? onTasks;

  static const _accent = AppColors.orange;
  static Color get _accentSoft => AppColors.orangeSoft;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    return _ProgramShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgramBadge(
            label: 'Personal',
            color: _accent,
            softColor: _accentSoft,
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 14),
          if (c == null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SquareProgramIcon(
                  color: _accent,
                  softColor: _accentSoft,
                  icon: Icons.flag_rounded,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No personal program',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Start a 21 or 30-day discipline challenge and level up yourself.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: '21 or 30 days',
                            color: _accent,
                            softColor: _accentSoft,
                          ),
                          _InfoChip(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Build consistency',
                            color: _accent,
                            softColor: _accentSoft,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FilledProgramButton(
              label: 'Start Challenge',
              icon: Icons.add_rounded,
              color: _accent,
              onPressed: onStart,
            ),
          ] else ...[
            _ActiveProgramBody(
              accent: _accent,
              softAccent: _accentSoft,
              icon: Icons.flag_rounded,
              name: c.name,
              currentDay: c.currentDay,
              durationDays: c.durationDays,
              progressPercent: c.progressPercent,
              dayComplete: c.dayComplete,
              startsInDays: c.daysUntilStart,
              onTap: onOpen,
            ),
            const SizedBox(height: 16),
            _DualProgramActions(
              accent: _accent,
              onOpen: onOpen,
              onTasks: c.isScheduled ? null : onTasks,
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupProgramCard extends ConsumerWidget {
  const _GroupProgramCard({
    required this.challenge,
    required this.onBrowse,
    this.onOpen,
    this.onTasks,
  });

  final ChallengeModel? challenge;
  final VoidCallback onBrowse;
  final VoidCallback? onOpen;
  final VoidCallback? onTasks;

  static Color get _accent => AppColors.navy;
  static Color get _accentSoft => AppColors.blueSoft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = challenge;
    final groups =
        ref.watch(groupsProvider).valueOrNull ?? const <GroupModel>[];
    GroupModel? groupMeta;
    if (c?.groupId != null) {
      for (final g in groups) {
        if (g.id == c!.groupId) {
          groupMeta = g;
          break;
        }
      }
    }

    return _ProgramShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgramBadge(
            label: 'Group',
            color: _accent,
            softColor: _accentSoft,
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 14),
          if (c == null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SquareProgramIcon(
                  color: _accent,
                  softColor: _accentSoft,
                  icon: Icons.groups_rounded,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No group program',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Join or create a group for shared accountability.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FilledProgramButton(
              label: 'Browse Groups',
              icon: Icons.explore_rounded,
              color: _accent,
              onPressed: onBrowse,
            ),
          ] else ...[
            _ActiveProgramBody(
              accent: _accent,
              softAccent: _accentSoft,
              icon: Icons.groups_rounded,
              name: c.name,
              currentDay: c.currentDay,
              durationDays: c.durationDays,
              progressPercent: c.progressPercent,
              dayComplete: c.dayComplete,
              onTap: onOpen,
              memberCount: groupMeta?.memberCount,
            ),
            const SizedBox(height: 16),
            _DualProgramActions(
              accent: _accent,
              onOpen: onOpen,
              onTasks: onTasks,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgramShell extends StatelessWidget {
  const _ProgramShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProgramBadge extends StatelessWidget {
  const _ProgramBadge({
    required this.label,
    required this.color,
    required this.softColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color softColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.softColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareProgramIcon extends StatelessWidget {
  const _SquareProgramIcon({
    required this.color,
    required this.softColor,
    required this.icon,
  });

  final Color color;
  final Color softColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 28, color: color),
    );
  }
}

class _ActiveProgramBody extends StatelessWidget {
  const _ActiveProgramBody({
    required this.accent,
    required this.softAccent,
    required this.icon,
    required this.name,
    required this.currentDay,
    required this.durationDays,
    required this.progressPercent,
    required this.dayComplete,
    this.startsInDays = 0,
    this.onTap,
    this.memberCount,
  });

  final Color accent;
  final Color softAccent;
  final IconData icon;
  final String name;
  final int currentDay;
  final int durationDays;
  final double progressPercent;
  final bool dayComplete;
  final int startsInDays;
  final VoidCallback? onTap;
  final int? memberCount;

  @override
  Widget build(BuildContext context) {
    final pct = progressPercent.round().clamp(0, 100);
    final members = memberCount ?? 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SquareProgramIcon(color: accent, softColor: softAccent, icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  startsInDays > 0
                      ? 'Starts in $startsInDays day${startsInDays == 1 ? '' : 's'}'
                      : 'Day $currentDay / $durationDays'
                          '${dayComplete ? ' · done' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (progressPercent / 100).clamp(0.0, 1.0),
                          minHeight: 7,
                          color: accent,
                          backgroundColor: AppColors.borderStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (members > 0) ...[
                  const SizedBox(height: 12),
                  _MemberStackRow(
                      memberCount: members,
                      accent: accent,
                      softAccent: softAccent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberStackRow extends StatelessWidget {
  const _MemberStackRow({
    required this.memberCount,
    required this.accent,
    required this.softAccent,
  });

  final int memberCount;
  final Color accent;
  final Color softAccent;

  static const _palette = [
    Color(0xFF5B8DEF),
    Color(0xFF18BEBC),
    Color(0xFFF15A29),
    Color(0xFFF6C744),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = memberCount.clamp(0, 4);
    final overflow = memberCount > 4 ? memberCount - 4 : 0;

    return Row(
      children: [
        SizedBox(
          width: 18.0 +
              (shown > 0 ? (shown - 1) * 16.0 : 0) +
              (overflow > 0 ? 28.0 : 0),
          height: 28,
          child: Stack(
            children: [
              for (var i = 0; i < shown; i++)
                Positioned(
                  left: i * 16.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _palette[i % _palette.length],
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              if (overflow > 0)
                Positioned(
                  left: shown * 16.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: softAccent,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '+$overflow',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$memberCount members',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FilledProgramButton extends StatelessWidget {
  const _FilledProgramButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _DualProgramActions extends StatelessWidget {
  const _DualProgramActions({
    required this.accent,
    this.onOpen,
    this.onTasks,
  });

  final Color accent;
  final VoidCallback? onOpen;
  final VoidCallback? onTasks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Open', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: onTasks,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(
                    color: accent.withValues(alpha: 0.55), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rounded, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "Today's tasks",
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontWeight: FontWeight.w600, color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

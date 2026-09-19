import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  int? _selectedDay;
  bool _showCelebration = false;
  String _celebrationSubtitle = 'Next day unlocks after midnight';
  List<TaskModel>? _dayTasks;
  bool _loadingDay = false;

  Future<void> _loadDay(ChallengeModel challenge, int dayNumber) async {
    if (dayNumber == challenge.currentDay &&
        challenge.status != 'completed' &&
        challenge.status != 'failed') {
      setState(() {
        _selectedDay = dayNumber;
        _dayTasks = null;
      });
      return;
    }
    setState(() {
      _selectedDay = dayNumber;
      _loadingDay = true;
    });
    try {
      final data = await ref
          .read(apiRepositoryProvider)
          .getChallengeDay(challenge.id, dayNumber);
      final tasks = (data['tasks'] as List<dynamic>? ?? [])
          .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _dayTasks = tasks;
        _loadingDay = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dayTasks = const [];
        _loadingDay = false;
      });
    }
  }

  Future<void> _toggleTask(ChallengeModel challenge, TaskModel task) async {
    if (task.isCompleted) return;
    if (_selectedDay != null && _selectedDay != challenge.currentDay) return;
    HapticFeedback.mediumImpact();
    try {
      final result = await ref.read(apiRepositoryProvider).completeTask(
            challenge.id,
            task.id,
          );
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(personalStatsProvider);
      if (result['challenge_completed'] == true && mounted) {
        context.go(AppRoutes.challengeComplete);
        return;
      }
      if (result['celebration'] == true && mounted) {
        setState(() {
          _showCelebration = true;
          _celebrationSubtitle =
              (result['reward_message'] as String?) ?? '+10 HP · score updated';
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(challengeDetailProvider(widget.challengeId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.orange)),
        error: (e, _) => Center(child: Text('$e')),
        data: (challenge) {
          final selected = _selectedDay ?? challenge.currentDay;
          final isToday = selected == challenge.currentDay &&
              challenge.status != 'completed' &&
              challenge.status != 'failed';
          ChallengeDayModel? dayMeta;
          for (final d in challenge.days) {
            if (d.dayNumber == selected) {
              dayMeta = d;
              break;
            }
          }
          final showTasks = isToday ? challenge.tasks : (_dayTasks ?? const <TaskModel>[]);
          final isPastChallenge =
              challenge.status == 'completed' || challenge.status == 'failed';

          return Stack(
            children: [
              SafeArea(
                child: RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: () async {
                    ref.invalidate(challengeDetailProvider(widget.challengeId));
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Expanded(
                            child: Text(
                              challenge.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      if (isPastChallenge) ...[
                        SoftCard(
                          color: challenge.status == 'completed'
                              ? const Color(0xFFFFF8E7)
                              : const Color(0xFFFFF1F1),
                          child: Text(
                            challenge.status == 'completed'
                                ? 'Challenge completed — review what you achieved day by day.'
                                : 'This challenge ended early. Missed days and completed tasks are below.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ChallengeDayStrip(
                        days: challenge.days.isNotEmpty
                            ? challenge.days
                            : [
                                ChallengeDayModel(
                                  dayNumber: challenge.currentDay,
                                  calendarDate:
                                      DateTime.now().toIso8601String().split('T').first,
                                  isComplete: challenge.dayComplete,
                                  isMissed: false,
                                  isToday: true,
                                  isLocked: false,
                                ),
                              ],
                        selectedDay: selected,
                        onSelect: (day) => _loadDay(challenge, day),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            isToday
                                ? "Today's tasks"
                                : 'Day $selected ${dayMeta?.isComplete == true ? '· done' : ''}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          if (dayMeta?.isMissed == true)
                            const Text(
                              'Missed',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (isToday && challenge.dayComplete)
                            const Text(
                              'Done for today',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isToday
                            ? (challenge.dayComplete
                                ? 'Come back after midnight for the next day.'
                                : (challenge.todayMission ??
                                    'Complete your tasks before the day ends.'))
                            : (dayMeta?.isLocked == true
                                ? 'This day unlocks after midnight.'
                                : 'What you completed on this day.'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_loadingDay)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.orange),
                          ),
                        )
                      else if (!isToday && dayMeta?.isLocked == true)
                        const SoftCard(
                          child: Text(
                            'Tasks for this day will appear after 12:00 AM.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else if (showTasks.isEmpty)
                        const SoftCard(
                          child: Text(
                            'No task records for this day.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        ...showTasks.asMap().entries.map((e) {
                          final t = e.value;
                          return TaskTile(
                            title: t.title,
                            isCompleted: t.isCompleted,
                            isFoundation: t.type == 'foundation',
                            onChanged: (!isToday || t.isCompleted)
                                ? null
                                : (_) => _toggleTask(challenge, t),
                          )
                              .animate(delay: (70 * e.key).ms)
                              .fadeIn()
                              .slideX(begin: 0.05, end: 0);
                        }),
                      if (challenge.quote != null && isToday) ...[
                        const SizedBox(height: 16),
                        SoftCard(
                          color: const Color(0xFFFFF7F0),
                          borderColor: AppColors.orange.withValues(alpha: 0.2),
                          child: Text(
                            challenge.quote!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showCelebration)
                CelebrationOverlay(
                  title: 'Day complete!',
                  subtitle: _celebrationSubtitle,
                  onDismiss: () => setState(() => _showCelebration = false),
                ),
            ],
          );
        },
      ),
    );
  }
}

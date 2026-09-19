import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  String? _goal;
  int _duration = 21;
  final List<String> _selectedTasks = [];
  final _customTaskController = TextEditingController();
  bool _notifications = true;
  bool _includeFoundation = true;
  bool _loading = false;

  static const _steps = ['Goal', 'Duration', 'Foundation', 'Tasks', 'Commit'];

  Future<void> _next() async {
    if (_step == 0 && _goal == null) return;
    if (_step == 3 && _selectedTasks.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 personal tasks')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _saveCurrentStep();
      if (_step < 4) {
        if (!mounted) return;
        setState(() {
          _step++;
          _loading = false;
        });
        return;
      }

      await ref.read(apiRepositoryProvider).completeOnboarding();
      if (!mounted) return;
      ref.invalidate(activeChallengeProvider);
      ref.invalidate(activeProgramsProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(groupsProvider);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Persist the step the user is leaving (0-based UI → 1-based API).
  Future<void> _saveCurrentStep() async {
    final data = <String, dynamic>{};
    final apiStep = _step + 1;
    if (_step == 0 && _goal != null) data['goal'] = _goal;
    if (_step == 1) data['duration_days'] = _duration;
    if (_step == 2) data['include_foundation'] = _includeFoundation;
    if (_step == 3) {
      data['personal_tasks'] = List<String>.from(_selectedTasks);
      data['notifications'] = _notifications;
      data['include_foundation'] = _includeFoundation;
    }
    if (_step == 4) {
      data['committed'] = true;
      data['notifications'] = _notifications;
      data['personal_tasks'] = List<String>.from(_selectedTasks);
      data['include_foundation'] = _includeFoundation;
    }
    if (data.isNotEmpty) {
      await ref.read(apiRepositoryProvider).saveOnboardingStep(apiStep, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);
    final isCommit = _step == 4;

    return Scaffold(
      backgroundColor: isCommit ? const Color(0xFFFFF8F2) : null,
      appBar: AppBar(
        backgroundColor: isCommit ? const Color(0xFFFFF8F2) : null,
        title: Text('Setup · ${_steps[_step]}'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step--))
            : null,
      ),
      body: Container(
        decoration: isCommit
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF8F2),
                    Color(0xFFFFF1E6),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0, 0.4, 1],
                ),
              )
            : null,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps.length,
                    minHeight: 10,
                    color: AppColors.orange,
                    backgroundColor: AppColors.borderStrong,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: switch (_step) {
                    0 => _buildGoalStep(goalsAsync),
                    1 => _buildDurationStep(),
                    2 => _buildFoundationStep(),
                    3 => _buildTasksStep(),
                    _ => _buildCommitStep(),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: isCommit
                    ? PrimaryButton(
                        label: 'I Commit — Start Day 1',
                        onPressed: _next,
                        isLoading: _loading,
                      )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic)
                    : PrimaryButton(
                        label: 'Continue',
                        onPressed: _next,
                        isLoading: _loading,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalStep(AsyncValue<List<GoalModel>> goalsAsync) {
    final icons = <String, IconData>{
      'ielts': Icons.school_rounded,
      'sat': Icons.menu_book_rounded,
      'programming': Icons.code_rounded,
      'fitness': Icons.fitness_center_rounded,
      'reading': Icons.auto_stories_rounded,
      'quran': Icons.mosque_rounded,
      'productivity': Icons.bolt_rounded,
      'custom': Icons.flag_rounded,
    };
    final colors = [
      AppColors.orange,
      AppColors.teal,
      AppColors.blue,
      AppColors.goldDepth,
      const Color(0xFF8B5CF6),
      AppColors.hp,
    ];

    return goalsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange)),
      error: (e, _) => Text('Error loading goals: $e'),
      data: (goals) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose your goal',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'What are you building discipline for?',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (_, i) {
              final g = goals[i];
              final selected = _goal == g.slug;
              final color = colors[i % colors.length];
              final icon = icons[g.slug.toLowerCase()] ??
                  icons.entries
                      .firstWhere(
                        (e) => g.slug.toLowerCase().contains(e.key),
                        orElse: () =>
                            const MapEntry('custom', Icons.flag_rounded),
                      )
                      .value;
              return GestureDetector(
                onTap: () => setState(() => _goal = g.slug),
                child: SoftCard(
                  color: selected
                      ? color.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderColor: selected ? color : AppColors.border,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        g.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? color : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDurationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Challenge duration',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        _DurationCard(
          days: 21,
          selected: _duration == 21,
          onTap: () => setState(() => _duration = 21),
        ),
        const SizedBox(height: 12),
        _DurationCard(
          days: 30,
          selected: _duration == 30,
          onTap: () => setState(() => _duration = 30),
        ),
      ],
    );
  }

  Widget _buildFoundationStep() {
    const tasks = ['Wake up on time', 'Daily planning', 'Evening review'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foundation tasks',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Optional habits that support every challenge. You can include them or skip.',
          style: TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Include foundation tasks',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _includeFoundation
                  ? 'Wake up, planning, and evening review will be added'
                  : 'Only your personal tasks will be used',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            value: _includeFoundation,
            activeThumbColor: AppColors.orange,
            onChanged: (v) => setState(() => _includeFoundation = v),
          ),
        ),
        if (_includeFoundation) ...[
          const SizedBox(height: 16),
          ...tasks.map(
            (t) => TaskTile(
              title: t,
              isCompleted: false,
              isFoundation: true,
              onChanged: null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTasksStep() {
    final templatesAsync =
        _goal != null ? ref.watch(taskTemplatesProvider(_goal!)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personal tasks',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Select at least 2 (${_selectedTasks.length} selected)'),
        const SizedBox(height: 16),
        if (templatesAsync != null)
          templatesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (templates) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: templates.map((t) {
                final selected = _selectedTasks.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTasks.add(t);
                      } else {
                        _selectedTasks.remove(t);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customTaskController,
                decoration: const InputDecoration(hintText: 'Custom task'),
                onSubmitted: (_) => _addCustomTask(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addCustomTask,
            ),
          ],
        ),
        if (_selectedTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Your personal tasks',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._selectedTasks.map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedTasks.remove(t)),
              ),
            ),
          ),
        ],
        SwitchListTile(
          title: const Text('Enable notifications'),
          subtitle: const Text('Motivating mission reminders'),
          value: _notifications,
          onChanged: (v) => setState(() => _notifications = v),
        ),
      ],
    );
  }

  void _addCustomTask() {
    final t = _customTaskController.text.trim();
    if (t.isNotEmpty && !_selectedTasks.contains(t)) {
      setState(() {
        _selectedTasks.add(t);
        _customTaskController.clear();
      });
    }
  }

  Widget _buildCommitStep() {
    final taskCount = _selectedTasks.length + (_includeFoundation ? 3 : 0);
    final goalLabel = (_goal ?? 'goal').replaceAll('_', ' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const BrandLogo(
              size: 96,
              variant: BrandLogoVariant.onBlue,
            ),
          ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.92, 0.92),
                curve: Curves.easeOutCubic,
                duration: 450.ms,
              ),
        ),
        const SizedBox(height: 28),
        Text(
          'Your commitment',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 8),
        const Text(
          'Review your plan, then lock Day 1.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: 24),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              _CommitSummaryRow(
                icon: Icons.flag_rounded,
                color: AppColors.orange,
                label: 'Goal',
                value: goalLabel,
              ),
              const Divider(height: 1),
              _CommitSummaryRow(
                icon: Icons.calendar_today_rounded,
                color: AppColors.teal,
                label: 'Duration',
                value: '$_duration days',
              ),
              const Divider(height: 1),
              _CommitSummaryRow(
                icon: Icons.checklist_rounded,
                color: AppColors.navy,
                label: 'Daily tasks',
                value: '$taskCount ready',
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 160.ms)
            .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 20),
        SoftCard(
          color: AppColors.cream,
          borderColor: AppColors.gold.withValues(alpha: 0.35),
          child: const Text(
            'Discipline is choosing between what you want now and what you want most.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ).animate().fadeIn(delay: 220.ms),
        const SizedBox(height: 16),
        const Text(
          'By tapping "I Commit", you begin your training program.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 260.ms),
      ],
    );
  }

  @override
  void dispose() {
    _customTaskController.dispose();
    super.dispose();
  }
}

class _CommitSummaryRow extends StatelessWidget {
  const _CommitSummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard(
      {required this.days, required this.selected, required this.onTap});
  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SoftCard(
        color: selected
            ? AppColors.orange.withValues(alpha: 0.1)
            : AppColors.surface,
        borderColor: selected ? AppColors.orange : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$days Days',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.orange : AppColors.textPrimary,
              ),
            ),
            Text(
              days == 21
                  ? 'Classic discipline sprint'
                  : 'Extended mastery program',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

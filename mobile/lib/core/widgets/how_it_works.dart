import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cache/app_cache.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Keep these equal to the backend constants in `challenge_service.py`.
const kTaskPoints = 5;
const kDayBonusPoints = 10;
const kMissedDayPenalty = 15;

const _seenFlag = 'how_it_works_seen';

/// Show the walkthrough once, the first time someone reaches Home.
bool get howItWorksSeen => AppCache.flag(_seenFlag);

class _Slide {
  const _Slide(this.icon, this.color, this.title, this.body);

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

List<_Slide> get _slides => [
  _Slide(
    Icons.flag_rounded,
    AppColors.orange,
    'One challenge, a few tasks a day',
    'Pick a challenge (like Social Media Detox), choose the tasks you will do '
        'every day, and choose when to start. You can add "daily basics" too: '
        'wake up on time, plan your day, review the evening.',
  ),
  _Slide(
    Icons.bolt_rounded,
    AppColors.orange,
    'Every task earns points',
    '+$kTaskPoints points for each task you finish, and a +$kDayBonusPoints bonus '
        'when you finish all of them in a day. Your points decide your place on '
        'the leaderboard.',
  ),
  _Slide(
    Icons.local_fire_department_rounded,
    AppColors.teal,
    'Keep your streak',
    'Finish all your tasks each day to grow your streak. A new day starts at '
        'midnight, so you can only do today\'s tasks today. Tomorrow unlocks itself.',
  ),
  _Slide(
    Icons.trending_down_rounded,
    AppColors.danger,
    'Missing a day costs you',
    'Skip a day and you lose $kMissedDayPenalty points and your streak resets. '
        'Miss several days in a row and you enter recovery: finish your basics '
        'to get back on track. You can also cancel a challenge any time.',
  ),
  _Slide(
    Icons.groups_rounded,
    AppColors.navy,
    'Go further with a group',
    'Join a group with an invite code. The admin sets the tasks (or lets you '
        'choose your own), and the group has its own ranking and chat to keep '
        'each other going.',
  ),
];

Future<void> showHowItWorks(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _HowItWorksSheet(),
  );
  AppCache.setFlag(_seenFlag);
}

class _HowItWorksSheet extends StatefulWidget {
  const _HowItWorksSheet();

  @override
  State<_HowItWorksSheet> createState() => _HowItWorksSheetState();
}

class _HowItWorksSheetState extends State<_HowItWorksSheet> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page == _slides.length - 1) {
      Navigator.of(context).pop();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.orange : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              children: [
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  const SizedBox(width: 64),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(label: last ? 'Got it' : 'Next', onPressed: _next),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    // Scrolls on small screens or with large text instead of overflowing.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: slide.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(slide.icon, size: 44, color: slide.color),
              ),
              const SizedBox(height: 26),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                slide.body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.5, height: 1.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact "how do points work" sheet, opened from small (i) buttons.
Future<void> showPointsInfo(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How points work', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const _PointsRow(
              icon: Icons.check_circle_rounded,
              color: AppColors.teal,
              label: 'Finish a task',
              value: '+$kTaskPoints',
            ),
            const _PointsRow(
              icon: Icons.emoji_events_rounded,
              color: AppColors.orange,
              label: 'Finish every task in a day',
              value: '+$kDayBonusPoints bonus',
            ),
            const _PointsRow(
              icon: Icons.trending_down_rounded,
              color: AppColors.danger,
              label: 'Miss a day (and your streak resets)',
              value: '-$kMissedDayPenalty',
            ),
            const SizedBox(height: 8),
            Text(
              'Your points never go below 0. Group points count only what you '
              'earn inside that group.',
              style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PointsRow extends StatelessWidget {
  const _PointsRow({
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

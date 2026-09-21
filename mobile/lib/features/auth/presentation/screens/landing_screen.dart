import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

const _navy = Color(0xFF033D95);
const _blue = Color(0xFF1C74BB);

/// First screen for signed-out users. Sign up / Log in are pinned at the bottom
/// so they are always visible, whatever the screen height.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _CtaBar(
        onSignUp: () => context.push(AppRoutes.signup),
        onLogIn: () => context.push(AppRoutes.login),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const _Hero(),
                const SizedBox(height: 28),
                _SectionTitle('See it in action'),
                const SizedBox(height: 12),
                const _Previews(),
                const SizedBox(height: 26),
                const _Numbers(),
                const SizedBox(height: 22),
                const _Manifesto(),
                const SizedBox(height: 22),
                const Center(child: MadeByIlmHub()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bottom bar
class _CtaBar extends StatelessWidget {
  const _CtaBar({required this.onSignUp, required this.onLogIn});

  final VoidCallback onSignUp;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(label: 'Sign up free', onPressed: onSignUp),
                  const SizedBox(height: 10),
                  PrimaryButton(label: 'Log in', outlined: true, onPressed: onLogIn),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hero
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _blue],
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset('assets/brand/app_icon.png', width: 38, height: 38),
              ),
              const SizedBox(width: 10),
              Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    // Fill the 21 days, hold, then start over.
                    final fill = Curves.easeInOut.transform((_c.value / 0.72).clamp(0.0, 1.0));
                    final day = (fill * 21).round();
                    final done = day >= 21;
                    return CustomPaint(
                      painter: _RingPainter(fill * 21),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              done ? Icons.emoji_events_rounded : Icons.check_rounded,
                              color: done ? const Color(0xFFF6C744) : Colors.white,
                              size: 34,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              done ? 'Done!' : 'Day $day',
                              style: const TextStyle(
                                fontSize: 34,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'of 21',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Positioned(
                  right: -4,
                  top: 18,
                  child: _FloatChip(icon: Icons.bolt_rounded, text: '+5 pts', delay: 0),
                ),
                const Positioned(
                  left: -6,
                  bottom: 34,
                  child: _FloatChip(
                    icon: Icons.local_fire_department_rounded,
                    text: 'Streak',
                    delay: 700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Build discipline,\none day at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15, end: 0),
          const SizedBox(height: 10),
          Text(
            'Small daily tasks. A streak you protect.\nA 21-day challenge that changes you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.filled);

  /// How many of the 21 segments are filled (fractions animate smoothly).
  final double filled;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 21;
    const gap = 0.075;
    final stroke = size.width * 0.075;
    final radius = size.width / 2 - stroke / 2 - 4;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final sweep = 2 * math.pi / segments - gap;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.16);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = const Color(0xFFF15A29).withValues(alpha: 0.35);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [Color(0xFFF15A29), Color(0xFFF6C744), Color(0xFFF15A29)],
      ).createShader(rect);

    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * (2 * math.pi / segments) + gap / 2;
      canvas.drawArc(rect, start, sweep, false, track);
      final f = (filled - i).clamp(0.0, 1.0);
      if (f > 0) {
        canvas.drawArc(rect, start, sweep * f, false, glow);
        canvas.drawArc(rect, start, sweep * f, false, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.filled != filled;
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.icon, required this.text, required this.delay});

  final IconData icon;
  final String text;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF15A29)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF15161A),
            ),
          ),
        ],
      ),
    )
        .animate(delay: delay.ms, onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -3, end: 4, duration: 1800.ms, curve: Curves.easeInOut);
  }
}

// ------------------------------------------------------------------ previews
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
      );
}

class _Previews extends StatelessWidget {
  const _Previews();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: const [
          _PreviewCard(
            title: 'Finish your daily tasks',
            subtitle: 'Tick them off and earn points.',
            child: _TasksVisual(),
          ),
          _PreviewCard(
            title: 'Protect your streak',
            subtitle: 'Every day counts. Miss one and it resets.',
            child: _StreakVisual(),
          ),
          _PreviewCard(
            title: 'Climb the ranking',
            subtitle: 'Compete with friends and groups.',
            child: _RankVisual(),
          ),
          _PreviewCard(
            title: 'Team up in a group',
            subtitle: 'Shared tasks and a chat.',
            child: _TeamVisual(),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 246,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The visual scales down instead of overflowing on small screens / big text.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(width: 212, child: child),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TasksVisual extends StatelessWidget {
  const _TasksVisual();

  @override
  Widget build(BuildContext context) {
    const rows = ['Wake up on time', 'Read 20 pages', 'No social media'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                )
                    .animate(
                      delay: (400 + i * 350).ms,
                      onPlay: (c) => c.repeat(period: 3600.ms),
                    )
                    .scale(begin: const Offset(0, 0), duration: 300.ms, curve: Curves.easeOutBack)
                    .then(delay: 2400.ms)
                    .scale(end: const Offset(0, 0), duration: 200.ms),
              ],
            ),
          ),
      ],
    );
  }
}

class _StreakVisual extends StatelessWidget {
  const _StreakVisual();

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.orange, size: 44)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1.08, 1.08),
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(width: 6),
            Text(
              '12',
              style: TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Text(
                'day streak',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: i < 6 ? AppColors.teal : AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(days[i], style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _RankVisual extends StatelessWidget {
  const _RankVisual();

  @override
  Widget build(BuildContext context) {
    Widget bar(String place, String pts, double h, Color color) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(pts, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
              const SizedBox(height: 4),
              Container(
                height: h,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Text(
                  place,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bar('2', '95', 52, const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        bar('1', '120', 84, const Color(0xFFF5B301)),
        const SizedBox(width: 8),
        bar('3', '60', 38, const Color(0xFFD9822B)),
      ],
    );
  }
}

class _TeamVisual extends StatelessWidget {
  const _TeamVisual();

  @override
  Widget build(BuildContext context) {
    Widget avatar(String l, Color c, double left) => Positioned(
          left: left,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2.5),
            ),
            child: Text(l, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        );
    Widget bubble(String t, bool mine) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: mine ? AppColors.orange : AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              t,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: mine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 38,
          child: Stack(
            children: [
              avatar('A', const Color(0xFF3B82F6), 0),
              avatar('B', const Color(0xFF14B8A6), 26),
              avatar('C', const Color(0xFFF59E0B), 52),
              avatar('+', AppColors.muted, 78),
            ],
          ),
        ),
        bubble('Done with my tasks!', false),
        bubble('Nice, keep going', true),
      ],
    );
  }
}

// ------------------------------------------------------------------ numbers + manifesto
class _Numbers extends StatelessWidget {
  const _Numbers();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, Color color, String big, String small) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text(
                  big,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  small,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, height: 1.25, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile(Icons.bolt_rounded, AppColors.orange, '+5', 'points for every task'),
        const SizedBox(width: 10),
        tile(Icons.emoji_events_rounded, AppColors.goldDepth, '+10', 'bonus for a perfect day'),
        const SizedBox(width: 10),
        tile(Icons.groups_rounded, AppColors.teal, 'Groups', 'ranking and chat'),
      ],
    );
  }
}

class _Manifesto extends StatelessWidget {
  const _Manifesto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.orange.withValues(alpha: 0.14),
            AppColors.orange.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: AppColors.orange, size: 30),
          const SizedBox(height: 4),
          Text(
            'Discipline is choosing between what you want now and what you want most.',
            style: TextStyle(
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No sign-up fee. No pressure. Just you, one day at a time.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

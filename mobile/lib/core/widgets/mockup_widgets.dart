import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Glossy 3D-style icon bubble used across the mockup.
class GlossyIcon extends StatelessWidget {
  const GlossyIcon({
    super.key,
    required this.icon,
    this.size = 56,
    this.color = AppColors.orange,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.18)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.48),
    );
  }
}

/// Animated horizontal progress (fills on appear).
class AnimatedFillBar extends StatelessWidget {
  const AnimatedFillBar({
    super.key,
    required this.value,
    this.height = 12,
    this.color = AppColors.orange,
    this.background = const Color(0x33FFFFFF),
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final double height;
  final Color color;
  final Color background;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: background,
          color: color,
        ),
      ),
    );
  }
}

/// Circular day / task ring that animates from 0.
class AnimatedRing extends StatelessWidget {
  const AnimatedRing({
    super.key,
    required this.progress,
    this.size = 160,
    this.stroke = 12,
    this.color = AppColors.orange,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: stroke,
                backgroundColor: AppColors.borderStrong,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// Dark challenge progress card (photo 7 style) — tappable.
class IlmChallengeCard extends StatelessWidget {
  const IlmChallengeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dayLabel,
    required this.progress,
    this.message = "Keep going! You're doing great.",
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String dayLabel;
  final double progress;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E11),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dayLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: const Color(0xFF2A2F36),
                  valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

/// Home greeting hero with brand mark (no mountain asset).
class HomeGreetingHero extends StatelessWidget {
  const HomeGreetingHero({
    super.key,
    required this.name,
  });

  final String name;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final first = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting, $first',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(text: 'Discipline today,\n'),
                    TextSpan(text: 'success', style: TextStyle(color: AppColors.navy)),
                    TextSpan(text: ' tomorrow.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stay focused, keep going and become your best version.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _HomeBrandBadge(),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06, end: 0);
  }
}

class _HomeBrandBadge extends StatelessWidget {
  const _HomeBrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF4EC),
            Color(0xFFFFE0D0),
            Color(0xFFFFF8F2),
          ],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '21',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          const BrandLogo(size: 64, variant: BrandLogoVariant.gold)
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                duration: 650.ms,
                curve: Curves.easeOutCubic,
              ),
          Positioned(
            bottom: 12,
            child: Text(
              'ILM HUB',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.2,
                color: AppColors.orangeDepth.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal day calendar strip (photo 8).
class ChallengeDayStrip extends StatelessWidget {
  const ChallengeDayStrip({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<ChallengeDayModel> days;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  static const _weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = days[i];
          final selected = d.dayNumber == selectedDay;
          final date = d.date;
          final label = date != null ? _weekday[date.weekday - 1] : 'Day';
          final num = date?.day.toString() ?? '${d.dayNumber}';

          Color bg = Colors.white;
          Color fg = AppColors.textSecondary;
          Color border = AppColors.borderStrong;
          if (selected) {
            bg = AppColors.teal;
            fg = Colors.white;
            border = AppColors.teal;
          } else if (d.isMissed) {
            border = AppColors.danger.withValues(alpha: 0.45);
          } else if (d.isComplete) {
            border = AppColors.success.withValues(alpha: 0.45);
          }

          return GestureDetector(
            onTap: d.isLocked ? null : () => onSelect(d.dayNumber),
            child: Opacity(
              opacity: d.isLocked ? 0.45 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border, width: 1.5),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      num,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.7)
                            : d.isComplete
                                ? AppColors.success
                                : d.isMissed
                                    ? AppColors.danger
                                    : AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pulsing streak flame card.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const GlossyIcon(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange,
              size: 48,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 900.ms,
                ),
            const SizedBox(height: 10),
            Text(
              '$streak',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: AppColors.orange,
              ),
            ),
            const Text(
              'Day Streak',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TasksRingCard extends StatelessWidget {
  const TasksRingCard({
    super.key,
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : done / total;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            AnimatedRing(
              progress: p,
              size: 72,
              stroke: 8,
              color: AppColors.teal,
              child: Text(
                '$done/$total',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tasks done',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple animated line chart for stats.
class AnimatedLineChart extends StatelessWidget {
  const AnimatedLineChart({
    super.key,
    required this.values,
    this.height = 140,
  });

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _LineChartPainter(values: values, progress: t),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.progress});
  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max).clamp(1.0, double.infinity);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1).clamp(1, 999));
      final y = size.height - (values[i] / maxV) * (size.height * 0.85);
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final extract = metric.extractPath(0, metric.length * progress);

    final fill = Path.from(extract)
      ..lineTo(pts[(pts.length * progress).floor().clamp(0, pts.length - 1)].dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.orange.withValues(alpha: 0.28),
            AppColors.orange.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      extract,
      Paint()
        ..color = AppColors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (progress > 0.95) {
      for (final p in pts) {
        canvas.drawCircle(p, 4.5, Paint()..color = AppColors.orange);
        canvas.drawCircle(p, 2.2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

/// Stat tile with bounce-in.
class StatTile3D extends StatelessWidget {
  const StatTile3D({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.delay = Duration.zero,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            GlossyIcon(icon: icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      )
          .animate(delay: delay)
          .fadeIn(duration: 350.ms)
          .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
    );
  }
}

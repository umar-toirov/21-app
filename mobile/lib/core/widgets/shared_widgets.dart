import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/env.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// The app mark and name. Uses the icon glyph that suits the current theme.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppColors.isDark
                ? 'assets/brand/app_glyph.png'
                : 'assets/brand/app_glyph_light.png',
            width: size * 1.25,
            height: size * 1.25,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(width: size * 0.2),
          Text(
            AppConfig.appName,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: -size * 0.03,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small credit line: the app is made by ILM HUB (no logo).
class MadeByIlmHub extends StatelessWidget {
  const MadeByIlmHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Made by ',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: 'ILM HUB',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 12.5),
      textAlign: TextAlign.center,
    );
  }
}

/// Flat primary button with soft glow and a subtle press scale.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.color,
    this.depthColor,
    this.textColor,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final Color? color;
  final Color? depthColor;
  final Color? textColor;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.outlined) {
      return _OutlinedDuoButton(
        label: widget.label,
        onPressed: widget.isLoading ? null : widget.onPressed,
        isLoading: widget.isLoading,
        icon: widget.icon,
      );
    }

    final color = widget.color ?? AppColors.orange;
    final fg = widget.textColor ?? Colors.white;
    final enabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? color : AppColors.borderStrong,
          borderRadius: BorderRadius.circular(14),
          boxShadow: !enabled
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: fg, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
      ),
      ),
    );
  }
}

class _OutlinedDuoButton extends StatefulWidget {
  const _OutlinedDuoButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  State<_OutlinedDuoButton> createState() => _OutlinedDuoButtonState();
}

class _OutlinedDuoButtonState extends State<_OutlinedDuoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              HapticFeedback.selectionClick();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderStrong, width: 1),
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textPrimary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: AppColors.textPrimary, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.blue;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: c,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact gem-style pill for top status bars.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A task row: coloured icon tile, title + tag, points hint and a round check.
/// Completing it plays a sound, a haptic tap and a small burst with "+points".
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.title,
    required this.isCompleted,
    required this.onChanged,
    this.isFoundation = false,
    this.points,
    this.groupTask = false,
  });

  final String title;
  final bool isCompleted;
  final ValueChanged<bool?>? onChanged;
  final bool isFoundation;

  /// Points shown before completing, and floated up in the burst.
  final int? points;

  /// Inside a group: admin-set tasks read "Group task", the member's own read "My task".
  final bool groupTask;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(covariant TaskTile old) {
    super.didUpdateWidget(old);
    if (!old.isCompleted && widget.isCompleted) {
      _fx.forward(from: 0);
      HapticFeedback.mediumImpact();
      SoundService.instance.playTask();
    }
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.isCompleted;
    final accent = widget.isFoundation ? AppColors.goldDepth : AppColors.teal;
    final canTap = widget.onChanged != null && !done;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canTap ? () => widget.onChanged!(true) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: done ? accent.withValues(alpha: 0.35) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: done ? 0.08 : 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.groupTask && widget.isFoundation
                        ? Icons.groups_rounded
                        : (widget.isFoundation
                            ? Icons.wb_sunny_rounded
                            : Icons.task_alt_rounded),
                    size: 22,
                    color: accent.withValues(alpha: done ? 0.55 : 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textSecondary,
                          color: done ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                        child: Text(widget.title),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.groupTask
                            ? (widget.isFoundation ? 'Group task' : 'My task')
                            : (widget.isFoundation ? 'Foundation' : 'Personal'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!done && widget.points != null) ...[
                  Text(
                    '+${widget.points}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else
                  const SizedBox(width: 6),
                _CheckCircle(done: done, color: accent),
              ],
            ),
          ),
        ),
        Positioned.fill(
          bottom: 10,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _fx,
              builder: (_, __) => _fx.isDismissed
                  ? const SizedBox.shrink()
                  : CustomPaint(
                      painter: _BurstPainter(
                        progress: _fx.value,
                        label: widget.points == null ? null : '+${widget.points}',
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done, required this.color});

  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? color : Colors.transparent,
        border: Border.all(
          color: done ? color : AppColors.borderStrong,
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: done ? 1 : 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.elasticOut,
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
      ),
    );
  }
}

/// Ring + confetti dots around the check circle, and a "+points" label that
/// floats up and fades.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, this.label});

  final double progress;
  final String? label;

  static final _colors = [
    AppColors.orange,
    AppColors.teal,
    AppColors.gold,
    AppColors.success,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 29, size.height / 2);
    final t = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      15 + 26 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * fade
        ..color = AppColors.teal.withValues(alpha: 0.5 * fade),
    );

    const count = 12;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (i.isEven ? 0.15 : -0.15);
      final distance = 14 + (i.isEven ? 40 : 28) * t;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        p,
        (i.isEven ? 3.4 : 2.4) * fade,
        Paint()..color = _colors[i % _colors.length].withValues(alpha: fade),
      );
    }

    final text = label;
    if (text != null) {
      final labelFade = progress < 0.65 ? 1.0 : ((1 - progress) / 0.35).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.orange.withValues(alpha: labelFade),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width - 26, center.dy - tp.height / 2 - 30 * t),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, size: 38, color: AppColors.orange),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.9, 0.9)),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 28), action!],
          ],
        ),
      ),
    );
  }
}

/// Day path with circular nodes.
class ProgressPath extends StatelessWidget {
  const ProgressPath({
    super.key,
    required this.currentDay,
    required this.totalDays,
    this.maxVisible = 7,
  });

  final int currentDay;
  final int totalDays;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final total = totalDays.clamp(1, 30);
    final start = math.max(1, currentDay - (maxVisible ~/ 2));
    final end = math.min(total, start + maxVisible - 1);
    final days = [for (var d = start; d <= end; d++) d];

    return SizedBox(
      height: 86,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 22),
                  decoration: BoxDecoration(
                    color: days[i] <= currentDay
                        ? AppColors.teal
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            _DayNode(
              day: days[i],
              isComplete: days[i] < currentDay,
              isCurrent: days[i] == currentDay,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayNode extends StatelessWidget {
  const _DayNode({
    required this.day,
    required this.isComplete,
    required this.isCurrent,
  });

  final int day;
  final bool isComplete;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color depth;
    final Color fg;

    if (isComplete) {
      fill = AppColors.teal;
      depth = AppColors.tealDepth;
      fg = Colors.white;
    } else if (isCurrent) {
      fill = AppColors.gold;
      depth = AppColors.goldDepth;
      fg = AppColors.navy;
    } else {
      fill = AppColors.surface;
      depth = AppColors.borderStrong;
      fg = AppColors.muted;
    }

    Widget node = Column(
      children: [
        Container(
          width: isCurrent ? 52 : 44,
          height: isCurrent ? 52 : 44,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border(
              bottom: BorderSide(color: depth, width: isCurrent ? 5 : 4),
              left: BorderSide(color: depth, width: 1),
              right: BorderSide(color: depth, width: 1),
              top: BorderSide(color: depth, width: 1),
            ),
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                : Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCurrent ? 18 : 15,
                      color: fg,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isCurrent ? 'TODAY' : 'DAY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isCurrent ? AppColors.orange : AppColors.muted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );

    if (isCurrent) {
      node = node
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.06, 1.06),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }
    return node;
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Circular day progress ring from the mockup (Day X / total).
class DayProgressRing extends StatelessWidget {
  const DayProgressRing({
    super.key,
    required this.currentDay,
    required this.totalDays,
    this.size = 160,
  });

  final int currentDay;
  final int totalDays;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = (currentDay / totalDays.clamp(1, 999)).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: AppColors.borderStrong,
              color: AppColors.orange,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Day $currentDay',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '/ $totalDays',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple mountain path illustration for landing (mockup style).
class MountainPathArt extends StatelessWidget {
  const MountainPathArt({super.key, this.height = 180});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _MountainPainter()),
    );
  }
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.orangeSoft, AppColors.background],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final back = Path()
      ..moveTo(0, size.height * 0.72)
      ..lineTo(size.width * 0.28, size.height * 0.38)
      ..lineTo(size.width * 0.52, size.height * 0.62)
      ..lineTo(size.width * 0.78, size.height * 0.28)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFFFFD4C2));

    final mid = Path()
      ..moveTo(0, size.height * 0.82)
      ..lineTo(size.width * 0.35, size.height * 0.48)
      ..lineTo(size.width * 0.58, size.height * 0.7)
      ..lineTo(size.width * 0.85, size.height * 0.42)
      ..lineTo(size.width, size.height * 0.68)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mid, Paint()..color = AppColors.orange.withValues(alpha: 0.55));

    final pathPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final trail = Path()
      ..moveTo(size.width * 0.18, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.7,
        size.width * 0.48,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.45,
        size.width * 0.72,
        size.height * 0.32,
      );
    canvas.drawPath(trail, pathPaint);

    // Flag at peak
    final flagX = size.width * 0.72;
    final flagY = size.height * 0.28;
    canvas.drawCircle(Offset(flagX, flagY), 10, Paint()..color = AppColors.gold);
    canvas.drawCircle(Offset(flagX, flagY), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Burst celebration overlay matching the mockup success screen.
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({
    super.key,
    required this.onDismiss,
    this.title = 'All tasks completed!',
    this.subtitle = '+5 HP',
  });

  final VoidCallback onDismiss;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Stack(
        children: [
          ...List.generate(28, (i) {
            final rnd = math.Random(i * 31);
            final colors = [
              AppColors.teal,
              AppColors.orange,
              AppColors.gold,
              AppColors.blue,
              AppColors.success,
            ];
            final left = rnd.nextDouble() * size.width;
            return Positioned(
              left: left,
              top: -20,
              child: Container(
                width: 8 + rnd.nextDouble() * 10,
                height: 10 + rnd.nextDouble() * 14,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              )
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .moveY(
                    begin: 0,
                    end: size.height * (0.55 + rnd.nextDouble() * 0.4),
                    duration: (900 + rnd.nextInt(900)).ms,
                    curve: Curves.easeIn,
                  )
                  .rotate(begin: 0, end: rnd.nextDouble() * 2 - 1)
                  .fadeOut(delay: 700.ms, duration: 500.ms),
            );
          }),
          Center(
            child: SoftCard(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, Color(0xFFFFE08A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.2, 0.2),
                        curve: Curves.elasticOut,
                        duration: 900.ms,
                      )
                      .then()
                      .shake(hz: 2, duration: 400.ms),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(delay: 280.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Awesome!', onPressed: onDismiss),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, end: 0),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

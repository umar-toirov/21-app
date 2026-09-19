import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Floating ILM HUB emblem with subtle 3D bob + tilt.
class BrandMascot extends StatelessWidget {
  const BrandMascot({
    super.key,
    this.size = 140,
    this.variant = BrandLogoVariant.color,
    this.floating = true,
  });

  final double size;
  final BrandLogoVariant variant;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    Widget child = BrandLogo(size: size, variant: variant);

    if (!floating) return child;

    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -8, duration: 1600.ms, curve: Curves.easeInOut)
        .rotate(
          begin: -0.03,
          end: 0.03,
          duration: 2200.ms,
          curve: Curves.easeInOut,
        );
  }
}

enum BrandLogoVariant { color, gold, onBlue, full, fullDark, auth }

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 120,
    this.variant = BrandLogoVariant.color,
  });

  final double size;
  final BrandLogoVariant variant;

  String get _asset {
    switch (variant) {
      case BrandLogoVariant.gold:
        return 'assets/brand/icon_gold.png';
      case BrandLogoVariant.onBlue:
        return 'assets/brand/icon_on_blue.png';
      case BrandLogoVariant.full:
      case BrandLogoVariant.auth:
        return 'assets/brand/logo_auth.png';
      case BrandLogoVariant.fullDark:
        return 'assets/brand/logo_auth.png';
      case BrandLogoVariant.color:
        return 'assets/brand/icon.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFull = variant == BrandLogoVariant.full ||
        variant == BrandLogoVariant.fullDark ||
        variant == BrandLogoVariant.auth;
    return Image.asset(
      _asset,
      height: size,
      width: isFull ? size * 2.6 : size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Duolingo-style 3D button with pressable depth edge.
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
    final depth = widget.depthColor ?? AppColors.orangeDepth;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        height: 56,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: enabled ? color : AppColors.muted,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            bottom: BorderSide(
              color: enabled ? depth : AppColors.borderStrong,
              width: _pressed ? 0 : 5,
            ),
            left: BorderSide(color: enabled ? depth : AppColors.borderStrong, width: 0.5),
            right: BorderSide(color: enabled ? depth : AppColors.borderStrong, width: 0.5),
            top: BorderSide(color: enabled ? depth : AppColors.borderStrong, width: 0.5),
          ),
          boxShadow: _pressed || !enabled
              ? null
              : [
                  BoxShadow(
                    color: depth.withValues(alpha: 0.35),
                    blurRadius: 0,
                    offset: const Offset(0, 4),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        height: 56,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderStrong,
            width: _pressed ? 2 : 2.5,
          ),
          boxShadow: _pressed
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.borderStrong,
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.blue),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: AppColors.blue, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.border, offset: Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: c,
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.title,
    required this.isCompleted,
    required this.onChanged,
    this.isFoundation = false,
  });

  final String title;
  final bool isCompleted;
  final ValueChanged<bool?>? onChanged;
  final bool isFoundation;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  @override
  Widget build(BuildContext context) {
    final done = widget.isCompleted;
    return GestureDetector(
      onTap: widget.onChanged == null || done
          ? null
          : () => widget.onChanged!(true),
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: done ? AppColors.teal.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: done
                ? AppColors.teal
                : widget.isFoundation
                    ? AppColors.gold.withValues(alpha: 0.7)
                    : AppColors.borderStrong,
            width: 2.5,
          ),
          boxShadow: done
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: 200.ms,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done ? AppColors.teal : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? AppColors.teal : AppColors.borderStrong,
                  width: 3,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isFoundation ? 'FOUNDATION' : 'PERSONAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: widget.isFoundation ? AppColors.goldDepth : AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(target: done ? 1 : 0).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.01, 1.01),
          duration: 180.ms,
        );
  }
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
            const BrandMascot(size: 110, floating: false)
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.85, 0.85)),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
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

/// Duolingo-style day path with circular nodes.
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
                      fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w800,
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
        border: Border.all(color: borderColor ?? AppColors.border, width: 1.5),
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '/ $totalDays',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF0E8), Color(0xFFF7F8FA)],
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
                      fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

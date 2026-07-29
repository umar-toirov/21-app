import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Sticky Duolingo-style resource bar (streak / HP / XP).
class DuoTopBar extends StatelessWidget {
  const DuoTopBar({
    super.key,
    required this.streak,
    required this.hp,
    required this.score,
    this.onProfileTap,
  });

  final int streak;
  final int hp;
  final int score;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderStrong, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _Gem(
            icon: Icons.local_fire_department_rounded,
            value: '$streak',
            color: AppColors.orange,
            glow: const Color(0xFFFFE0D1),
          ),
          const SizedBox(width: 10),
          _Gem(
            icon: Icons.favorite_rounded,
            value: '$hp',
            color: AppColors.hp,
            glow: const Color(0xFFFFE0E0),
          ),
          const SizedBox(width: 10),
          _Gem(
            icon: Icons.bolt_rounded,
            value: '$score',
            color: AppColors.goldDepth,
            glow: const Color(0xFFFFF3D0),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.teal, AppColors.blue],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _Gem extends StatelessWidget {
  const _Gem({
    required this.icon,
    required this.value,
    required this.color,
    required this.glow,
  });

  final IconData icon;
  final String value;
  final Color color;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: glow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 5),
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

/// Colored unit/section banner like Duolingo.
class UnitBanner extends StatelessWidget {
  const UnitBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.color = AppColors.orange,
    this.depthColor = AppColors.orangeDepth,
    this.progress = 0,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Color depthColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, depthColor, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: depthColor.withValues(alpha: 0.45),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

enum PathNodeState { locked, current, complete }

/// Duolingo-style zig-zag learning path of day nodes.
class DuoLearningPath extends StatelessWidget {
  const DuoLearningPath({
    super.key,
    required this.currentDay,
    required this.totalDays,
    this.onDayTap,
    this.mascotSide = true,
  });

  final int currentDay;
  final int totalDays;
  final ValueChanged<int>? onDayTap;
  final bool mascotSide;

  @override
  Widget build(BuildContext context) {
    final days = totalDays.clamp(1, 30);
    // Show a window around current day for performance/UX
    final start = math.max(1, currentDay - 3);
    final end = math.min(days, math.max(currentDay + 5, start + 7));

    return Column(
      children: [
        for (var day = start; day <= end; day++) ...[
          _PathRow(
            day: day,
            state: day < currentDay
                ? PathNodeState.complete
                : day == currentDay
                    ? PathNodeState.current
                    : PathNodeState.locked,
            alignRight: day.isEven,
            showMascot: mascotSide && day == currentDay,
            onTap: onDayTap,
          ),
          if (day < end)
            _PathConnector(
              alignRight: day.isEven,
              complete: day < currentDay,
            ),
        ],
      ],
    );
  }
}

class _PathConnector extends StatelessWidget {
  const _PathConnector({required this.alignRight, required this.complete});
  final bool alignRight;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        painter: _ConnectorPainter(alignRight: alignRight, complete: complete),
        size: Size(MediaQuery.sizeOf(context).width, 28),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.alignRight, required this.complete});
  final bool alignRight;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = complete ? AppColors.success : AppColors.borderStrong
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = alignRight ? size.width * 0.68 : size.width * 0.32;
    final endX = alignRight ? size.width * 0.32 : size.width * 0.68;
    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(startX, 14, endX, 14, endX, 28);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.alignRight != alignRight || oldDelegate.complete != complete;
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.day,
    required this.state,
    required this.alignRight,
    required this.showMascot,
    this.onTap,
  });

  final int day;
  final PathNodeState state;
  final bool alignRight;
  final bool showMascot;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final node = PathLessonNode(
      day: day,
      state: state,
      onTap: () => onTap?.call(day),
    );

    final children = <Widget>[
      if (showMascot && !alignRight) ...[
        const BrandMascot(size: 78, variant: BrandLogoVariant.color),
        const SizedBox(width: 8),
      ],
      if (alignRight) const Spacer(),
      node,
      if (!alignRight) const Spacer(),
      if (showMascot && alignRight) ...[
        const SizedBox(width: 8),
        const BrandMascot(size: 78, variant: BrandLogoVariant.color),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: children),
    );
  }
}

/// Big 3D circular lesson node.
class PathLessonNode extends StatefulWidget {
  const PathLessonNode({
    super.key,
    required this.day,
    required this.state,
    this.onTap,
    this.showStartLabel = true,
  });

  final int day;
  final PathNodeState state;
  final VoidCallback? onTap;
  final bool showStartLabel;

  @override
  State<PathLessonNode> createState() => _PathLessonNodeState();
}

class _PathLessonNodeState extends State<PathLessonNode> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color depth;
    final Widget face;

    switch (widget.state) {
      case PathNodeState.complete:
        fill = AppColors.success;
        depth = const Color(0xFF16A34A);
        face = const Icon(Icons.check_rounded, color: Colors.white, size: 36);
      case PathNodeState.current:
        fill = AppColors.orange;
        depth = AppColors.orangeDepth;
        face = Text(
          '${widget.day}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
        );
      case PathNodeState.locked:
        fill = const Color(0xFFE8ECF1);
        depth = const Color(0xFFC5CDD8);
        face = Icon(Icons.lock_rounded, color: AppColors.muted.withValues(alpha: 0.9), size: 30);
    }

    final interactive = widget.state != PathNodeState.locked;

    Widget node = GestureDetector(
      onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: interactive
          ? (_) {
              setState(() => _pressed = false);
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 5 : 0, 0),
        width: widget.state == PathNodeState.current ? 88 : 78,
        height: widget.state == PathNodeState.current ? 88 : 78,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border(
            bottom: BorderSide(color: depth, width: _pressed ? 2 : 7),
            left: BorderSide(color: depth, width: 2),
            right: BorderSide(color: depth, width: 2),
            top: BorderSide(color: depth, width: 2),
          ),
          boxShadow: widget.state == PathNodeState.current && !_pressed
              ? [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: face,
      ),
    );

    if (widget.state == PathNodeState.current && widget.showStartLabel) {
      node = Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderStrong, width: 2.5),
              boxShadow: const [
                BoxShadow(color: AppColors.borderStrong, offset: Offset(0, 3), blurRadius: 0),
              ],
            ),
            child: const Text(
              'START',
              style: TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -4, duration: 900.ms),
          node
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1000.ms,
                curve: Curves.easeInOut,
              ),
        ],
      );
    }

    return node;
  }
}

/// Bottom task sheet card for current day (Duolingo lesson panel feel).
class TodayLessonPanel extends StatelessWidget {
  const TodayLessonPanel({
    super.key,
    required this.mission,
    required this.tasks,
    required this.onToggle,
  });

  final String mission;
  final List<({String id, String title, bool done, bool foundation})> tasks;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.done).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderStrong, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
          const BoxShadow(
            color: AppColors.borderStrong,
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$done/${tasks.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mission,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: tasks.isEmpty ? 0 : done / tasks.length,
              minHeight: 12,
              backgroundColor: AppColors.borderStrong,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 14),
          ...tasks.map(
            (t) => TaskTile(
              title: t.title,
              isCompleted: t.done,
              isFoundation: t.foundation,
              onChanged: t.done ? null : (_) => onToggle(t.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative ambient blobs for backgrounds.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF7F2),
                  Color(0xFFF7F8FA),
                  Color(0xFFEEF9F8),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: _Blob(color: AppColors.orange.withValues(alpha: 0.12), size: 160),
        ),
        Positioned(
          top: 180,
          left: -50,
          child: _Blob(color: AppColors.teal.withValues(alpha: 0.12), size: 140),
        ),
        Positioned(
          bottom: 120,
          right: -20,
          child: _Blob(color: AppColors.gold.withValues(alpha: 0.15), size: 120),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          duration: 3200.ms,
        );
  }
}

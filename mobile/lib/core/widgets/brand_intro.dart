import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Plays the ILM HUB brand intro once per app launch, then reveals [child].
///
/// The background matches the native Android splash so the hand-off from the
/// OS launch screen to Flutter has no flash. Tap anywhere to skip.
class BrandIntroGate extends StatefulWidget {
  const BrandIntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<BrandIntroGate> createState() => _BrandIntroGateState();
}

class _BrandIntroGateState extends State<BrandIntroGate> {
  static bool _played = false;

  static const _hold = Duration(milliseconds: 1900);
  static const _fade = Duration(milliseconds: 320);

  late bool _showing = !_played;
  bool _leaving = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_showing) {
      _played = true;
      _timer = Timer(_hold, _dismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || _leaving) return;
    _timer?.cancel();
    setState(() => _leaving = true);
    Timer(_fade, () {
      if (mounted) setState(() => _showing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showing)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: AnimatedOpacity(
                opacity: _leaving ? 0 : 1,
                duration: _fade,
                curve: Curves.easeOut,
                child: const _IntroScene(),
              ),
            ),
          ),
      ],
    );
  }
}

class _IntroScene extends StatelessWidget {
  const _IntroScene();

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final bg = dark ? const Color(0xFF0C0D10) : Colors.white;
    final wordmark = dark ? const Color(0xFFF2F3F6) : const Color(0xFF1E3A8A);
    final sub = dark ? const Color(0xFF9A9EAB) : const Color(0xFF70737F);

    return ColoredBox(
      color: bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/emblem.png',
                height: 132,
                filterQuality: FilterQuality.high,
              )
                  .animate()
                  .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 26),
              Text(
                'ILM HUB',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 7,
                  color: wordmark,
                ),
              )
                  .animate(delay: 380.ms)
                  .fadeIn(duration: 420.ms)
                  .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(3),
                ),
              )
                  .animate(delay: 640.ms)
                  .fadeIn(duration: 300.ms)
                  .scaleX(begin: 0, end: 1, duration: 420.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              Text(
                'Discipline today, success tomorrow',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: sub,
                ),
              ).animate(delay: 820.ms).fadeIn(duration: 480.ms),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/env.dart';

/// Brand navy: the same colour as the native Android launch screen, so the
/// hand-off from the OS splash to this intro has no flash.
const kBrandNavy = Color(0xFF033D95);

/// Plays a short intro once per app launch, then reveals [child].
///
/// Shows the app icon, its name and a "Made by ILM HUB" credit. Tap to skip.
class BrandIntroGate extends StatefulWidget {
  const BrandIntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<BrandIntroGate> createState() => _BrandIntroGateState();
}

class _BrandIntroGateState extends State<BrandIntroGate> {
  static bool _played = false;

  static const _hold = Duration(milliseconds: 1600);
  static const _fade = Duration(milliseconds: 280);

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
                child: const BrandIntroScene(),
              ),
            ),
          ),
      ],
    );
  }
}

class BrandIntroScene extends StatelessWidget {
  const BrandIntroScene({super.key});

  @override
  Widget build(BuildContext context) {
    // This sits above the app's Navigator, so it needs its own Material for
    // text to pick up the theme (otherwise Flutter shows a debug underline).
    return Material(
      color: kBrandNavy,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/brand/app_glyph.png',
                      width: 150,
                      height: 150,
                      filterQuality: FilterQuality.high,
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .scale(
                          begin: const Offset(0.86, 0.86),
                          end: const Offset(1, 1),
                          duration: 650.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 22),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppConfig.appName,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 38,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: Colors.white,
                        ),
                      ),
                    ).animate(delay: 250.ms).fadeIn(duration: 380.ms).slideY(
                          begin: 0.25,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 10),
                    const Text(
                      'Discipline today, success tomorrow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xCCFFFFFF),
                      ),
                    ).animate(delay: 450.ms).fadeIn(duration: 400.ms),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Made by ', style: TextStyle(color: Color(0x99FFFFFF))),
                    TextSpan(
                      text: 'ILM HUB',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }
}

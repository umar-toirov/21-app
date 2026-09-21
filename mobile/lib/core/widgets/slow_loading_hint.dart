import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A spinner that, if loading drags on, explains why. The free API host sleeps
/// when idle and can take up to a minute to wake, which otherwise looks broken.
class SlowLoadingHint extends StatefulWidget {
  const SlowLoadingHint({super.key, this.label});

  final String? label;

  @override
  State<SlowLoadingHint> createState() => _SlowLoadingHintState();
}

class _SlowLoadingHintState extends State<SlowLoadingHint> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.orange),
            if (widget.label != null) ...[
              const SizedBox(height: 18),
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            AnimatedOpacity(
              opacity: _slow ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Waking up the server. This can take up to a minute the first time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

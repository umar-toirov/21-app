import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Plain screen background (kept as a widget so callers stay unchanged).
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.background, child: child);
  }
}

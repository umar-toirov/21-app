import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  int _indexFromLocation(String location) {
    if (location.contains('/groups')) return 1;
    if (location.contains('/statistics')) return 3;
    if (location.contains('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomAppBar(
        elevation: 12,
        color: AppColors.surface,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: index == 0,
                onTap: () => context.go(AppRoutes.home),
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Groups',
                selected: index == 1,
                onTap: () => context.go('${AppRoutes.home}/groups'),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                selected: index == 3,
                onTap: () => context.go('${AppRoutes.home}/statistics'),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: index == 4,
                onTap: () => context.go('${AppRoutes.home}/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? AppColors.orange : AppColors.muted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.orange : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/env.dart';
import 'core/providers/providers.dart';
import 'core/router/app_router.dart';
import 'core/services/reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/brand_intro.dart';

const _themePrefKey = 'theme_mode';

/// Loaded in main() before runApp so the first frame already has the right theme.
ThemeMode initialThemeMode = ThemeMode.system;

Future<void> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    initialThemeMode = switch (prefs.getString(_themePrefKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  } catch (_) {}
}

final themeModeProvider = StateProvider<ThemeMode>((ref) => initialThemeMode);

/// Updates the theme instantly and remembers it for next launch.
Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  ref.read(themeModeProvider.notifier).state = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, mode.name);
  } catch (_) {}
}

final _authRefreshProvider = Provider<AuthRefreshNotifier>((ref) {
  final notifier = AuthRefreshNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRefreshProvider);
  return createRouter(refreshListenable: refresh);
});

class IlmModeApp extends ConsumerStatefulWidget {
  const IlmModeApp({super.key});

  @override
  ConsumerState<IlmModeApp> createState() => _IlmModeAppState();
}

class _IlmModeAppState extends ConsumerState<IlmModeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Follow the phone's light/dark switch while in "System" mode.
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // Keep the daily reminders in step with the profile's Notifications switch.
    ref.listen(profileProvider, (_, next) {
      final profile = next.valueOrNull;
      if (profile != null) {
        ReminderService.instance.sync(enabled: profile.notificationsEnabled);
      }
    });

    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformDark);

    // AppColors resolves surfaces/text against this flag.
    AppColors.isDark = isDark;

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      // New key on every flip rebuilds the whole tree once, so every widget
      // re-reads AppColors immediately.
      builder: (context, child) => BrandIntroGate(
        child: KeyedSubtree(
          key: ValueKey(isDark),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

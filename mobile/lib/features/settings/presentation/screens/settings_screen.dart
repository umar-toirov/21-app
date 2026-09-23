import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/widgets/how_it_works.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _SectionLabel('Appearance'),
            SoftCard(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 18),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 18),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    final mode = s.first;
                    setThemeMode(ref, mode);
                    // Fire and forget: the UI never waits on the network.
                    ref
                        .read(apiRepositoryProvider)
                        .updateProfile({'dark_mode': mode == ThemeMode.dark})
                        .then<void>((_) {}, onError: (_) {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('General'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: const Text('Notifications'),
                    value: profile.notificationsEnabled,
                    onChanged: (v) async {
                      HapticFeedback.selectionClick();
                      // Sync the device's reminders directly (don't just wait on
                      // app.dart's listener) so we can tell the user if the OS
                      // denied notification permission — otherwise the switch
                      // turns on but nothing is ever scheduled, silently.
                      final ok = await ReminderService.instance.sync(enabled: v);
                      await ref
                          .read(apiRepositoryProvider)
                          .updateProfile({'notifications_enabled': v});
                      ref.invalidate(profileProvider);
                      if (v && !ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            content: Text(
                              "Couldn't turn on reminders. Check notification "
                              'permission for this app in your phone settings.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ));
                      }
                    },
                  ),
                  ),
                  const _Hairline(),
                  Material(
                    type: MaterialType.transparency,
                    child: StatefulBuilder(
                      builder: (context, setLocal) => SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        title: const Text('Sounds'),
                        subtitle: Text(
                          'Play a sound when you finish a task',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        value: SoundService.instance.enabled,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          SoundService.instance.setEnabled(v);
                          setLocal(() {});
                        },
                      ),
                    ),
                  ),
                  const _Hairline(),
                  _NavRow(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    value: profile.locale == 'uz' ? "O'zbekcha" : 'English',
                    onTap: () => _pickLanguage(context, ref, profile.locale),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('About'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'How it works',
                    onTap: () => showHowItWorks(context),
                  ),
                  const _Hairline(),
                  _NavRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Support',
                    onTap: () => _showInfo(
                      context,
                      'Support',
                      'Questions or feedback? Reach the ILM HUB team using the '
                          'contact details on our website. Include your account '
                          'email so we can help faster.',
                    ),
                  ),
                  const _Hairline(),
                  _NavRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About Habit Zone',
                    onTap: () => _showInfo(
                      context,
                      'About Habit Zone',
                      'Habit Zone is a discipline app by ILM HUB. Complete your daily '
                          'tasks, keep your streak and grow with a group. '
                          'Challenges are free.',
                    ),
                  ),
                  const _Hairline(),
                  _NavRow(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => _showInfo(
                      context,
                      'Terms of Service',
                      'By using Habit Zone you agree to use it respectfully and to keep '
                          'your account secure. Groups are for accountability and '
                          'encouragement; be kind in chat and to other members.',
                    ),
                  ),
                  const _Hairline(),
                  _NavRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy Policy',
                    onTap: () => _showInfo(
                      context,
                      'Privacy Policy',
                      'We store your profile and progress to run the app. We do '
                          'not sell your data. You can delete your account at '
                          'any time and your data is removed after 30 days.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('Account'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    showChevron: false,
                    onTap: () async {
                      await ref.read(apiRepositoryProvider).signOut();
                      if (context.mounted) context.go(AppRoutes.landing);
                    },
                  ),
                  const _Hairline(),
                  _NavRow(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete account',
                    danger: true,
                    showChevron: false,
                    onTap: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(
      BuildContext context, WidgetRef ref, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in const [('en', 'English'), ('uz', "O'zbekcha")])
              ListTile(
                title: Text(o.$2),
                trailing: current == o.$1
                    ? const Icon(Icons.check_rounded, color: AppColors.orange)
                    : null,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await ref.read(apiRepositoryProvider).updateProfile({'locale': picked});
    ref.invalidate(profileProvider);
  }

  void _showInfo(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This cannot be undone. Your data will be deleted after 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(dioProvider).delete('/me');
    await ref.read(apiRepositoryProvider).signOut();
    if (context.mounted) context.go(AppRoutes.landing);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: AppColors.border,
      );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? value;
  final bool danger;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon,
                size: 22, color: danger ? color : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (value != null)
              Text(value!,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) => ListView(
          children: [
            SwitchListTile(
              title: const Text('Notifications'),
              value: profile.notificationsEnabled,
              onChanged: (v) async {
                await ref.read(apiRepositoryProvider).updateProfile({'notifications_enabled': v});
                ref.invalidate(profileProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: profile.darkMode,
              onChanged: (v) async {
                await ref.read(apiRepositoryProvider).updateProfile({'dark_mode': v});
                ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
                ref.invalidate(profileProvider);
              },
            ),
            ListTile(title: const Text('Language'), subtitle: Text(profile.locale == 'uz' ? 'Uzbek' : 'English'), trailing: const Icon(Icons.chevron_right)),
            const Divider(),
            const ListTile(title: Text('Support'), trailing: Icon(Icons.chevron_right)),
            const ListTile(title: Text('About 21'), trailing: Icon(Icons.chevron_right)),
            const ListTile(title: Text('Terms of Service'), trailing: Icon(Icons.chevron_right)),
            const ListTile(title: Text('Privacy Policy'), trailing: Icon(Icons.chevron_right)),
            const Divider(),
            ListTile(
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text('This action cannot be undone. Your data will be deleted after 30 days.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final dio = ref.read(dioProvider);
                  await dio.delete('/me');
                  await ref.read(apiRepositoryProvider).signOut();
                  if (context.mounted) context.go(AppRoutes.landing);
                }
              },
            ),
            ListTile(
              title: const Text('Sign Out'),
              onTap: () async {
                await ref.read(apiRepositoryProvider).signOut();
                if (context.mounted) context.go(AppRoutes.landing);
              },
            ),
          ],
        ),
      ),
    );
  }
}

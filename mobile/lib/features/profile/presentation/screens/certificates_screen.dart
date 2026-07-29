import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (certs) {
          if (certs.isEmpty) {
            return const Center(child: Text('Complete a challenge to earn your first certificate'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final c = certs[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium, color: AppColors.accent, size: 40),
                  title: Text(c.title),
                  subtitle: Text('#${c.certificateNo} · ${c.durationDays} days'),
                  trailing: const Icon(Icons.share_outlined),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/packs/pack_config.dart';
import '../library/library_providers.dart';
import 'pack_install_notifier.dart';

/// Download / update icon packs.
class DownloaderScreen extends ConsumerWidget {
  const DownloaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installMap = ref.watch(packInstallProvider);
    final packsAsync = ref.watch(packsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download packs'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: supportedPacks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pulls the latest release from GitHub (zipball), extracts into your '
                  'XDG data directory, and indexes SVG paths into SQLite.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
              ],
            );
          }

          final config = supportedPacks[index - 1];
          final install = installMap[config.slug] ?? const PackInstallState();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            config.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        packsAsync.when(
                          data: (packs) {
                            final matches = packs.where((e) => e.name == config.name);
                            final installedGroup = matches.isEmpty ? null : matches.first;
                            if (installedGroup == null) {
                              return const Text('Not installed');
                            }
                            return Text(
                              '${installedGroup.version} · ${installedGroup.iconCount} icons',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (e, st) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'github.com/${config.owner}/${config.repo}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    if (install.busy) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: install.progress),
                      const SizedBox(height: 8),
                      Text(
                        install.progressLabel ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (install.error != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            install.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: install.busy
                              ? null
                              : () => ref.read(packInstallProvider.notifier).install(config),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download / update'),
                        ),
                        const SizedBox(width: 12),
                        if (install.busy)
                          OutlinedButton(
                            onPressed: () => ref.read(packInstallProvider.notifier).cancel(config.slug),
                            child: const Text('Cancel'),
                          ),
                        if (install.error != null && !install.busy)
                          TextButton(
                            onPressed: () =>
                                ref.read(packInstallProvider.notifier).clearError(config.slug),
                            child: const Text('Dismiss'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

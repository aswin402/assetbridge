import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

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

    // Filter out supported packs from the install map to find custom/local ones in progress
    final customSlugs = installMap.keys.where((slug) => !supportedPacks.any((p) => p.slug == slug)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download packs'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLocalDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add local pack'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: supportedPacks.length + customSlugs.length + 1,
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

          final isFixedPack = index <= supportedPacks.length;
          final PackConfig config;
          if (isFixedPack) {
            config = supportedPacks[index - 1];
          } else {
            final slug = customSlugs[index - supportedPacks.length - 1];
            // We don't have the full config for custom packs yet, so we mock it for the UI
            config = PackConfig(name: slug, slug: slug);
          }

          final install = installMap[config.slug] ?? const PackInstallState();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    packsAsync.when(
                      data: (packs) {
                        final matches = packs.where((e) => e.name == config.name || e.id.toString() == config.slug);
                        final installedGroup = matches.isEmpty ? null : matches.first;

                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                config.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (installedGroup == null)
                              const Text('Not installed')
                            else
                              Text(
                                '${installedGroup.version} · ${installedGroup.iconCount} icons',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        );
                      },
                      loading: () => Row(
                        children: [
                          Expanded(
                            child: Text(
                              config.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      error: (e, st) => Row(
                        children: [
                          Expanded(
                            child: Text(
                              config.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (config.owner != null && config.repo != null)
                      Text(
                        'github.com/${config.owner}/${config.repo}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      )
                    else
                      Text(
                        'Local pack',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
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
                        if (isFixedPack)
                          FilledButton.icon(
                            onPressed: install.busy
                                ? null
                                : () => ref.read(packInstallProvider.notifier).install(config),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Download / update'),
                          ),
                        const SizedBox(width: 12),
                        packsAsync.maybeWhen(
                          data: (packs) {
                            final matches = packs.where((e) => e.name == config.name || e.id.toString() == config.slug);
                            if (matches.isNotEmpty && !install.busy) {
                              return TextButton.icon(
                                onPressed: () => _confirmDelete(context, ref, config.name, config.slug),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String name, String slug) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: Text('This will remove "$name" and all its icons from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(packInstallProvider.notifier).delete(name, slug);
    }
  }

  Future<void> _showAddLocalDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    final prefixController = TextEditingController();
    bool isUiKit = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add local pack'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Pack name',
                  hintText: 'e.g. My Custom Icons',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'File Path (ZIP or Sketch)',
                  hintText: '/path/to/icons.zip or design.sketch',
                ),
                readOnly: true,
              ),
              IconButton(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['zip', 'sketch'],
                  );
                  if (result != null && result.files.single.path != null) {
                    pathController.text = result.files.single.path!;
                    if (nameController.text.isEmpty) {
                      nameController.text = result.files.single.name
                          .replaceFirst('.zip', '')
                          .replaceFirst('.sketch', '');
                    }
                    if (result.files.single.name.toLowerCase().endsWith('.sketch')) {
                      setState(() => isUiKit = true);
                    }
                  }
                },
                icon: const Icon(Icons.file_open),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: prefixController,
                decoration: const InputDecoration(
                  labelText: 'Subdirectory (optional)',
                  hintText: 'e.g. assets/svg',
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isUiKit,
                onChanged: (v) => setState(() => isUiKit = v ?? false),
                title: const Text('Treat as UI Kit'),
                subtitle: const Text('Shows in UI Kits section instead of Icon Packs'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final path = pathController.text.trim();
                if (name.isNotEmpty && path.isNotEmpty) {
                  ref.read(packInstallProvider.notifier).installLocal(
                        name: name,
                        path: path,
                        svgPathPrefix: prefixController.text.trim().isEmpty ? null : prefixController.text.trim(),
                        isUiKit: isUiKit,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

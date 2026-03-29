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
    final colorScheme = Theme.of(context).colorScheme;

    // Filter out supported packs from the install map to find custom/local ones in progress
    final customSlugs = installMap.keys
        .where((slug) => !supportedPacks.any((p) => p.slug == slug))
        .toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Manage Packs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: supportedPacks.length + customSlugs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Packs are downloaded as ZIPs from GitHub and indexed locally for instant search and drag-and-drop.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Text(
                      'AVAILABLE PACKS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAddLocalDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Local'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          }

          final isFixedPack = index <= supportedPacks.length;
          final PackConfig config;
          if (isFixedPack) {
            config = supportedPacks[index - 1];
          } else {
            final slug = customSlugs[index - supportedPacks.length - 1];
            config = PackConfig(name: slug, slug: slug);
          }

          final install = installMap[config.slug] ?? const PackInstallState();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (config.owner != null && config.repo != null)
                                Text(
                                  'github.com/${config.owner}/${config.repo}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                )
                              else
                                Text(
                                  'Local path',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.secondary.withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        packsAsync.maybeWhen(
                          data: (packs) {
                            final matches = packs.where((e) =>
                                e.name == config.name ||
                                e.id.toString() == config.slug);
                            if (matches.isNotEmpty) {
                              final p = matches.first;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${p.version} · ${p.iconCount} items',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              );
                            }
                            return const Text(
                              'Not installed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (install.busy) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: install.progress,
                          minHeight: 3,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        install.progressLabel ?? 'Processing...',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (install.error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          install.error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (isFixedPack)
                          SizedBox(
                            height: 32,
                            child: FilledButton(
                              onPressed: install.busy
                                  ? null
                                  : () => ref
                                      .read(packInstallProvider.notifier)
                                      .install(config),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text('Download / Update',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        const Spacer(),
                        if (install.busy)
                          TextButton(
                            onPressed: () => ref
                                .read(packInstallProvider.notifier)
                                .cancel(config.slug),
                            child: const Text('Cancel',
                                style: TextStyle(fontSize: 12)),
                          )
                        else ...[
                          packsAsync.maybeWhen(
                            data: (packs) {
                              final matches = packs.where((e) =>
                                  e.name == config.name ||
                                  e.id.toString() == config.slug);
                              if (matches.isNotEmpty) {
                                return IconButton(
                                  onPressed: () => _confirmDelete(
                                      context, ref, config.name, config.slug),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18),
                                  color: colorScheme.error.withValues(alpha: 0.6),
                                  tooltip: 'Delete',
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                          if (install.error != null)
                            TextButton(
                              onPressed: () => ref
                                  .read(packInstallProvider.notifier)
                                  .clearError(config.slug),
                              child: const Text('Dismiss',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String name, String slug) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: Text(
            'This will remove "$name" and all its icons from your library.'),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pathController,
                      decoration: const InputDecoration(
                        labelText: 'File Path (ZIP or Sketch)',
                        hintText: 'Select file...',
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        if (result.files.single.name
                            .toLowerCase()
                            .endsWith('.sketch')) {
                          setState(() => isUiKit = true);
                        }
                      }
                    },
                    icon: const Icon(Icons.file_open_rounded),
                  ),
                ],
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
              SwitchListTile(
                value: isUiKit,
                onChanged: (v) => setState(() => isUiKit = v),
                title: const Text('Treat as UI Kit'),
                subtitle: const Text(
                    'Shows in UI Kits section instead of Icon Packs'),
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
                        svgPathPrefix: prefixController.text.trim().isEmpty
                            ? null
                            : prefixController.text.trim(),
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


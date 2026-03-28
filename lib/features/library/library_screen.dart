import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/paths/app_paths.dart';
import '../downloader/downloader_screen.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/pack_sidebar_row.dart';
import '../../shared/widgets/search_bar.dart';
import '../downloader/pack_install_notifier.dart';
import 'library_providers.dart';

final _categories = ['All', 'Arrows', 'UI', 'Social', 'Shapes', 'More'];

String? _categoryKeyword(String chip) {
  switch (chip) {
    case 'Arrows':
      return 'arrow';
    case 'UI':
      return 'ui';
    case 'Social':
      return 'social';
    case 'Shapes':
      return 'shape';
    case 'More':
    case 'All':
      return null;
    default:
      return null;
  }
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _debouncedSearch = '';
  final Set<int> _disabledPackIds = {};
  var _selectedCategory = 'All';
  double _gridExtent = 72;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _debouncedSearch = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _confirmDeletePack(Pack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: Text('This will remove "${pack.name}" and all its icons from your library.'),
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

    if (confirmed == true && mounted) {
      final slug = pack.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-8]'), '_');
      ref.read(packInstallProvider.notifier).delete(pack.name, slug);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Asset> _filterAssets(List<Asset> rows) {
    final kw = _categoryKeyword(_selectedCategory);
    return rows.where((a) {
      if (_disabledPackIds.contains(a.packId)) return false;
      if (_debouncedSearch.isNotEmpty) {
        final q = _debouncedSearch;
        if (!a.name.toLowerCase().contains(q) && !a.tags.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (kw != null && !a.tags.toLowerCase().contains(kw)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appDatabaseProvider);
    final packsAsync = ref.watch(packsStreamProvider);
    final assetsAsync = ref.watch(allAssetsStreamProvider);

    ref.listen(packsStreamProvider, (prev, next) {
      next.whenData((packs) {
        final valid = packs.map((p) => p.id).toSet();
        final stale = _disabledPackIds.difference(valid);
        if (stale.isNotEmpty && mounted) {
          setState(() => _disabledPackIds.removeAll(stale));
        }
      });
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'AssetBridge',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: LibrarySearchBar(
                      controller: _searchController,
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 260,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'PACKS',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1.2,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: packsAsync.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: Text('$e')),
                                data: (packs) {
                                  if (packs.isEmpty) {
                                    return Text(
                                      'No packs installed.\nTap Add Pack to download Phosphor.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: packs.length,
                                    itemBuilder: (context, i) {
                                      final pack = packs[i];
                                      final enabled = !_disabledPackIds.contains(pack.id);
                                      return PackSidebarRow(
                                        title: pack.name,
                                        countLabel: '${pack.iconCount}',
                                        enabled: enabled,
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() {
                                            if (v) {
                                              _disabledPackIds.remove(pack.id);
                                            } else {
                                              _disabledPackIds.add(pack.id);
                                            }
                                          });
                                        },
                                        onDelete: () => _confirmDeletePack(pack),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (context) => const DownloaderScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Pack'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.settings_outlined, size: 18),
                              label: const Text('Settings'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final c in _categories)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: CategoryChip(
                                      label: c,
                                      selected: _selectedCategory == c,
                                      onSelected: (_) => setState(() => _selectedCategory = c),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                'Grid size',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _gridExtent,
                                  min: 48,
                                  max: 120,
                                  divisions: 12,
                                  label: '${_gridExtent.round()} px',
                                  onChanged: (v) => setState(() => _gridExtent = v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: assetsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('$e')),
                            data: (assets) {
                              final filtered = _filterAssets(assets);
                              if (assets.isEmpty) {
                                return _LibraryEmptyState(
                                  gridExtent: _gridExtent,
                                  hasPacks: packsAsync.maybeWhen(
                                    data: (p) => p.isNotEmpty,
                                    orElse: () => false,
                                  ),
                                );
                              }
                              if (filtered.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No icons match filters.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              }
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: _gridExtent,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    final a = filtered[i];
                                    return _AssetTile(
                                      asset: a,
                                      size: _gridExtent,
                                    );
                                  },
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.size});

  final Asset asset;
  final double size;

  bool get _isSvg => asset.filePath.toLowerCase().endsWith('.svg');
  bool get _isSketch => asset.filePath.toLowerCase().endsWith('.sketch');

  Future<void> _handleTap(BuildContext context) async {
    if (_isSvg) {
      await _copySvg(context);
    } else {
      await _copyPath(context);
    }
  }

  Future<void> _copySvg(BuildContext context) async {
    try {
      final content = await File(asset.filePath).readAsString();
      await Clipboard.setData(ClipboardData(text: content));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied SVG: ${asset.name}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 250,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy: $e')),
      );
    }
  }

  Future<void> _copyPath(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: asset.filePath));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied path: ${asset.name}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 250,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(asset.filePath);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleTap(context),
        onSecondaryTapDown: (details) {
          final position = details.globalPosition;
          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
              position.dx,
              position.dy,
              position.dx,
              position.dy,
            ),
            items: [
              if (_isSvg)
                PopupMenuItem(
                  onTap: () => _copySvg(context),
                  child: const ListTile(
                    leading: Icon(Icons.copy, size: 18),
                    title: Text('Copy SVG'),
                    dense: true,
                  ),
                ),
              PopupMenuItem(
                onTap: () => _copyPath(context),
                child: const ListTile(
                  leading: Icon(Icons.folder_outlined, size: 18),
                  title: Text('Copy Path'),
                  dense: true,
                ),
              ),
            ],
          );
        },
        child: Tooltip(
          message: asset.name,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _isSvg
                ? SvgPicture.file(
                    file,
                    width: size * 0.55,
                    height: size * 0.55,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image_outlined,
                      size: size * 0.35,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSketch ? Icons.diamond_outlined : Icons.insert_drive_file_outlined,
                        size: size * 0.45,
                        color: _isSketch ? Colors.orange : Theme.of(context).colorScheme.primary,
                      ),
                      if (size > 60) ...[
                        const SizedBox(height: 2),
                        Text(
                          asset.name,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: 8,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.gridExtent,
    required this.hasPacks,
  });

  final double gridExtent;
  final bool hasPacks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              hasPacks ? 'No SVGs indexed yet' : 'No packs yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasPacks
                  ? 'Something went wrong indexing, or the pack folder is empty.'
                  : 'Use Add Pack to download Phosphor from GitHub.\n'
                      'Data: ${AppPaths.dataRoot}\n'
                      'DB: ${AppPaths.databaseFile}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Preview grid (${gridExtent.round()} px)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: gridExtent,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, i) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: gridExtent * 0.35,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/indexer/sketch_to_svg.dart';
import '../../core/indexer/svg_cache.dart';
import '../../core/paths/app_paths.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/pack_sidebar_row.dart';
import '../../shared/widgets/search_bar.dart';
import '../downloader/downloader_screen.dart';
import '../downloader/pack_install_notifier.dart';
import 'library_providers.dart';
import '../../shared/theme/theme_mode_provider.dart';
import '../../core/providers/toast_provider.dart';
import '../../shared/widgets/custom_title_bar.dart';

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
    default:
      return null;
  }
}

bool _assetIsSvg(Asset asset) => asset.filePath.toLowerCase().endsWith('.svg');

bool _assetIsSketch(Asset asset) {
  if (asset.filePath.toLowerCase().endsWith('.sketch')) return true;
  if (asset.metadata == null) return false;
  try {
    final meta = jsonDecode(asset.metadata!) as Map<String, dynamic>;
    final type = meta['type'] as String?;
    return type == 'sketch_kit' || type == 'sketch_component';
  } catch (_) {
    return false;
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
  int? _selectedPackId;
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
      setState(
        () => _debouncedSearch = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  Future<void> _confirmDeletePack(Pack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: Text(
          'This will remove "${pack.name}" and all its icons from your library.',
        ),
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
      final slug = pack.name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '_',
      );
      ref.read(packInstallProvider.notifier).delete(pack.name, slug);
    }
  }

  Future<void> _showAddLibraryDialog() async {
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    bool isUiKit = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Custom Library'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Library name',
                  hintText: 'e.g. My Projects',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pathController,
                      decoration: const InputDecoration(
                        labelText: 'Directory Path',
                        hintText: 'Select folder...',
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      final path = await FilePicker.platform.getDirectoryPath();
                      if (path != null) {
                        pathController.text = path;
                        if (nameController.text.isEmpty) {
                          nameController.text = p.basename(path);
                        }
                      }
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: isUiKit,
                onChanged: (v) => setState(() => isUiKit = v),
                title: const Text('Treat as UI Kit'),
                subtitle: const Text(
                  'Components will extracted from Sketch files if present',
                ),
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
                  ref
                      .read(packInstallProvider.notifier)
                      .installCustomLibrary(
                        name: name,
                        path: path,
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
      if (_selectedPackId != null && a.packId != _selectedPackId) return false;
      if (_debouncedSearch.isNotEmpty) {
        final q = _debouncedSearch;
        if (!a.name.toLowerCase().contains(q) &&
            !a.tags.toLowerCase().contains(q))
          return false;
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
        if (_selectedPackId != null) {
          final exists = packs.any((p) => p.id == _selectedPackId);
          if (!exists && mounted) setState(() => _selectedPackId = null);
        }
      });
    });

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CustomTitleBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'AssetBridge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: LibrarySearchBar(controller: _searchController),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Sidebar ──────────────────────────────────────────────
                SizedBox(
                  width: 240,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionLabel(context, 'ICON PACKS'),
                                  const SizedBox(height: 8),
                                  packsAsync.when(
                                    loading: () => const SizedBox.shrink(),
                                    error: (e, _) => Center(child: Text('$e')),
                                    data: (packs) {
                                      final icons = packs
                                          .where(
                                            (p) => !p.isUiKit && !p.isCustom,
                                          )
                                          .toList();
                                      return Column(
                                        children: [
                                          PackSidebarRow(
                                            title: 'All Assets',
                                            countLabel:
                                                '${packs.fold(0, (sum, p) => sum + p.iconCount)}',
                                            selected: _selectedPackId == null,
                                            showIcon: false,
                                            onTap: () => setState(
                                              () => _selectedPackId = null,
                                            ),
                                          ),
                                          if (icons.isEmpty)
                                            _emptyLabel(
                                              context,
                                              'No icon packs installed.',
                                            )
                                          else
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: icons.length,
                                              itemBuilder: (context, i) {
                                                final pack = icons[i];
                                                return PackSidebarRow(
                                                  title: pack.name,
                                                  countLabel:
                                                      '${pack.iconCount}',
                                                  selected:
                                                      _selectedPackId ==
                                                      pack.id,
                                                  onTap: () => setState(() {
                                                    _selectedPackId =
                                                        (_selectedPackId ==
                                                            pack.id)
                                                        ? null
                                                        : pack.id;
                                                  }),
                                                  onDelete: () =>
                                                      _confirmDeletePack(pack),
                                                );
                                              },
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _sectionLabel(context, 'MY LIBRARIES'),
                                  const SizedBox(height: 8),
                                  packsAsync.when(
                                    loading: () => const SizedBox.shrink(),
                                    error: (e, _) => const SizedBox.shrink(),
                                    data: (packs) {
                                      final customs = packs
                                          .where((p) => p.isCustom)
                                          .toList();
                                      if (customs.isEmpty)
                                        return _emptyLabel(
                                          context,
                                          'No custom libraries.',
                                        );
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: customs.length,
                                        itemBuilder: (context, i) {
                                          final pack = customs[i];
                                          return PackSidebarRow(
                                            title: pack.name,
                                            countLabel: '${pack.iconCount}',
                                            selected:
                                                _selectedPackId == pack.id,
                                            onTap: () => setState(() {
                                              _selectedPackId =
                                                  (_selectedPackId == pack.id)
                                                  ? null
                                                  : pack.id;
                                            }),
                                            onDelete: () =>
                                                _confirmDeletePack(pack),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _sectionLabel(context, 'UI KITS'),
                                  const SizedBox(height: 8),
                                  packsAsync.when(
                                    loading: () => const SizedBox.shrink(),
                                    error: (e, _) => const SizedBox.shrink(),
                                    data: (packs) {
                                      final kits = packs
                                          .where(
                                            (p) => p.isUiKit && !p.isCustom,
                                          )
                                          .toList();
                                      if (kits.isEmpty)
                                        return _emptyLabel(
                                          context,
                                          'No UI kits added.',
                                        );
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: kits.length,
                                        itemBuilder: (context, i) {
                                          final pack = kits[i];
                                          return PackSidebarRow(
                                            title: pack.name,
                                            countLabel: '${pack.iconCount}',
                                            selected:
                                                _selectedPackId == pack.id,
                                            onTap: () => setState(() {
                                              _selectedPackId =
                                                  (_selectedPackId == pack.id)
                                                  ? null
                                                  : pack.id;
                                            }),
                                            onDelete: () =>
                                                _confirmDeletePack(pack),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _showAddLibraryDialog,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.library_add_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Library',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => const DownloaderScreen(),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withValues(alpha: 0.5),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Add Pack',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Main grid ────────────────────────────────────────────
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
                                    onSelected: (_) =>
                                        setState(() => _selectedCategory = c),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.grid_view_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                ),
                                child: Slider(
                                  value: _gridExtent,
                                  min: 48,
                                  max: 120,
                                  divisions: 12,
                                  onChanged: (v) =>
                                      setState(() => _gridExtent = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: assetsAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
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
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: _gridExtent,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: filtered.length,
                              // KEY FIX: addRepaintBoundaries isolates repaints
                              // addAutomaticKeepAlives: false releases memory for
                              // off-screen sketch preview widgets
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              itemBuilder: (context, i) {
                                return _AssetTile(
                                  key: ValueKey(filtered[i].id),
                                  asset: filtered[i],
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
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    ),
  );

  Widget _emptyLabel(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

// ---------------------------------------------------------------------------
// Asset tile
// ---------------------------------------------------------------------------

class _AssetTile extends ConsumerStatefulWidget {
  const _AssetTile({super.key, required this.asset, required this.size});

  final Asset asset;
  final double size;

  @override
  ConsumerState<_AssetTile> createState() => _AssetTileState();
}

class _AssetTileState extends ConsumerState<_AssetTile> {
  bool _extracting = false;

  Asset get asset => widget.asset;
  double get size => widget.size;
  bool get isSvg => _assetIsSvg(asset);
  bool get isSketch => _assetIsSketch(asset);

  Future<void> _handleTap() async {
    if (isSvg) {
      await _copySvgSource();
      return;
    }
    if (isSketch) {
      await _copySketchAsSvg();
      return;
    }
    await _copyRawPath();
  }

  Future<void> _copySvgSource() async {
    try {
      final content = await File(asset.filePath).readAsString();
      await Clipboard.setData(ClipboardData(text: content));
      ref.read(toastProvider.notifier).success('Copied SVG: ${asset.name}');
    } catch (e) {
      ref.read(toastProvider.notifier).error('Failed to copy: $e');
    }
  }

  Future<void> _copySketchAsSvg() async {
    setState(() => _extracting = true);
    try {
      final svgText = await _resolveSvg();
      if (svgText == null || svgText.isEmpty) {
        ref
            .read(toastProvider.notifier)
            .error('Could not convert ${asset.name} to SVG');
        return;
      }
      await Clipboard.setData(ClipboardData(text: svgText));
      ref
          .read(toastProvider.notifier)
          .success('Copied as SVG: ${asset.name} — paste into Lunacy');
    } catch (e) {
      ref.read(toastProvider.notifier).error('Error: $e');
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  /// Central SVG resolver — checks cache first, then converts.
  Future<String?> _resolveSvg() async {
    // Check cache first
    if (SvgPreviewCache.instance.has(asset.id)) {
      return SvgPreviewCache.instance.get(asset.id);
    }

    if (asset.metadata == null) return null;
    final meta = jsonDecode(asset.metadata!) as Map<String, dynamic>;
    final type = meta['type'] as String?;
    String? svg;

    if (type == 'sketch_component') {
      svg = await SketchToSvg.componentToSvg(
        rootPath: meta['rootPath'] as String,
        pagePath: meta['pagePath'] as String,
        componentId: meta['id'] as String,
      );
    } else if (type == 'sketch_kit' || type == 'sketch_file') {
      svg = await _firstArtboardAsSvg(asset.filePath);
    }

    if (svg != null) SvgPreviewCache.instance.set(asset.id, svg);
    return svg;
  }

  Future<String?> _firstArtboardAsSvg(String kitPath) async {
    final pagesDir = Directory(p.join(kitPath, 'pages'));
    if (!await pagesDir.exists()) return null;
    await for (final entity in pagesDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final layers = json['layers'] as List<dynamic>?;
        if (layers == null) continue;
        for (final layer in layers) {
          if (layer is! Map<String, dynamic>) continue;
          final cls = layer['_class'] as String?;
          if (cls == 'artboard' || cls == 'symbolMaster' || cls == 'group') {
            return SketchToSvg.artboardToSvg(layer);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _copyRawPath() async {
    await Clipboard.setData(ClipboardData(text: asset.filePath));
    ref.read(toastProvider.notifier).success('Copied path: ${asset.filePath}');
  }

  Future<DragItem?> _buildDragItem(DragItemRequest request) async {
    String? filePath;

    if (isSvg) {
      filePath = asset.filePath;
    } else if (isSketch) {
      final svgText = await _resolveSvg();
      if (svgText != null) {
        final tempFile = File(
          p.join(
            AppPaths.thumbnailsRoot,
            '${asset.name.replaceAll(RegExp(r'[^\w]'), '_')}_drag.svg',
          ),
        );
        await tempFile.writeAsString(svgText);
        filePath = tempFile.path;
      }
    }

    if (filePath == null) return null;
    if (!await File(filePath).exists()) return null;

    final item = DragItem(localData: filePath);
    item.add(Formats.fileUri(Uri.file(filePath)));
    return item;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tileContent = Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _extracting ? null : _handleTap,
        onSecondaryTapDown: _showContextMenu,
        hoverColor: colorScheme.primary.withValues(alpha: 0.05),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        child: Tooltip(
          message: asset.name,
          waitDuration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _extracting
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : _buildPreview(context),
          ),
        ),
      ),
    );

    return DragItemWidget(
      dragItemProvider: _buildDragItem,
      allowedOperations: () => [DropOperation.copy],
      child: DraggableWidget(child: tileContent),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (isSketch && asset.metadata != null) {
      try {
        final meta = jsonDecode(asset.metadata!) as Map<String, dynamic>;
        final type = meta['type'] as String?;
        if (type == 'sketch_component' || type == 'sketch_kit') {
          return _SketchComponentPreview(asset: asset, size: size);
        }
      } catch (_) {}
    }

    if (isSvg) {
      return SvgPicture.file(
        File(asset.filePath),
        width: size * 0.55,
        height: size * 0.55,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackIcon(context),
      );
    }

    if (asset.previewPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(asset.previewPath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallbackIcon(context),
        ),
      );
    }

    return _fallbackIcon(context);
  }

  Widget _fallbackIcon(BuildContext context) =>
      Icon(Icons.diamond_outlined, size: size * 0.45, color: Colors.orange);

  void _showContextMenu(TapDownDetails details) {
    final pos = details.globalPosition;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        if (isSvg)
          PopupMenuItem(
            onTap: _copySvgSource,
            child: const ListTile(
              leading: Icon(Icons.code, size: 18),
              title: Text('Copy SVG source'),
              dense: true,
            ),
          ),
        if (isSketch)
          PopupMenuItem(
            onTap: _copySketchAsSvg,
            child: const ListTile(
              leading: Icon(Icons.content_copy_outlined, size: 18),
              title: Text('Copy as SVG (paste into Lunacy)'),
              dense: true,
            ),
          ),
        PopupMenuItem(
          onTap: () async {
            final dir = isSvg
                ? File(asset.filePath).parent.path
                : asset.filePath;
            await Process.run('xdg-open', [dir]);
          },
          child: const ListTile(
            leading: Icon(Icons.folder_open_outlined, size: 18),
            title: Text('Show in Files'),
            dense: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sketch preview widget — lazy + throttled + cached
// ---------------------------------------------------------------------------

class _SketchComponentPreview extends StatefulWidget {
  const _SketchComponentPreview({required this.asset, required this.size});

  final Asset asset;
  final double size;

  @override
  State<_SketchComponentPreview> createState() =>
      _SketchComponentPreviewState();
}

class _SketchComponentPreviewState extends State<_SketchComponentPreview> {
  String? _svgString;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  @override
  void didUpdateWidget(_SketchComponentPreview old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) {
      setState(() {
        _svgString = null;
        _loading = true;
        _failed = false;
      });
      _loadSvg();
    }
  }

  Future<void> _loadSvg() async {
    // Check cache first — no async work needed
    if (SvgPreviewCache.instance.has(widget.asset.id)) {
      if (mounted) {
        setState(() {
          _svgString = SvgPreviewCache.instance.get(widget.asset.id);
          _loading = false;
        });
      }
      return;
    }

    // Throttle: max 4 concurrent conversions via semaphore
    await svgLoadSemaphore.acquire();
    try {
      if (!mounted) return;

      final meta = jsonDecode(widget.asset.metadata!) as Map<String, dynamic>;
      final type = meta['type'] as String?;
      String? svg;

      if (type == 'sketch_component') {
        svg = await SketchToSvg.componentToSvg(
          rootPath: meta['rootPath'] as String,
          pagePath: meta['pagePath'] as String,
          componentId: meta['id'] as String,
        );
      } else if (type == 'sketch_kit') {
        // Show preview image for kit entry if available
        if (widget.asset.previewPath != null &&
            await File(widget.asset.previewPath!).exists()) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        svg = await _firstArtboardSvg(widget.asset.filePath);
      }

      // Cache it
      if (svg != null) SvgPreviewCache.instance.set(widget.asset.id, svg);

      if (mounted) {
        setState(() {
          _svgString = svg;
          _loading = false;
          _failed = svg == null;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _failed = true;
        });
    } finally {
      svgLoadSemaphore.release();
    }
  }

  Future<String?> _firstArtboardSvg(String kitPath) async {
    final pagesDir = Directory(p.join(kitPath, 'pages'));
    if (!await pagesDir.exists()) return null;
    await for (final entity in pagesDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final layers = json['layers'] as List<dynamic>?;
        if (layers == null) continue;
        for (final layer in layers) {
          if (layer is! Map<String, dynamic>) continue;
          final cls = layer['_class'] as String?;
          if (cls == 'artboard' || cls == 'symbolMaster' || cls == 'group') {
            return SketchToSvg.artboardToSvg(layer);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: widget.size * 0.3,
          height: widget.size * 0.3,
          child: const CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    // Kit with preview image
    if (!_failed && _svgString == null && widget.asset.previewPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(widget.asset.previewPath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Icon(
            Icons.diamond_outlined,
            size: widget.size * 0.45,
            color: Colors.orange,
          ),
        ),
      );
    }

    if (_failed || _svgString == null) {
      return Icon(
        Icons.diamond_outlined,
        size: widget.size * 0.45,
        color: Colors.orange,
      );
    }

    return SvgPicture.string(
      _svgString!,
      width: widget.size * 0.9,
      height: widget.size * 0.9,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.diamond_outlined,
        size: widget.size * 0.45,
        color: Colors.orange,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({required this.gridExtent, required this.hasPacks});

  final double gridExtent;
  final bool hasPacks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              hasPacks ? 'No assets indexed yet' : 'No packs yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasPacks
                  ? 'Something went wrong indexing, or the pack folder is empty.'
                  : 'Use Add Pack to download an icon pack or add a UI Kit.\nData: ${AppPaths.dataRoot}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

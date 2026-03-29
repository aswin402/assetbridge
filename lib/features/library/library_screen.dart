import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/indexer/sketch_to_svg.dart';
import '../../core/paths/app_paths.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/pack_sidebar_row.dart';
import '../../shared/widgets/search_bar.dart';
import '../downloader/downloader_screen.dart';
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
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------


bool _assetIsSvg(Asset asset) =>
    asset.filePath.toLowerCase().endsWith('.svg');

bool _assetIsSketch(Asset asset) {
  // A sketch asset is either a standalone .sketch file OR a kit/component
  // whose filePath is a directory (we detect via metadata type).
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

// ---------------------------------------------------------------------------

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
      setState(
          () => _debouncedSearch = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _confirmDeletePack(Pack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: Text(
            'This will remove "${pack.name}" and all its icons from your library.'),
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
      final slug =
          pack.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
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
        if (!a.name.toLowerCase().contains(q) &&
            !a.tags.toLowerCase().contains(q)) {
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
                  // ── Sidebar ──────────────────────────────────────────────
                  SizedBox(
                    width: 260,
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _sectionLabel(context, 'ICON PACKS'),
                                    const SizedBox(height: 8),
                                    packsAsync.when(
                                      loading: () => const Center(
                                          child: CircularProgressIndicator()),
                                      error: (e, _) =>
                                          Center(child: Text('$e')),
                                      data: (packs) {
                                        final icons = packs
                                            .where((p) => !p.isUiKit)
                                            .toList();
                                        if (icons.isEmpty) {
                                          return _emptyLabel(context,
                                              'No icon packs installed.');
                                        }
                                        return ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: icons.length,
                                          itemBuilder: (context, i) {
                                            final pack = icons[i];
                                            final enabled =
                                                !_disabledPackIds
                                                    .contains(pack.id);
                                            return PackSidebarRow(
                                              title: pack.name,
                                              countLabel:
                                                  '${pack.iconCount}',
                                              enabled: enabled,
                                              onChanged: (v) {
                                                if (v == null) return;
                                                setState(() {
                                                  if (v) {
                                                    _disabledPackIds
                                                        .remove(pack.id);
                                                  } else {
                                                    _disabledPackIds
                                                        .add(pack.id);
                                                  }
                                                });
                                              },
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
                                      loading: () =>
                                          const SizedBox.shrink(),
                                      error: (e, _) =>
                                          const SizedBox.shrink(),
                                      data: (packs) {
                                        final kits = packs
                                            .where((p) => p.isUiKit)
                                            .toList();
                                        if (kits.isEmpty) {
                                          return _emptyLabel(
                                              context, 'No UI kits added.');
                                        }
                                        return ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: kits.length,
                                          itemBuilder: (context, i) {
                                            final pack = kits[i];
                                            final enabled =
                                                !_disabledPackIds
                                                    .contains(pack.id);
                                            return PackSidebarRow(
                                              title: pack.name,
                                              countLabel:
                                                  '${pack.iconCount}',
                                              enabled: enabled,
                                              onChanged: (v) {
                                                if (v == null) return;
                                                setState(() {
                                                  if (v) {
                                                    _disabledPackIds
                                                        .remove(pack.id);
                                                  } else {
                                                    _disabledPackIds
                                                        .add(pack.id);
                                                  }
                                                });
                                              },
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
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DownloaderScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Pack'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.settings_outlined,
                                  size: 18),
                              label: const Text('Settings'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // ── Main grid ────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final c in _categories)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(right: 6),
                                    child: CategoryChip(
                                      label: c,
                                      selected: _selectedCategory == c,
                                      onSelected: (_) => setState(
                                          () => _selectedCategory = c),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                'Grid size',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _gridExtent,
                                  min: 48,
                                  max: 120,
                                  divisions: 12,
                                  label: '${_gridExtent.round()} px',
                                  onChanged: (v) =>
                                      setState(() => _gridExtent = v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: assetsAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (e, _) =>
                                Center(child: Text('$e')),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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
                                itemBuilder: (context, i) {
                                  return _AssetTile(
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
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _AssetTile extends StatefulWidget {
  const _AssetTile({required this.asset, required this.size});

  final Asset asset;
  final double size;

  @override
  State<_AssetTile> createState() => _AssetTileState();
}

class _AssetTileState extends State<_AssetTile> {
  bool _extracting = false;

  Asset get asset => widget.asset;
  double get size => widget.size;

  bool get isSvg => _assetIsSvg(asset);
  bool get isSketch => _assetIsSketch(asset);

  // ── Tap handler ─────────────────────────────────────────────────────────────

  Future<void> _handleTap() async {
    if (isSvg) {
      await _copySvgSource();
      return;
    }
    if (isSketch) {
      await _copySketchAsSvg();
      return;
    }
    // Fallback for unknown types
    await _copyRawPath();
  }

  /// SVG icon — copy raw file content (works perfectly, keep as-is)
  Future<void> _copySvgSource() async {
    try {
      final content = await File(asset.filePath).readAsString();
      await Clipboard.setData(ClipboardData(text: content));
      _snack('Copied SVG: ${asset.name}');
    } catch (e) {
      _snack('Failed to copy: $e');
    }
  }

  /// Sketch component or kit — convert JSON layer tree → SVG → paste as text.
  /// Lunacy will paste it as native vectors, identical to pasting any SVG.
  Future<void> _copySketchAsSvg() async {
    setState(() => _extracting = true);
    try {
      String? svgText;

      if (asset.metadata != null) {
        final meta = jsonDecode(asset.metadata!) as Map<String, dynamic>;
        final type = meta['type'] as String?;

        if (type == 'sketch_component') {
          // Convert the specific component layer to SVG
          svgText = await SketchToSvg.componentToSvg(
            rootPath: meta['rootPath'] as String,
            pagePath: meta['pagePath'] as String,
            componentId: meta['id'] as String,
          );
        } else if (type == 'sketch_kit' || type == 'sketch_file') {
          // For a full kit tile: convert the first artboard found
          svgText = await _firstArtboardAsSvg(asset.filePath);
        }
      }

      if (svgText == null || svgText.isEmpty) {
        _snack('Could not convert ${asset.name} to SVG');
        return;
      }

      await Clipboard.setData(ClipboardData(text: svgText));
      _snack('Copied as SVG: ${asset.name} — paste into Lunacy');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  /// Reads the first artboard from an unzipped sketch dir and converts it.
  Future<String?> _firstArtboardAsSvg(String kitPath) async {
    final pagesDir = Directory(p.join(kitPath, 'pages'));
    if (!await pagesDir.exists()) return null;

    await for (final entity in pagesDir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;

      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final layers = json['layers'] as List<dynamic>?;
        if (layers == null) continue;

        for (final layer in layers) {
          if (layer is! Map<String, dynamic>) continue;
          final cls = layer['_class'] as String?;
          if (cls == 'artboard' || cls == 'symbolMaster') {
            return SketchToSvg.artboardToSvg(layer);
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _copyRawPath() async {
    await Clipboard.setData(ClipboardData(text: asset.filePath));
    _snack('Copied path: ${asset.filePath}');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 340,
      ),
    );
  }

  // ── Drag handler ─────────────────────────────────────────────────────────────
  //
  // Same approach: for Sketch assets, convert to SVG then write SVG text to
  // a temp file and drag that file. Lunacy reads the dropped SVG file.

  Future<DragItem?> _buildDragItem(DragItemRequest request) async {
    String? svgText;
    String? filePath;

    if (isSvg) {
      filePath = asset.filePath;
    } else if (isSketch && asset.metadata != null) {
      final meta = jsonDecode(asset.metadata!) as Map<String, dynamic>;
      final type = meta['type'] as String?;

      if (type == 'sketch_component') {
        svgText = await SketchToSvg.componentToSvg(
          rootPath: meta['rootPath'] as String,
          pagePath: meta['pagePath'] as String,
          componentId: meta['id'] as String,
        );
      } else if (type == 'sketch_kit' || type == 'sketch_file') {
        svgText = await _firstArtboardAsSvg(asset.filePath);
      }

      if (svgText != null) {
        // Write SVG to temp file so we can drag a real file
        final tempFile = File(p.join(
          AppPaths.thumbnailsRoot,
          '${asset.name.replaceAll(RegExp(r'[^\w]'), '_')}_drag.svg',
        ));
        await tempFile.writeAsString(svgText);
        filePath = tempFile.path;
      }
    }

    if (filePath == null) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;

    final item = DragItem(localData: filePath);
    item.add(Formats.fileUri(Uri.file(filePath)));
    return item;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tileContent = Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _extracting ? null : _handleTap,
        onSecondaryTapDown: _showContextMenu,
        child: Tooltip(
          message: asset.name,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _extracting
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
    // For sketch components: render SVG inline instead of showing kit preview
    // (all components share the same kit preview.png which shows everything)
    if (isSketch && asset.metadata != null) {
      try {
        final meta = jsonDecode(asset.metadata!) as Map<String, dynamic>;
        final type = meta['type'] as String?;
        if (type == 'sketch_component' || type == 'sketch_kit') {
          return _SketchComponentPreview(asset: asset, size: size);
        }
      } catch (_) {}
    }

    // Plain SVG icon — render directly
    if (isSvg) {
      return SvgPicture.file(
        File(asset.filePath),
        width: size * 0.55,
        height: size * 0.55,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackIcon(context),
      );
    }

    // Standalone .sketch file with a preview image
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

  Widget _fallbackIcon(BuildContext context) => Icon(
        Icons.broken_image_outlined,
        size: size * 0.35,
        color: Theme.of(context).colorScheme.outline,
      );

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
                : asset.filePath; // kit filePath IS the directory
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
// Empty state
// ---------------------------------------------------------------------------

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
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.45),
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
                  : 'Use Add Pack to download an icon pack or add a UI Kit.\n'
                      'Data: ${AppPaths.dataRoot}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchComponentPreview extends StatefulWidget {
  const _SketchComponentPreview({
    required this.asset,
    required this.size,
  });

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
    try {
      final meta =
          jsonDecode(widget.asset.metadata!) as Map<String, dynamic>;
      final type = meta['type'] as String?;
      String? svg;

      if (type == 'sketch_component') {
        svg = await SketchToSvg.componentToSvg(
          rootPath: meta['rootPath'] as String,
          pagePath: meta['pagePath'] as String,
          componentId: meta['id'] as String,
        );
      } else if (type == 'sketch_kit') {
        // For kit entry: show the kit preview image if available,
        // otherwise show first artboard SVG
        if (widget.asset.previewPath != null &&
            await File(widget.asset.previewPath!).exists()) {
          if (mounted) setState(() => _loading = false);
          return; // will fall through to Image.file in parent
        }
        svg = await _firstArtboardSvg(widget.asset.filePath);
      }

      if (mounted) {
        setState(() {
          _svgString = svg;
          _loading = false;
          _failed = svg == null;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
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
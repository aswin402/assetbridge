import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../paths/app_paths.dart';
import 'tag_parser.dart';
import 'sketch_parser.dart';

class SvgIndexer {
  SvgIndexer(this._db);

  final AppDatabase _db;

  /// Entry point. Detection order:
  ///   1. Is scanDir itself an unzipped Sketch library?
  ///   2. Does scanDir contain a subdirectory that is a Sketch library?
  ///   3. Walk recursively for .svg / standalone .sketch files.
  Future<int> indexPackContents({
    required int packId,
    required String packRoot,
    String? scanSubdir,
  }) async {
    final rootDir = Directory(packRoot);
    if (!await rootDir.exists()) return 0;

    final scanPath =
        scanSubdir != null ? p.join(packRoot, scanSubdir) : packRoot;
    final scanDir = Directory(scanPath);
    if (!await scanDir.exists()) return 0;

    // Deduplicate on re-index
    await (_db.delete(_db.assets)..where((a) => a.packId.equals(packId))).go();

    // 1. scanDir itself is an unzipped Sketch bundle
    if (await _isSketchLibraryDir(scanDir)) {
      return _indexSketchLibraryDir(
          packId: packId, packRoot: packRoot, scanDir: scanDir);
    }

    // 2. Look one level deep — handles packDir/slug/document.json layout
    //    produced by installLocal when a .sketch file is extracted.
    await for (final entity
        in scanDir.list(recursive: false, followLinks: false)) {
      if (entity is Directory && await _isSketchLibraryDir(entity)) {
        return _indexSketchLibraryDir(
            packId: packId, packRoot: packRoot, scanDir: entity);
      }
    }

    // 3. Standard SVG / standalone .sketch walk
    return _indexSvgFiles(
        packId: packId, packRoot: packRoot, scanDir: scanDir);
  }

  // ── Sketch library directory ──────────────────────────────────────────────

  Future<int> _indexSketchLibraryDir({
    required int packId,
    required String packRoot,
    required Directory scanDir,
  }) async {
    final kitName = p.basename(scanDir.path);
    final preview = await _getUnzippedPreview(scanDir, kitName);

    // Kit entry — filePath is the directory (UI uses metadata.type to detect)
    await _db.into(_db.assets).insert(
          AssetsCompanion.insert(
            packId: packId,
            name: kitName,
            tags: 'uikit,sketch,design,kit,library',
            filePath: p.normalize(scanDir.path),
            fileSizeBytes: const Value(0),
            previewPath: Value(preview),
            metadata: const Value('{"type":"sketch_kit"}'),
          ),
        );

    final components = await SketchParser.parseLibrary(scanDir);
    if (kDebugMode) print('SvgIndexer: SketchParser found ${components.length} components in ${scanDir.path}');
    if (components.isEmpty) return 1;

    final companions = components.map((c) {
      final nameTags = tagsFromComponentName(c.name);
      final tags = {'component', 'sketch', 'uikit', ...nameTags}.join(',');
      return AssetsCompanion.insert(
        packId: packId,
        name: c.name,
        tags: tags,
        category: const Value('Components'),
        filePath: p.normalize(scanDir.path),
        fileSizeBytes: const Value(0),
        previewPath: Value(preview),
        metadata: Value(jsonEncode({
          'type': 'sketch_component',
          'id': c.id,
          'pageId': c.pageId,
          'pagePath': c.pagePath,
          'rootPath': scanDir.path,
        })),
      );
    }).toList();

    await _batchInsert(companions);
    return companions.length + 1;
  }

  // ── SVG / standalone .sketch walk ────────────────────────────────────────

  Future<int> _indexSvgFiles({
    required int packId,
    required String packRoot,
    required Directory scanDir,
  }) async {
    final companions = <AssetsCompanion>[];

    await for (final entity
        in scanDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      final isSvg = lower.endsWith('.svg');
      final isSketch = lower.endsWith('.sketch');
      if (!isSvg && !isSketch) continue;

      final stat = await entity.stat();
      final rel = p.relative(entity.path, from: packRoot);
      final name = p.basenameWithoutExtension(entity.path);
      final tags = tagsFromFilename(entity.path, isSketch: isSketch);
      final category = categoryFromRelativePath(rel);

      String? previewPath;
      if (isSketch) previewPath = await _tryExtractSketchPreview(entity);

      companions.add(AssetsCompanion.insert(
        packId: packId,
        name: name,
        tags: tags,
        category: category != null ? Value(category) : const Value.absent(),
        filePath: p.normalize(entity.path),
        fileSizeBytes: Value(stat.size),
        previewPath: Value(previewPath),
      ));
    }

    await _batchInsert(companions);
    return companions.length;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _isSketchLibraryDir(Directory dir) async {
    final docJson = File(p.join(dir.path, 'document.json'));
    final pagesDir = Directory(p.join(dir.path, 'pages'));
    return await docJson.exists() && await pagesDir.exists();
  }

  Future<String?> _getUnzippedPreview(Directory dir, String name) async {
    final f = File(p.join(dir.path, 'previews', 'preview.png'));
    if (!await f.exists()) return null;
    final dest =
        p.join(AppPaths.thumbnailsRoot, '${_sanitize(name)}_thumb.png');
    await f.copy(dest);
    return dest;
  }

  Future<String?> _tryExtractSketchPreview(File sketchFile) async {
    try {
      final bytes = await sketchFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final previewFile = archive.findFile('previews/preview.png');
      if (previewFile != null) {
        final name = p.basenameWithoutExtension(sketchFile.path);
        final dest = p.join(
            AppPaths.thumbnailsRoot, '${_sanitize(name)}_thumb.png');
        await File(dest).writeAsBytes(previewFile.content as List<int>);
        return dest;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _batchInsert(List<AssetsCompanion> companions) async {
    const chunk = 400;
    for (var i = 0; i < companions.length; i += chunk) {
      final end =
          (i + chunk > companions.length) ? companions.length : i + chunk;
      await _db
          .batch((b) => b.insertAll(_db.assets, companions.sublist(i, end)));
    }
  }

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w]'), '_').toLowerCase();
}
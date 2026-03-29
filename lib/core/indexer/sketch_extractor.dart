import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../paths/app_paths.dart';

class SketchExtractor {
  static const _uuid = Uuid();

  /// Builds a minimal but valid `.sketch` bundle containing only [componentId]
  /// from the unzipped Sketch library at [rootPath].
  ///
  /// Returns the path to the generated `.sketch` file, or `null` on failure.
  static Future<String?> extractComponent({
    required String rootPath,
    required String pagePath,
    required String componentId,
    required String name,
  }) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return null;

    final pageFile = File(pagePath);
    if (!await pageFile.exists()) return null;

    final tempDir = Directory(
        p.join(AppPaths.thumbnailsRoot, 'temp_${_uuid.v4()}'));
    await tempDir.create(recursive: true);

    try {
      // -----------------------------------------------------------------------
      // 1. Read and patch document.json so it only lists this one page
      // -----------------------------------------------------------------------
      final docFile = File(p.join(rootPath, 'document.json'));
      if (!await docFile.exists()) return null;

      final docJson =
          jsonDecode(await docFile.readAsString()) as Map<String, dynamic>;

      final pageId = p.basenameWithoutExtension(pagePath);

      // Patch pages array to contain only the target page ref
      final pages = (docJson['pages'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .where((ref) =>
                  (ref['_ref'] as String?)?.contains(pageId) ?? false)
              .toList() ??
          [];

      if (pages.isNotEmpty) {
        docJson['pages'] = pages;
      }
      // If we couldn't find a matching ref, keep all pages — safer than
      // producing a broken bundle.

      await File(p.join(tempDir.path, 'document.json'))
          .writeAsString(jsonEncode(docJson));

      // -----------------------------------------------------------------------
      // 2. Copy meta.json and user.json if present
      // -----------------------------------------------------------------------
      for (final fname in ['meta.json', 'user.json']) {
        final src = File(p.join(rootPath, fname));
        if (await src.exists()) {
          await src.copy(p.join(tempDir.path, fname));
        }
      }

      // -----------------------------------------------------------------------
      // 3. Process and Filter the target page JSON
      // -----------------------------------------------------------------------
      final pagesDestDir = Directory(p.join(tempDir.path, 'pages'));
      await pagesDestDir.create();

      final pageContent = await pageFile.readAsString();
      final pageJson = jsonDecode(pageContent) as Map<String, dynamic>;

      // Filter layers to include ONLY the target component
      final layers = (pageJson['layers'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .where((l) => l['do_objectID'] == componentId)
              .toList() ??
          [];

      if (layers.isNotEmpty) {
        pageJson['layers'] = layers;
      }
      // If we couldn't find it (unlikely), we keep the whole page as fallback.

      await File(p.join(pagesDestDir.path, p.basename(pagePath)))
          .writeAsString(jsonEncode(pageJson));

      // -----------------------------------------------------------------------
      // 4. Copy images/ folder — components may reference embedded bitmaps
      // -----------------------------------------------------------------------
      final imagesDir = Directory(p.join(rootPath, 'images'));
      if (await imagesDir.exists()) {
        final imagesDestDir = Directory(p.join(tempDir.path, 'images'));
        await imagesDestDir.create();
        await for (final img
            in imagesDir.list(recursive: false, followLinks: false)) {
          if (img is File) {
            await img.copy(p.join(imagesDestDir.path, p.basename(img.path)));
          }
        }
      }

      // -----------------------------------------------------------------------
      // 5. Zip into a .sketch bundle
      // -----------------------------------------------------------------------
      final safeName = name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final zipPath =
          p.join(AppPaths.thumbnailsRoot, '$safeName.sketch');

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      await for (final entity
          in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          // archive_io addFile(file, filename) — filename is the path
          // INSIDE the zip. Must use forward slashes.
          final rel = p
              .relative(entity.path, from: tempDir.path)
              .replaceAll(r'\', '/');
          encoder.addFile(entity, rel);
        }
      }
      encoder.close();

      return zipPath;
    } catch (e, st) {
      // Surface errors so callers can show meaningful messages
      // ignore: avoid_print
      print('[SketchExtractor] Failed to extract "$name": $e\n$st');
      return null;
    } finally {
      // Always clean up temp dir
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Extracts the entire kit directory as a single `.sketch` file.
  /// Useful for "open full kit" actions.
  static Future<String?> extractFullKit({
    required String rootPath,
    required String kitName,
  }) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return null;

    final safeName = kitName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final zipPath = p.join(AppPaths.thumbnailsRoot, '$safeName.sketch');

    try {
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      await for (final entity
          in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final rel = p
              .relative(entity.path, from: rootPath)
              .replaceAll(r'\', '/');
          encoder.addFile(entity, rel);
        }
      }
      encoder.close();
      return zipPath;
    } catch (e, st) {
      // ignore: avoid_print
      print('[SketchExtractor] Failed to zip kit "$kitName": $e\n$st');
      return null;
    }
  }
}
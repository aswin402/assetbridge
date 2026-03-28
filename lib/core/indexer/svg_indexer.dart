import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'tag_parser.dart';

class SvgIndexer {
  SvgIndexer(this._db);

  final AppDatabase _db;

  /// Walks [packRoot] for `*.svg` files and inserts [AssetsCompanion] rows.
  /// If [scanSubdir] is provided, only files within that subdirectory of [packRoot] are indexed.
  Future<int> indexPackContents({
    required int packId,
    required String packRoot,
    String? scanSubdir,
  }) async {
    final rootDir = Directory(packRoot);
    if (!await rootDir.exists()) return 0;

    final scanPath = scanSubdir != null ? p.join(packRoot, scanSubdir) : packRoot;
    final scanDir = Directory(scanPath);
    if (!await scanDir.exists()) return 0;

    final companions = <AssetsCompanion>[];
    await for (final entity in scanDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lowerPath = entity.path.toLowerCase();
      if (!lowerPath.endsWith('.svg') && !lowerPath.endsWith('.sketch')) continue;

      final stat = await entity.stat();
      final rel = p.relative(entity.path, from: packRoot);
      final name = p.basenameWithoutExtension(entity.path);
      final tags = tagsFromSvgFilename(entity.path);
      final category = categoryFromRelativePath(rel);

      companions.add(
        AssetsCompanion.insert(
          packId: packId,
          name: name,
          tags: tags,
          category: category != null ? Value(category) : const Value.absent(),
          filePath: p.normalize(entity.path),
          fileSizeBytes: Value(stat.size),
        ),
      );
    }

    const chunk = 400;
    for (var i = 0; i < companions.length; i += chunk) {
      final end = (i + chunk > companions.length) ? companions.length : i + chunk;
      final slice = companions.sublist(i, end);
      await _db.batch((b) {
        for (final c in slice) {
          b.insert(_db.assets, c);
        }
      });
    }

    return companions.length;
  }
}

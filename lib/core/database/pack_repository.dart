import 'dart:io';

import 'app_database.dart';

extension PackRepository on AppDatabase {
  /// Deletes all rows for [packName] and removes the on-disk folder if present.
  Future<void> deletePackByName(String packName) async {
    final row = await (select(packs)..where((p) => p.name.equals(packName))).getSingleOrNull();
    if (row == null) return;

    await transaction(() async {
      await (delete(assets)..where((a) => a.packId.equals(row.id))).go();
      await (delete(packs)..where((p) => p.id.equals(row.id))).go();
    });

    final dir = Directory(row.localPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Removes stale folder when the DB had no row (e.g. failed partial install).
  Future<void> removePackDirectoryIfExists(String absolutePackPath) async {
    final dir = Directory(absolutePackPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

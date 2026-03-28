import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../paths/app_paths.dart';

part 'app_database.g.dart';

class Packs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get version => text()();

  IntColumn get iconCount => integer()();

  TextColumn get localPath => text()();

  DateTimeColumn get downloadedAt => dateTime().nullable()();

  TextColumn get sourceUrl => text().nullable()();
}

class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get packId => integer().references(Packs, #id)();

  TextColumn get name => text()();

  /// Comma-separated tags (search / display).
  TextColumn get tags => text()();

  TextColumn get category => text().nullable()();

  TextColumn get filePath => text()();

  IntColumn get fileSizeBytes => integer().nullable()();
}

@DriftDatabase(tables: [Packs, Assets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// In-memory database for tests (no sqlite3 file / XDG paths).
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'assetbridge',
      native: DriftNativeOptions(
        databasePath: () async {
          await AppPaths.ensureDirectories();
          return AppPaths.databaseFile;
        },
      ),
    );
  }

  @override
  int get schemaVersion => 1;
}

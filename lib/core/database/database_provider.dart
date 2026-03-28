import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Single app database instance; closed when the provider container is disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

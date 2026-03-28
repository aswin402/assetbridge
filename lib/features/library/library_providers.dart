import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';

final packsStreamProvider = StreamProvider<List<Pack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.packs).watch();
});

final allAssetsStreamProvider = StreamProvider<List<Asset>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.assets).watch();
});

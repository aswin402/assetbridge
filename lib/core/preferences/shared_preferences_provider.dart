import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../paths/app_paths.dart';

/// App-wide [SharedPreferences] instance (Linux: typically under local share).
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  await AppPaths.ensureDirectories();
  return SharedPreferences.getInstance();
});

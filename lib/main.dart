import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/paths/app_paths.dart';
import 'shared/theme/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.ensureDirectories();
  await bootstrapPreferences();
  runApp(const ProviderScope(child: AssetBridgeApp()));
}

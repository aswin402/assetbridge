import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/paths/app_paths.dart';
import 'shared/theme/theme_mode_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window_manager before anything else
  await windowManager.ensureInitialized();

  await AppPaths.ensureDirectories();
  await bootstrapPreferences();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(400, 600),
      minimumSize: Size(400, 600),
      center: true,
      // This is what actually hides the title bar on Linux
      titleBarStyle: TitleBarStyle.hidden,
      title: 'AssetBridge',
      skipTaskbar: false,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const ProviderScope(child: AssetBridgeApp()));
}

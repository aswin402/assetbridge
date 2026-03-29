import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/library/library_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_mode_provider.dart';

import 'shared/widgets/toast_overlay.dart';
import 'shared/widgets/window_resizer.dart';

class AssetBridgeApp extends ConsumerWidget {
  const AssetBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'AssetBridge',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light(null),
      darkTheme: AppTheme.dark(null),
      builder: (context, child) => ToastOverlay(
        child: WindowResizer(child: child!),
      ),
      home: const LibraryScreen(),
    );
  }
}

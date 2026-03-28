import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/library/library_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_mode_provider.dart';

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
      home: const LibraryScreen(),
    );
  }
}

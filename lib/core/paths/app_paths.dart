import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xdg_directories/xdg_directories.dart' as xdg;

/// XDG Base Directory paths for AssetBridge on Linux.
///
/// Data: `~/.local/share/assetbridge/`
/// Config: `~/.config/assetbridge/`
abstract final class AppPaths {
  static String get dataRoot => p.join(xdg.dataHome.path, 'assetbridge');

  static String get configRoot => p.join(xdg.configHome.path, 'assetbridge');

  /// Icon pack contents: `~/.local/share/assetbridge/packs/<pack_name>/`
  static String get packsRoot => p.join(dataRoot, 'packs');

  /// SQLite database file.
  static String get databaseFile => p.join(dataRoot, 'assetbridge.db');

  /// Ensures data, packs, and config directories exist.
  static Future<void> ensureDirectories() async {
    await Directory(dataRoot).create(recursive: true);
    await Directory(packsRoot).create(recursive: true);
    await Directory(configRoot).create(recursive: true);
  }
}

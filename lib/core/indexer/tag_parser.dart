import 'package:path/path.dart' as p;

/// Builds comma-separated tags from an SVG filename (no extension).
///
/// Splits on `-` and `_`, lowercases tokens, and adds light semantic hints
/// (e.g. arrow icons → direction, navigation).
String tagsFromSvgFilename(String filename) {
  final base = p.basenameWithoutExtension(filename).toLowerCase();
  final tokens = base
      .split(RegExp(r'[-_\s]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final tags = <String>{...tokens};

  if (tokens.any((t) => t.contains('arrow'))) {
    tags.add('direction');
    tags.add('navigation');
  }
  if (tokens.any((t) => t == 'user' || t == 'users')) {
    tags.add('people');
  }
  if (tokens.any((t) => t.contains('home'))) {
    tags.add('ui');
  }

  final sorted = tags.toList()..sort();
  return sorted.join(',');
}

/// Category from relative path. Filters out common root names like `assets`, `icons`, etc.
/// E.g. `assets/regular/foo.svg` → `regular`.
/// E.g. `src/filled/home.svg` → `filled`.
String? categoryFromRelativePath(String relativePath) {
  final parts = p.split(p.normalize(relativePath));
  // Remove the filename
  if (parts.length < 2) return null;
  final folders = parts.sublist(0, parts.length - 1);

  // Common "root" folders to skip
  final noise = {'assets', 'icons', 'src', 'symbols', 'web', 'svg', 'static'};

  for (final f in folders) {
    if (!noise.contains(f.toLowerCase())) {
      return f;
    }
  }

  // Fallback to the direct parent if we only found noise or nothing
  return folders.isNotEmpty ? folders.last : null;
}

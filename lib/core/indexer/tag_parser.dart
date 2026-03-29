import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// SVG / generic file tag builder
// ---------------------------------------------------------------------------

/// Builds comma-separated, lowercase tags from an SVG (or any) filename.
///
/// Splits on `-`, `_`, and whitespace; adds light semantic hints.
String tagsFromFilename(String filename, {bool isSketch = false}) {
  if (isSketch) {
    final base = p.basenameWithoutExtension(filename).toLowerCase();
    final tokens = _tokenise(base);
    final tags = <String>{'sketch', 'uikit', ...tokens};
    return (tags.toList()..sort()).join(',');
  }
  return tagsFromSvgFilename(filename);
}

/// Builds tags specifically for an SVG filename.
String tagsFromSvgFilename(String filename) {
  final base = p.basenameWithoutExtension(filename).toLowerCase();
  final tokens = _tokenise(base);
  final tags = <String>{...tokens};

  _addSemanticHints(tokens, tags);

  return (tags.toList()..sort()).join(',');
}

/// Builds tags from a Sketch component/artboard name.
///
/// Component names often use spaces and Title Case, so we normalise them
/// differently from file names.
Set<String> tagsFromComponentName(String name) {
  // Lower-case, then split on spaces, slashes, dashes, underscores
  final lower = name.toLowerCase();
  final tokens = _tokenise(lower);
  final tags = <String>{...tokens};
  _addSemanticHints(tokens, tags);
  return tags;
}

// ---------------------------------------------------------------------------
// Category from relative path
// ---------------------------------------------------------------------------

/// Returns the first non-noise folder segment from [relativePath],
/// or `null` if every segment is noise.
///
/// E.g. `assets/regular/foo.svg` → `regular`
///      `src/filled/home.svg`    → `filled`
///      `icons/arrow-up.svg`     → `null`
String? categoryFromRelativePath(String relativePath) {
  final parts = p.split(p.normalize(relativePath));
  if (parts.length < 2) return null;

  // Drop the filename
  final folders = parts.sublist(0, parts.length - 1);

  const noise = {
    'assets', 'icons', 'src', 'symbols', 'web', 'svg',
    'static', 'dist', 'lib', 'output', 'build', 'public',
  };

  for (final f in folders) {
    if (!noise.contains(f.toLowerCase())) return f;
  }

  return folders.isNotEmpty ? folders.last : null;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

List<String> _tokenise(String text) {
  return text
      .split(RegExp(r'[-_\s/\\]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

void _addSemanticHints(List<String> tokens, Set<String> tags) {
  if (tokens.any((t) => t.contains('arrow'))) {
    tags.addAll(['direction', 'navigation']);
  }
  if (tokens.any((t) => t == 'user' || t == 'users' || t == 'person')) {
    tags.addAll(['people', 'avatar']);
  }
  if (tokens.any((t) => t.contains('home'))) {
    tags.addAll(['ui', 'navigation']);
  }
  if (tokens.any((t) => t == 'close' || t == 'x' || t == 'cancel')) {
    tags.add('dismiss');
  }
  if (tokens.any((t) => t == 'check' || t == 'tick' || t == 'done')) {
    tags.addAll(['success', 'confirm']);
  }
  if (tokens.any((t) => t == 'warning' || t == 'alert' || t == 'error')) {
    tags.addAll(['status', 'notification']);
  }
  if (tokens.any((t) => t == 'search' || t == 'magnifier' || t == 'zoom')) {
    tags.add('find');
  }
  if (tokens.any((t) => t == 'settings' || t == 'gear' || t == 'cog')) {
    tags.addAll(['preferences', 'config']);
  }
  if (tokens.any((t) => t == 'heart' || t == 'like' || t == 'love')) {
    tags.addAll(['favourite', 'favorite']);
  }
  if (tokens.any((t) => t == 'star')) {
    tags.addAll(['favourite', 'rating']);
  }
  if (tokens.any((t) => t == 'plus' || t == 'add')) {
    tags.add('create');
  }
  if (tokens.any((t) => t == 'trash' || t == 'delete' || t == 'bin')) {
    tags.add('remove');
  }
  if (tokens.any((t) => t == 'edit' || t == 'pencil' || t == 'pen')) {
    tags.add('modify');
  }
  if (tokens.any((t) => t == 'folder' || t == 'file' || t == 'document')) {
    tags.add('storage');
  }
  if (tokens.any((t) => t == 'lock' || t == 'unlock' || t == 'key')) {
    tags.add('security');
  }
  if (tokens.any((t) => t == 'mail' || t == 'email' || t == 'envelope')) {
    tags.add('message');
  }
  if (tokens.any(
      (t) => t == 'phone' || t == 'mobile' || t == 'call')) {
    tags.addAll(['contact', 'communication']);
  }
}
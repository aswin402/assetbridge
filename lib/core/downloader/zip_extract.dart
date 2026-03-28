import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Extracts a GitHub-style zip (single top-level folder) into [destDir].
///
/// Strips the first path segment to avoid nesting `owner-repo-sha/`.
/// Validates paths to mitigate zip-slip.
Future<void> extractZipBytes(List<int> bytes, String destDir) async {
  final dest = p.normalize(p.absolute(destDir));
  final archive = ZipDecoder().decodeBytes(bytes);
  if (archive.files.isEmpty) return;

  String? rootPrefix;
  for (final f in archive.files) {
    if (!f.isFile || f.name.isEmpty) continue;
    final first = f.name.split('/').first;
    if (first.isNotEmpty) {
      rootPrefix = first;
      break;
    }
  }

  for (final file in archive.files) {
    if (!file.isFile) continue;
    var relative = file.name;
    if (rootPrefix != null) {
      final prefix = '$rootPrefix/';
      if (relative.startsWith(prefix)) {
        relative = relative.substring(prefix.length);
      }
    }
    if (relative.isEmpty || relative.endsWith('/') || relative.contains('..')) continue;

    final outPath = p.normalize(p.join(dest, relative));
    if (!p.isWithin(dest, outPath) && outPath != dest) {
      throw StateError('Unsafe zip path: ${file.name}');
    }

    await Directory(p.dirname(outPath)).create(recursive: true);
    await File(outPath).writeAsBytes(file.content as List<int>);
  }
}

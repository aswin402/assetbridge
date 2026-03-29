import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Extracts a zip file from [zipPath] into [destDir] using streaming to avoid
/// loading the entire archive into RAM.
///
/// Strips the common root prefix folder ONLY for GitHub-style zipballs where
/// every single file is inside a wrapper folder.
Future<void> extractZipFile(String zipPath, String destDir) async {
  final dest = p.normalize(p.absolute(destDir));
  final inputStream = InputFileStream(zipPath);

  try {
    final archive = ZipDecoder().decodeStream(inputStream);

    // Detect if there's a common root folder prefix (like GitHub's owner-repo-sha/)
    // We should ONLY strip if EVERY file in the archive starts with the same prefix.
    String? commonPrefix;
    bool allSharePrefix = true;

    for (final f in archive) {
      if (f.name.isEmpty) continue;
      final segments = f.name.split('/');
      if (segments.length < 2) {
        // This file is at the root of the ZIP (e.g., document.json)
        // Therefore, there is NO common root prefix to strip.
        allSharePrefix = false;
        break;
      }
      final prefix = segments.first;
      if (commonPrefix == null) {
        commonPrefix = prefix;
      } else if (commonPrefix != prefix) {
        allSharePrefix = false;
        break;
      }
    }

    final rootPrefix = (allSharePrefix && commonPrefix != null) ? commonPrefix : null;
    if (kDebugMode && rootPrefix != null) {
      print('ZipExtract: Detected common root prefix "$rootPrefix/". Stripping it.');
    } else if (rootPrefix == null) {
      if (kDebugMode) print('ZipExtract: No common root prefix found. Preserving all folders.');
    }

    for (final file in archive) {
      var relative = file.name;
      if (rootPrefix != null) {
        final prefix = '$rootPrefix/';
        if (relative.startsWith(prefix)) {
          relative = relative.substring(prefix.length);
        }
      }

      // Skip base root, macOS junk, or empty names
      if (relative.isEmpty || relative.contains('..')) continue;
      final base = p.basename(relative);
      if (base.startsWith('._') || base == '.DS_Store') continue;

      final outPath = p.normalize(p.join(dest, relative));
      if (!p.isWithin(dest, outPath) && outPath != dest) {
        // Zip-slip prevention
        continue;
      }

      if (!file.isFile) {
        await Directory(outPath).create(recursive: true);
      } else {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);

        // Streaming extraction: write content directly to disk.
        final outputStream = OutputFileStream(outPath);
        file.writeContent(outputStream);
        await outputStream.close();
      }
    }
  } finally {
    await inputStream.close();
  }
}

/// Extracts zip bytes directly into [destDir].
/// Useful for smaller archives like .sketch bundles.
Future<void> extractZipBytes(List<int> bytes, String destDir) async {
  final dest = p.normalize(p.absolute(destDir));
  final archive = ZipDecoder().decodeBytes(bytes);

  for (final file in archive) {
    if (!file.isFile) continue;
    final base = p.basename(file.name);
    if (base.startsWith('._') || base == '.DS_Store') continue;

    final outPath = p.normalize(p.join(dest, file.name));
    if (!p.isWithin(dest, outPath)) continue;

    await Directory(p.dirname(outPath)).create(recursive: true);
    await File(outPath).writeAsBytes(file.content as List<int>);
  }
}

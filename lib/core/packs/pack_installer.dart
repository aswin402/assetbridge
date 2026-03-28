import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../database/pack_repository.dart';
import '../downloader/github_release_client.dart';
import '../downloader/zip_extract.dart';
import '../indexer/svg_indexer.dart';
import '../paths/app_paths.dart';
import 'pack_config.dart';

/// Downloads a pack from the latest GitHub release zipball, extracts under
/// [AppPaths.packsRoot], and indexes SVG metadata into SQLite.
class PackInstaller {
  PackInstaller(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  /// Installs or replaces the given pack. Reports coarse-grained progress.
  Future<void> install({
    required PackConfig config,
    CancelToken? cancelToken,
    void Function(String phase, double? fraction)? onProgress,
  }) async {
    final owner = config.owner;
    final repo = config.repo;
    if (owner == null || repo == null) {
      throw ArgumentError('config.owner and config.repo must be provided for GitHub install');
    }

    final client = GitHubReleaseClient(_dio);
    onProgress?.call('Fetching release…', null);

    final release = await client.fetchLatestRelease(
      owner: owner,
      repo: repo,
      cancelToken: cancelToken,
    );
    if (release == null || release.zipballUrl.isEmpty) {
      throw StateError('No GitHub release or zipball URL for $owner/$repo');
    }

    final packDir = p.join(AppPaths.packsRoot, config.slug);
    await _db.deletePackByName(config.name);
    await _db.removePackDirectoryIfExists(packDir);
    await Directory(packDir).create(recursive: true);

    final tempDir = await Directory.systemTemp.createTemp('assetbridge_${config.slug}_');
    final zipFile = File(p.join(tempDir.path, 'src.zip'));

    Future<void> cleanupFailure() async {
      await _db.deletePackByName(config.name);
      await _db.removePackDirectoryIfExists(packDir);
    }

    try {
      onProgress?.call('Downloading ${release.tagName}…', 0);
      await _dio.download(
        release.zipballUrl,
        zipFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            onProgress?.call('Downloading ${release.tagName}…', null);
          } else {
            onProgress?.call('Downloading ${release.tagName}…', received / total);
          }
        },
      );

      if (cancelToken?.isCancelled ?? false) {
        await cleanupFailure();
        return;
      }

      onProgress?.call('Extracting…', null);
      final bytes = await zipFile.readAsBytes();
      await extractZipBytes(bytes, packDir);

      if (cancelToken?.isCancelled ?? false) {
        await cleanupFailure();
        return;
      }

      await _finishInstallation(
        config: config,
        packDir: packDir,
        version: release.tagName,
        sourceUrl: release.htmlUrl,
        onProgress: onProgress,
      );
    } catch (e) {
      await cleanupFailure();
      rethrow;
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Installs a pack from a local ZIP file.
  Future<void> installLocal({
    required File zipFile,
    required String name,
    required String slug,
    String? svgPathPrefix,
    void Function(String phase, double? fraction)? onProgress,
  }) async {
    final packDir = p.join(AppPaths.packsRoot, slug);
    await _db.deletePackByName(name);
    await _db.removePackDirectoryIfExists(packDir);
    await Directory(packDir).create(recursive: true);

    Future<void> cleanupFailure() async {
      await _db.deletePackByName(name);
      await _db.removePackDirectoryIfExists(packDir);
    }

    try {
      onProgress?.call('Extracting…', null);
      final bytes = await zipFile.readAsBytes();
      await extractZipBytes(bytes, packDir);

      await _finishInstallation(
        config: PackConfig(name: name, slug: slug, svgPathPrefix: svgPathPrefix),
        packDir: packDir,
        version: 'local',
        sourceUrl: 'file://${zipFile.path}',
        onProgress: onProgress,
      );
    } catch (e) {
      await cleanupFailure();
      rethrow;
    }
  }

  Future<void> _finishInstallation({
    required PackConfig config,
    required String packDir,
    required String version,
    required String sourceUrl,
    void Function(String phase, double? fraction)? onProgress,
  }) async {
    onProgress?.call('Indexing…', null);
    final packId = await _db.into(_db.packs).insert(
          PacksCompanion.insert(
            name: config.name,
            version: version,
            iconCount: 0,
            localPath: p.normalize(packDir),
            downloadedAt: Value(DateTime.now()),
            sourceUrl: Value(sourceUrl),
          ),
        );

    final count = await SvgIndexer(_db).indexPackContents(
      packId: packId,
      packRoot: packDir,
      scanSubdir: config.svgPathPrefix,
    );

    await (_db.update(_db.packs)..where((p) => p.id.equals(packId))).write(
      PacksCompanion(iconCount: Value(count)),
    );

    onProgress?.call('Done', 1);
  }
}

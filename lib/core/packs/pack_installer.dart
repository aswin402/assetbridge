import 'dart:io';

import 'package:archive/archive_io.dart';
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

class PackInstaller {
  PackInstaller(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  /// Installs or replaces the given pack from the latest GitHub release.
  Future<void> install({
    required PackConfig config,
    CancelToken? cancelToken,
    void Function(String phase, double? fraction)? onProgress,
  }) async {
    final owner = config.owner;
    final repo = config.repo;
    if (owner == null || repo == null) {
      throw ArgumentError(
          'config.owner and config.repo must be provided for GitHub install');
    }

    final client = GitHubReleaseClient(_dio);
    onProgress?.call('Fetching release…', null);

    var release = await client.fetchLatestRelease(
      owner: owner,
      repo: repo,
      cancelToken: cancelToken,
    );

    // Fallback if no formal release is found (e.g., material-icons source)
    if (release == null) {
      release = GitHubRelease(
        tagName: 'master',
        htmlUrl: 'https://github.com/$owner/$repo',
        zipballUrl: 'https://github.com/$owner/$repo/archive/refs/heads/master.zip',
        assets: [],
      );
    }

    // Check for .sketch assets first if it's a UI kit or if we want to be flexible
    final sketchAsset = release.assets.cast<GitHubReleaseAsset?>().firstWhere(
          (a) => a?.name.toLowerCase().endsWith('.sketch') ?? false,
          orElse: () => null,
        );

    final downloadUrl = sketchAsset?.browserDownloadUrl ?? release.zipballUrl;
    if (downloadUrl.isEmpty) {
      throw StateError('No download URL available for $owner/$repo');
    }

    final isSketch = sketchAsset != null;
    final isUiKit = config.isUiKit || isSketch;

    final packDir = p.join(AppPaths.packsRoot, config.slug);
    await _db.deletePackByName(config.name);
    await _db.removePackDirectoryIfExists(packDir);
    await Directory(packDir).create(recursive: true);

    final tempDir =
        await Directory.systemTemp.createTemp('assetbridge_${config.slug}_');
    final zipFile = File(p.join(tempDir.path, isSketch ? 'kit.sketch' : 'src.zip'));

    Future<void> cleanupFailure() async {
      await _db.deletePackByName(config.name);
      await _db.removePackDirectoryIfExists(packDir);
    }

    try {
      final label = isSketch ? 'Downloading Sketch Kit…' : 'Downloading ${release.tagName}…';
      onProgress?.call(label, 0);
      await _dio.download(
        downloadUrl,
        zipFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            onProgress?.call(label, null);
          } else {
            onProgress?.call(label, received / total);
          }
        },
      );

      if (cancelToken?.isCancelled ?? false) {
        await cleanupFailure();
        return;
      }

      if (isSketch) {
        onProgress?.call('Extracting Sketch bundle…', null);
        final kitFolder = p.join(packDir, config.slug);
        await Directory(kitFolder).create(recursive: true);
        // Use file-based streaming extraction for .sketch as well
        await extractZipFile(zipFile.path, kitFolder);
      } else {
        onProgress?.call('Extracting…', null);
        // Use file-based streaming extraction directly from the temp file.
        // This avoids readAsBytes RAM usage — critical for large packs.
        await extractZipFile(zipFile.path, packDir);
      }

      if (cancelToken?.isCancelled ?? false) {
        await cleanupFailure();
        return;
      }

      await _finishInstallation(
        config: config,
        packDir: packDir,
        version: release.tagName,
        sourceUrl: release.htmlUrl,
        isUiKit: isUiKit,
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

  /// Installs a pack from a local ZIP or Sketch file.
  Future<void> installLocal({
    required File zipFile,
    required String name,
    required String slug,
    String? svgPathPrefix,
    bool isUiKit = false,
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
      final isSketch = zipFile.path.toLowerCase().endsWith('.sketch');

      if (isSketch) {
        onProgress?.call('Extracting Sketch bundle…', null);
        final kitFolder = p.join(packDir, slug);
        await Directory(kitFolder).create(recursive: true);
        await extractZipFile(zipFile.path, kitFolder);
        isUiKit = true;
      } else {
        onProgress?.call('Extracting…', null);
        await extractZipFile(zipFile.path, packDir);
      }

      await _finishInstallation(
        config: PackConfig(
          name: name,
          slug: slug,
          svgPathPrefix: svgPathPrefix,
        ),
        isUiKit: isUiKit,
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

  /// Links an existing local directory as a custom library.
  Future<void> installCustomLibrary({
    required String name,
    required String path,
    bool isUiKit = false,
    void Function(String phase, double? fraction)? onProgress,
  }) async {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    await _db.deletePackByName(name);

    await _finishInstallation(
      config: PackConfig(name: name, slug: slug),
      packDir: path,
      version: 'custom',
      sourceUrl: 'file://$path',
      isUiKit: isUiKit,
      isCustom: true,
      onProgress: onProgress,
    );
  }

  Future<void> _finishInstallation({
    required PackConfig config,
    required String packDir,
    required String version,
    required String sourceUrl,
    bool isUiKit = false,
    bool isCustom = false,
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
            isUiKit: Value(isUiKit),
            isCustom: Value(isCustom),
          ),
        );

    final count = await SvgIndexer(_db).indexPackContents(
      packId: packId,
      packRoot: packDir,
      scanSubdir: config.svgPathPrefix,
    );

    await (_db.update(_db.packs)..where((row) => row.id.equals(packId)))
        .write(PacksCompanion(iconCount: Value(count)));

    onProgress?.call('Done', 1);
  }
}
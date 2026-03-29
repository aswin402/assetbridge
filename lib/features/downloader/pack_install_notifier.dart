import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/pack_repository.dart';
import '../../core/indexer/svg_indexer.dart';
import '../../core/packs/pack_config.dart';
import '../../core/packs/pack_installer.dart';
import '../../core/providers/dio_provider.dart';
import '../../core/providers/toast_provider.dart';

class PackInstallState {
  const PackInstallState({
    this.busy = false,
    this.progress,
    this.progressLabel,
    this.error,
  });

  final bool busy;
  final double? progress;
  final String? progressLabel;
  final String? error;
}

final packInstallProvider =
    NotifierProvider<PackInstallNotifier, Map<String, PackInstallState>>(
  PackInstallNotifier.new,
);

class PackInstallNotifier extends Notifier<Map<String, PackInstallState>> {
  final Map<String, CancelToken?> _cancelTokens = {};

  @override
  Map<String, PackInstallState> build() => {};

  Future<void> install(PackConfig config) async {
    final slug = config.slug;
    final cancelToken = CancelToken();
    _cancelTokens[slug] = cancelToken;

    state = {
      ...state,
      slug: const PackInstallState(
        busy: true,
        progress: 0,
        progressLabel: 'Starting...',
      ),
    };

    try {
      final db = ref.read(appDatabaseProvider);
      final dio = ref.read(dioProvider);
      await PackInstaller(db, dio).install(
        config: config,
        cancelToken: cancelToken,
        onProgress: (phase, fraction) {
          state = {
            ...state,
            slug: PackInstallState(
              busy: true,
              progress: fraction,
              progressLabel: phase,
            ),
          };
        },
      );
      state = {
        ...state,
        slug: const PackInstallState(),
      };
    } catch (e) {
      if (cancelToken.isCancelled) {
        state = {
          ...state,
          slug: const PackInstallState(),
        };
      } else {
        ref.read(toastProvider.notifier).error('Install failed: ${e.toString()}');
        state = {
          ...state,
          slug: PackInstallState(
            busy: false,
            error: e.toString(),
          ),
        };
      }
    } finally {
      _cancelTokens.remove(slug);
    }
  }

  Future<void> installLocal({
    required String name,
    required String path,
    String? svgPathPrefix,
    bool isUiKit = false,
  }) async {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    state = {
      ...state,
      slug: const PackInstallState(
        busy: true,
        progress: 0,
        progressLabel: 'Starting...',
      ),
    };

    try {
      final db = ref.read(appDatabaseProvider);
      final dio = ref.read(dioProvider);
      await PackInstaller(db, dio).installLocal(
        zipFile: File(path),
        name: name,
        slug: slug,
        svgPathPrefix: svgPathPrefix,
        isUiKit: isUiKit,
        onProgress: (phase, fraction) {
          state = {
            ...state,
            slug: PackInstallState(
              busy: true,
              progress: fraction,
              progressLabel: phase,
            ),
          };
        },
      );
      state = {
        ...state,
        slug: const PackInstallState(),
      };
    } catch (e) {
      ref.read(toastProvider.notifier).error('Local install failed: ${e.toString()}');
      state = {
        ...state,
        slug: PackInstallState(
          busy: false,
          error: e.toString(),
        ),
      };
    }
  }

  Future<void> installCustomLibrary({
    required String name,
    required String path,
    bool isUiKit = false,
  }) async {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    state = {
      ...state,
      slug: const PackInstallState(
        busy: true,
        progress: 0,
        progressLabel: 'Linking library...',
      ),
    };

    try {
      final db = ref.read(appDatabaseProvider);
      final dio = ref.read(dioProvider);
      await PackInstaller(db, dio).installCustomLibrary(
        name: name,
        path: path,
        isUiKit: isUiKit,
        onProgress: (phase, fraction) {
          state = {
            ...state,
            slug: PackInstallState(
              busy: true,
              progress: fraction,
              progressLabel: phase,
            ),
          };
        },
      );
      state = {
        ...state,
        slug: const PackInstallState(),
      };
    } catch (e) {
      ref.read(toastProvider.notifier).error('Linking failed: ${e.toString()}');
      state = {
        ...state,
        slug: PackInstallState(
          busy: false,
          error: e.toString(),
        ),
      };
    }
  }

  /// Rescans a custom library folder for new/changed files.
  /// SAFE — only clears DB asset rows then re-indexes. Never touches disk files.
  Future<void> rescanCustomLibrary(Pack pack) async {
    final slug = pack.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    state = {
      ...state,
      slug: const PackInstallState(
        busy: true,
        progressLabel: 'Scanning...',
      ),
    };

    try {
      final db = ref.read(appDatabaseProvider);

      // Only clear DB asset rows — never delete the folder on disk!
      await db.transaction(() async {
        await (db.delete(db.assets)..where((a) => a.packId.equals(pack.id))).go();
      });

      // Re-run the indexer on the existing localPath (no download, no extraction)
      final count = await SvgIndexer(db).indexPackContents(
        packId: pack.id,
        packRoot: pack.localPath,
      );

      // Update icon count
      await (db.update(db.packs)..where((p) => p.id.equals(pack.id)))
          .write(PacksCompanion(iconCount: Value(count)));

      state = {
        ...state,
        slug: const PackInstallState(),
      };
      ref.read(toastProvider.notifier).success(
          'Rescan complete — found $count items in "${pack.name}"');
    } catch (e) {
      ref.read(toastProvider.notifier).error('Rescan failed: ${e.toString()}');
      state = {
        ...state,
        slug: PackInstallState(
          busy: false,
          error: e.toString(),
        ),
      };
    }
  }

  Future<void> delete(String packName, String slug) async {
    state = {
      ...state,
      slug: const PackInstallState(
        busy: true,
        progressLabel: 'Deleting...',
      ),
    };

    try {
      final db = ref.read(appDatabaseProvider);
      await db.deletePackByName(packName);
      state = {
        ...state,
        slug: const PackInstallState(),
      };
    } catch (e) {
      ref.read(toastProvider.notifier).error('Delete failed: ${e.toString()}');
      state = {
        ...state,
        slug: PackInstallState(
          busy: false,
          error: e.toString(),
        ),
      };
    }
  }

  void cancel(String slug) {
    _cancelTokens[slug]?.cancel();
  }

  void clearError(String slug) {
    state = {
      ...state,
      slug: const PackInstallState(),
    };
  }

  Future<void> installFromGithubUrl(String url, {String? name}) async {
    String cleanUrl = url.trim()
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll('github.com/', '');
    if (cleanUrl.endsWith('.git')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 4);
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);

    final parts = cleanUrl.split('/');
    if (parts.length < 2) {
      throw ArgumentError('Invalid GitHub URL: $url. Expected format: github.com/owner/repo');
    }

    final owner = parts[0];
    final repo = parts[1];
    final slug = '${owner}_$repo'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final displayName = name ?? repo;

    final config = PackConfig(
      name: displayName,
      slug: slug,
      owner: owner,
      repo: repo,
    );

    await install(config);
  }
}

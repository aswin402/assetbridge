import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/pack_repository.dart';
import '../../core/packs/pack_config.dart';
import '../../core/packs/pack_installer.dart';
import '../../core/providers/dio_provider.dart';

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
        progressLabel: 'Starting…',
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
        progressLabel: 'Starting…',
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
        progressLabel: 'Deleting…',
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
}

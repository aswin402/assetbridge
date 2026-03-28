import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
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

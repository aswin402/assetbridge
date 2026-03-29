import 'dart:async';

/// Global LRU cache for converted SVG strings.
/// Keyed by asset ID. Holds max [maxSize] entries.
class SvgPreviewCache {
  SvgPreviewCache._();
  static final instance = SvgPreviewCache._();

  static const maxSize = 150;

  final _cache = <int, String>{};
  final _order = <int>[];

  String? get(int assetId) => _cache[assetId];

  void set(int assetId, String svg) {
    if (_cache.containsKey(assetId)) {
      _order.remove(assetId);
    } else if (_cache.length >= maxSize) {
      // Evict oldest
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[assetId] = svg;
    _order.add(assetId);
  }

  bool has(int assetId) => _cache.containsKey(assetId);
}

/// Semaphore that limits concurrent async operations.
class Semaphore {
  Semaphore(this._maxCount) : _currentCount = _maxCount;

  final int _maxCount;
  int _currentCount;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      next.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Global semaphore — max 4 SVG conversions at once.
final svgLoadSemaphore = Semaphore(4);
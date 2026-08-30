import 'dart:async';
import '../services/cache_service.dart';

/// Creates a Stream that serves data from CacheService, auto-refreshes periodically after TTL,
/// and re-fetches immediately when the cache key is invalidated.
Stream<T> createCachedStream<T>({
  required String cacheKey,
  required Duration ttl,
  required Future<T> Function() fetchFn,
}) {
  final controller = StreamController<T>();
  final cache = CacheService();
  Timer? periodicTimer;
  StreamSubscription<String>? invalidationSub;

  Future<void> executeFetch({bool isBackground = false}) async {
    try {
      final data = await cache.getOrFetch<T>(
        cacheKey,
        ttl,
        fetchFn,
        forceRefresh: isBackground,
      );
      if (!controller.isClosed) {
        controller.add(data);
      }
    } catch (e, st) {
      if (!controller.isClosed) {
        // If we don't have any cached data, emit error. Otherwise keep showing cached data
        if (cache.getStale<T>(cacheKey) == null) {
          controller.addError(e, st);
        }
      }
    }
  }

  controller.onListen = () {
    // 1. Emit cached or stale data immediately for instant UI
    final initial = cache.getStale<T>(cacheKey);
    if (initial != null) {
      controller.add(initial);
    }

    // 2. Fetch fresh data if expired or not in cache
    if (initial == null || cache.get<T>(cacheKey) == null) {
      executeFetch();
    }

    // 3. Periodic auto-refresh based on TTL
    periodicTimer = Timer.periodic(ttl, (_) {
      executeFetch(isBackground: true);
    });

    // 4. Listen for manual or event-driven invalidations
    invalidationSub = cache.onInvalidated.listen((invalidatedKey) {
      if (invalidatedKey == '*' ||
          invalidatedKey == cacheKey ||
          cacheKey.startsWith(invalidatedKey) ||
          invalidatedKey.startsWith(cacheKey)) {
        executeFetch(isBackground: true);
      }
    });
  };

  controller.onCancel = () {
    periodicTimer?.cancel();
    invalidationSub?.cancel();
    controller.close();
  };

  return controller.stream;
}

import 'dart:async';

/// Cache entry model with TTL expiration
class CacheEntry<T> {
  final T data;
  final DateTime fetchedAt;
  final Duration ttl;

  CacheEntry(this.data, {required this.ttl, DateTime? fetchedAt})
      : fetchedAt = fetchedAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(fetchedAt) > ttl;
}

/// Central in-memory cache service with TTL and event broadcasting
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry<dynamic>> _cache = {};
  final StreamController<String> _invalidationController =
      StreamController<String>.broadcast();

  Stream<String> get onInvalidated => _invalidationController.stream;

  /// Returns cached value if present and not expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Returns cached value even if expired (stale-while-revalidate)
  T? getStale<T>(String key) {
    final entry = _cache[key];
    return entry?.data as T?;
  }

  /// Store data in cache with given TTL
  void set<T>(String key, T data, Duration ttl) {
    _cache[key] = CacheEntry<T>(data, ttl: ttl);
  }

  /// Returns cached data if valid, otherwise executes fetchFn and caches result
  Future<T> getOrFetch<T>(
    String key,
    Duration ttl,
    Future<T> Function() fetchFn, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = get<T>(key);
      if (cached != null) return cached;
    }
    final fresh = await fetchFn();
    set<T>(key, fresh, ttl);
    return fresh;
  }

  /// Invalidate cache for a specific key and notifies listeners
  void invalidate(String key) {
    _cache.remove(key);
    _invalidationController.add(key);
  }

  /// Invalidate all keys starting with prefix
  void invalidatePrefix(String prefix) {
    _cache.removeWhere((k, _) => k.startsWith(prefix));
    _invalidationController.add(prefix);
  }

  /// Clear entire cache
  void clear() {
    _cache.clear();
    _invalidationController.add('*');
  }
}

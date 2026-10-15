/// Simple in-memory TTL cache for repository responses.
///
/// Used to avoid repeat network calls for frequently reused API data
/// within a session. Disk persistence for auth/saved items stays elsewhere.
class TtlCache<T> {
  TtlCache({required this.ttl});

  final Duration ttl;
  final Map<String, _CacheEntry<T>> _entries = {};

  /// Fresh value when still within [ttl]; otherwise `null`.
  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) return null;
    return entry.value;
  }

  /// Last stored value even if expired (offline / error fallback).
  T? getStale(String key) => _entries[key]?.value;

  bool isFresh(String key) => get(key) != null;

  void set(String key, T value) {
    _entries[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void invalidate([String? key]) {
    if (key == null) {
      _entries.clear();
    } else {
      _entries.remove(key);
    }
  }

  void invalidateWhere(bool Function(String key) test) {
    _entries.removeWhere((key, _) => test(key));
  }
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;
}

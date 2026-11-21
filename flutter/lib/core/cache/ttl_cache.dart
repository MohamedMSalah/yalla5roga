/// Simple in-memory TTL cache for repository responses.
///
/// Used to avoid repeat network calls for frequently reused API data
/// within a session. Disk persistence for auth/saved items stays elsewhere.
class TtlCache<T> {
  TtlCache({required this.ttl, this.maxEntries});

  final Duration ttl;
  final int? maxEntries;
  final Map<String, _CacheEntry<T>> _entries = {};
  static int _nextId = 0;
  final int identity = _nextId++;
  int _revision = 0;
  int get revision => _revision;

  /// Fresh value when still within [ttl]; otherwise `null`.
  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (!DateTime.now().isBefore(entry.expiresAt)) return null;
    return entry.value;
  }

  /// Last stored value even if expired (offline / error fallback).
  T? getStale(String key) => _entries[key]?.value;

  bool isFresh(String key) => get(key) != null;

  void set(String key, T value, {DateTime? fetchedAt}) {
    _entries.remove(key);
    if (maxEntries case final limit?
        when _entries.length >= limit && _entries.isNotEmpty) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = _CacheEntry(
      value: value,
      expiresAt: (fetchedAt ?? DateTime.now()).add(ttl),
    );
  }

  void updateExisting(String key, T Function(T value) update) {
    final entry = _entries[key];
    if (entry != null) {
      _entries[key] = _CacheEntry(
        value: update(entry.value),
        expiresAt: entry.expiresAt,
      );
    }
  }

  void invalidate([String? key]) {
    _revision++;
    if (key == null) {
      _entries.clear();
    } else {
      _entries.remove(key);
    }
  }

  void invalidateWhere(bool Function(String key) test) {
    _revision++;
    _entries.removeWhere((key, _) => test(key));
  }
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;
}

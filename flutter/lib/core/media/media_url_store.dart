import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Visibility of a resolved media asset.
enum MediaVisibility {
  public,
  private;

  static MediaVisibility? parse(Object? value) {
    switch (value) {
      case 'public':
        return MediaVisibility.public;
      case 'private':
        return MediaVisibility.private;
      default:
        return null;
    }
  }
}

/// A resolved delivery URL for a media asset.
///
/// Private assets use short-lived signed URLs, so [expiresAt] is stored to
/// decide when a background refresh is worthwhile. The URL itself can still be
/// used past expiry while an image is available in the persistent disk cache.
class MediaUrlEntry {
  const MediaUrlEntry({
    required this.url,
    required this.visibility,
    this.expiresAt,
  });

  final String url;
  final MediaVisibility visibility;
  final DateTime? expiresAt;

  bool get isPublic => visibility == MediaVisibility.public;

  /// Treat URLs that expire within the next 20 seconds as stale so widgets
  /// refresh ahead of the actual signing window.
  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !expiry.isAfter((now ?? DateTime.now()).add(const Duration(seconds: 20)));
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'visibility': visibility.name,
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
  };

  static MediaUrlEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    if (url is! String || url.trim().isEmpty) return null;
    final visibility = MediaVisibility.parse(raw['visibility']);
    if (visibility == null) return null;
    final expiresAt = DateTime.tryParse('${raw['expires_at'] ?? ''}');
    return MediaUrlEntry(
      url: url,
      visibility: visibility,
      expiresAt: expiresAt,
    );
  }
}

/// Persistent, account-scoped cache of media delivery URLs.
///
/// Stored in SharedPreferences (metadata only — never image bytes) so a fresh
/// launch can render already-cached images before the network answers. The map
/// is keyed by account UID so signing out or switching accounts cannot surface
/// another account's private signed URLs.
class MediaUrlStore {
  MediaUrlStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String _prefix = 'media_delivery_urls_v1';
  static const int _maxEntriesPerAccount = 400;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Map<String, Map<String, MediaUrlEntry>> _loaded = {};

  String _keyFor(String uid) => '${_prefix}_$uid';

  bool isLoaded(String uid) => _loaded.containsKey(uid);

  /// Loads (once) and returns the mutable entry map for [uid].
  Future<Map<String, MediaUrlEntry>> entriesFor(String uid) async {
    final existing = _loaded[uid];
    if (existing != null) return existing;

    final entries = <String, MediaUrlEntry>{};
    final raw = _prefs.getString(_keyFor(uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final item in decoded.entries) {
            final entry = MediaUrlEntry.fromJson(item.value);
            if (entry != null) {
              entries['${item.key}'] = entry;
            }
          }
        }
      } catch (_) {
        // Corrupted cache metadata must never break image rendering.
      }
    }
    _loaded[uid] = entries;
    return entries;
  }

  /// Synchronous peek; returns null until [entriesFor] has loaded the account.
  MediaUrlEntry? peek(String uid, String assetId) => _loaded[uid]?[assetId];

  Future<void> putAll(String uid, Map<String, MediaUrlEntry> entries) async {
    if (entries.isEmpty) return;
    final target = await entriesFor(uid);
    var changed = false;
    for (final item in entries.entries) {
      if (item.key.trim().isEmpty || item.value.url.trim().isEmpty) continue;
      target[item.key] = item.value;
      changed = true;
    }
    if (!changed) return;

    // Bound growth: drop oldest inserted entries beyond the cap.
    while (target.length > _maxEntriesPerAccount) {
      target.remove(target.keys.first);
    }
    await _persist(uid);
  }

  Future<void> remove(String uid, String assetId) async {
    final target = _loaded[uid];
    if (target == null || target.remove(assetId) == null) return;
    await _persist(uid);
  }

  /// Clears all persisted URLs for [uid] and returns what was removed so the
  /// caller can evict the matching on-disk image-cache entries.
  Future<List<MapEntry<String, MediaUrlEntry>>> clearAccount(String uid) async {
    final target = await entriesFor(uid);
    final removed = target.entries.toList(growable: false);
    target.clear();
    _loaded.remove(uid);
    await _prefs.remove(_keyFor(uid));
    return removed;
  }

  /// Removes every account's URL metadata (used by full local-data resets).
  Future<void> clearAll() async {
    _loaded.clear();
    final keys = _prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys.toList(growable: false)) {
      await _prefs.remove(key);
    }
  }

  Future<void> _persist(String uid) async {
    final target = _loaded[uid];
    if (target == null) return;
    final encoded = <String, dynamic>{
      for (final item in target.entries) item.key: item.value.toJson(),
    };
    await _prefs.setString(_keyFor(uid), jsonEncode(encoded));
  }

  /// Exposed for tests and diagnostics.
  DateTime now() => _clock();
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';
import 'package:yalla_5roga/core/network/api_client.dart';

/// Resolves `media://<uuid>` references to short-lived delivery URLs.
///
/// Behaviour:
/// - Persistent URL metadata is read first (fast, works offline).
/// - Expired/near-expiry private URLs are refreshed in the background while
///   the stale URL keeps rendering from the on-disk image cache.
/// - Requests in the same frame are batched through
///   `POST /api/media/signed-urls` (max 50 per call).
/// - On network failure the persisted URL is returned so cached images remain
///   visible offline.
///
/// Image cache identities are derived from the stable asset id (and, for
/// private assets, the account UID) — never from the rotating signed URL.
class MediaUrlResolver extends ChangeNotifier {
  MediaUrlResolver({
    required this.apiClient,
    required this.store,
    required this.uidProvider,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// Process-wide resolver used by leaf image widgets that do not depend on
  /// Provider context. Configured once in `AppDependencies.create`.
  static MediaUrlResolver? active;

  final ApiClient apiClient;
  final MediaUrlStore store;
  final String? Function() uidProvider;
  final DateTime Function() clock;

  final Map<String, Future<MediaUrlEntry?>> _inflight = {};
  final Map<String, _PendingRequest> _pending = {};
  bool _flushScheduled = false;

  String? get currentUserId => uidProvider();

  /// Synchronous lookup from already-loaded metadata (never triggers I/O).
  MediaUrlEntry? peek(String assetId) {
    final uid = uidProvider();
    if (uid == null) return null;
    return store.peek(uid, assetId);
  }

  /// Resolves [reference] when it is a `media://` value; otherwise returns
  /// the value unchanged (http(s) URLs and local previews).
  Future<String?> resolveReference(String? reference) async {
    final text = reference?.trim() ?? '';
    if (text.isEmpty) return null;
    final assetId = parseMediaId(text);
    if (assetId == null) return text;
    final entry = await resolve(assetId);
    return entry?.url;
  }

  /// Resolves one media asset id to a delivery URL.
  Future<MediaUrlEntry?> resolve(String assetId) async {
    final uid = uidProvider();
    if (uid == null || assetId.isEmpty) return null;

    await store.entriesFor(uid);
    final cached = store.peek(uid, assetId);
    if (cached != null) {
      if (cached.isExpired(clock())) {
        // Stale-while-revalidate: render the cached image immediately.
        unawaited(_fetch(uid, assetId));
      }
      return cached;
    }
    return _fetch(uid, assetId);
  }

  /// Forces a fresh signed URL, discarding persisted metadata first.
  Future<MediaUrlEntry?> revalidate(String assetId) async {
    final uid = uidProvider();
    if (uid == null) return null;
    await store.remove(uid, assetId);
    return _fetch(uid, assetId);
  }

  /// Stable image-cache key. Private assets are scoped to the account so one
  /// account can never render another account's cached private image.
  String cacheKeyFor(
    String assetId,
    MediaVisibility visibility, {
    String? uidOverride,
  }) {
    if (visibility == MediaVisibility.public) {
      return 'media_public_$assetId';
    }
    final uid = uidOverride ?? uidProvider() ?? 'guest';
    return 'media_private_${uid}_$assetId';
  }

  /// Drops a single cached URL and evicts its on-disk image (delete/replace).
  Future<void> invalidate(String assetId, {bool evictImage = true}) async {
    final uid = uidProvider();
    if (uid == null) return;
    final entry = store.peek(uid, assetId);
    await store.remove(uid, assetId);
    if (evictImage && entry != null) {
      unawaited(_evict(uid, assetId, entry));
    }
    notifyListeners();
  }

  /// Clears URL metadata and cached private images for [uid]. Called on
  /// logout and account switches; public cache entries are left intact.
  Future<void> clearForAccount(String uid) async {
    final removed = await store.clearAccount(uid);
    for (final item in removed) {
      // Never block logout/account switching on a disk-cache eviction; key
      // isolation already prevents cross-account rendering.
      unawaited(_evict(uid, item.key, item.value));
    }
    notifyListeners();
  }

  Future<void> _evict(String uid, String assetId, MediaUrlEntry entry) async {
    final key = cacheKeyFor(
      assetId,
      entry.visibility,
      uidOverride: uid,
    );
    try {
      await CachedNetworkImage.evictFromCache(entry.url, cacheKey: key)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Eviction is best effort; key isolation still prevents cross-account
      // rendering even if a file cannot be removed.
    }
  }

  Future<MediaUrlEntry?> _fetch(String uid, String assetId) {
    final key = '$uid:$assetId';
    final existing = _inflight[key];
    if (existing != null) return existing;

    final completer = Completer<MediaUrlEntry?>();
    _pending[key] = (uid: uid, assetId: assetId, completer: completer);
    if (!_flushScheduled) {
      _flushScheduled = true;
      scheduleMicrotask(_flush);
    }

    final future = completer.future;
    _inflight[key] = future;
    future.whenComplete(() => _inflight.remove(key));
    return future;
  }

  void _flush() {
    _flushScheduled = false;
    if (_pending.isEmpty) return;
    final pending = Map<String, _PendingRequest>.of(_pending);
    _pending.clear();

    final byUid = <String, List<_PendingRequest>>{};
    for (final request in pending.values) {
      byUid.putIfAbsent(request.uid, () => []).add(request);
    }
    for (final item in byUid.entries) {
      unawaited(_sendBatch(item.key, item.value));
    }
  }

  Future<void> _sendBatch(String uid, List<_PendingRequest> requests) async {
    final ids = <String>{
      for (final request in requests) request.assetId,
    }.toList(growable: false);

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiConstants.mediaSignedUrls,
        data: {'media_ids': ids},
      );
      final body = response.data;
      final raw = body?['data'];
      final entries = <String, MediaUrlEntry>{};
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final json = Map<String, dynamic>.from(item);
          final mediaId = '${json['media_id'] ?? ''}';
          final entry = _entryFromJson(json);
          if (mediaId.isNotEmpty && entry != null) {
            entries[mediaId] = entry;
          }
        }
      }

      await store.putAll(uid, entries);
      for (final request in requests) {
        request.completer.complete(entries[request.assetId]);
      }
      if (entries.isNotEmpty) notifyListeners();
    } catch (_) {
      // Offline / server failure: keep persisted URLs so the disk image cache
      // can still render the asset.
      for (final request in requests) {
        request.completer.complete(store.peek(uid, request.assetId));
      }
    }
  }

  static MediaUrlEntry? _entryFromJson(Map<String, dynamic> json) {
    final url = json['url'];
    if (url is! String || url.trim().isEmpty) return null;
    final visibility =
        MediaVisibility.parse(json['visibility']) ?? MediaVisibility.private;
    final expiresAt = DateTime.tryParse('${json['expires_at'] ?? ''}');
    return MediaUrlEntry(
      url: url,
      visibility: visibility,
      expiresAt: expiresAt,
    );
  }
}

typedef _PendingRequest = ({
  String uid,
  String assetId,
  Completer<MediaUrlEntry?> completer,
});

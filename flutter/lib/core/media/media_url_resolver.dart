import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

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
    Future<bool> Function(String url, {String? cacheKey})? evictCachedImage,
  }) : clock = clock ?? DateTime.now,
       _evictCachedImage = evictCachedImage ?? _removeCachedImage;

  /// Process-wide resolver used by leaf image widgets that do not depend on
  /// Provider context. Configured once in `AppDependencies.create`.
  static MediaUrlResolver? active;

  final ApiClient apiClient;
  final MediaUrlStore store;
  final String? Function() uidProvider;
  final DateTime Function() clock;
  final Future<bool> Function(String url, {String? cacheKey}) _evictCachedImage;

  final Map<String, Future<MediaUrlEntry?>> _inflight = {};
  final Map<String, _PendingRequest> _pending = {};
  bool _flushScheduled = false;
  int _accountGeneration = 0;

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

    final generation = _accountGeneration;
    await store.entriesFor(uid);
    if (!_isCurrent(uid, generation)) return null;
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

  /// Refreshes the capability while retaining the offline fallback.
  Future<MediaUrlEntry?> revalidate(String assetId) async {
    final uid = uidProvider();
    if (uid == null) return null;
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
    _accountGeneration++;
    final removed = await store.clearAccount(uid);
    for (final item in removed) {
      if (item.value.visibility == MediaVisibility.public) continue;
      // Never block logout/account switching on a disk-cache eviction; key
      // isolation already prevents cross-account rendering.
      unawaited(_evict(uid, item.key, item.value));
    }
    notifyListeners();
  }

  Future<void> _evict(String uid, String assetId, MediaUrlEntry entry) async {
    final key = cacheKeyFor(assetId, entry.visibility, uidOverride: uid);
    try {
      await _evictCachedImage(
        entry.url,
        cacheKey: key,
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Eviction is best effort; key isolation still prevents cross-account
      // rendering even if a file cannot be removed.
    }
  }

  static Future<bool> _removeCachedImage(String url, {String? cacheKey}) async {
    final provider = CachedNetworkImageProvider(url, cacheKey: cacheKey);
    final inMemory = await provider.evict();
    await DefaultCacheManager().removeFile(cacheKey ?? url);
    return inMemory;
  }

  Future<MediaUrlEntry?> _fetch(String uid, String assetId) {
    final generation = _accountGeneration;
    final key = '$generation:$uid:$assetId';
    final existing = _inflight[key];
    if (existing != null) return existing;

    final completer = Completer<MediaUrlEntry?>();
    _pending[key] = (
      uid: uid,
      generation: generation,
      assetId: assetId,
      completer: completer,
    );
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
      if (!_isCurrent(request.uid, request.generation)) {
        request.completer.complete(null);
        continue;
      }
      byUid.putIfAbsent(request.uid, () => []).add(request);
    }
    for (final item in byUid.entries) {
      const limit = 50;
      final requests = item.value;
      for (var start = 0; start < requests.length; start += limit) {
        unawaited(
          _sendBatch(item.key, requests.skip(start).take(limit).toList()),
        );
      }
    }
  }

  Future<void> _sendBatch(String uid, List<_PendingRequest> requests) async {
    final generation = requests.first.generation;
    final ids = <String>{for (final request in requests) request.assetId}
        .toList(growable: false);

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiConstants.mediaSignedUrls,
        data: {'media_ids': ids},
        options: Options(extra: {expectedUserIdKey: uid}),
      );
      if (!_isCurrent(uid, generation)) {
        for (final request in requests) {
          request.completer.complete(null);
        }
        return;
      }
      final body = response.data;
      final raw = body?['data'];
      final entries = <String, MediaUrlEntry>{};
      if (raw is! List) throw const FormatException('Invalid media batch');
      for (final item in raw) {
        if (item is! Map) throw const FormatException('Invalid media result');
        final json = Map<String, dynamic>.from(item);
        final mediaId = '${json['media_id'] ?? ''}';
        final entry = _entryFromJson(json);
        if (!ids.contains(mediaId) || entry == null) {
          throw const FormatException('Invalid media result');
        }
        entries[mediaId] = entry;
      }

      await store.putAll(uid, entries);
      var removed = false;
      for (final id in ids) {
        if (!_isCurrent(uid, generation)) break;
        final previous = store.peek(uid, id);
        if (entries.containsKey(id) ||
            previous == null ||
            previous.visibility != MediaVisibility.private) {
          continue;
        }
        await store.remove(uid, id);
        unawaited(_evict(uid, id, previous));
        removed = true;
      }
      final current = _isCurrent(uid, generation);
      for (final request in requests) {
        request.completer.complete(current ? entries[request.assetId] : null);
      }
      if (current && (entries.isNotEmpty || removed)) notifyListeners();
    } catch (_) {
      // Offline / server failure: keep persisted URLs so the disk image cache
      // can still render the asset.
      for (final request in requests) {
        request.completer.complete(
          _isCurrent(uid, generation) ? store.peek(uid, request.assetId) : null,
        );
      }
    }
  }

  bool _isCurrent(String uid, int generation) =>
      uid == uidProvider() && generation == _accountGeneration;

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
  int generation,
  String assetId,
  Completer<MediaUrlEntry?> completer,
});

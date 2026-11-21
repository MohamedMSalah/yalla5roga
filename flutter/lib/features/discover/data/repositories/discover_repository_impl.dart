import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:yalla_5roga/features/discover/data/datasources/places_local_store.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class DiscoverRepositoryImpl
    implements DiscoverRepository, OfflinePlaceCatalog, ViewportCatalog {
  DiscoverRepositoryImpl({
    required this.remote,
    required this.networkInfo,
    this.local,
  });

  final DiscoverRemoteDataSource remote;
  final NetworkInfo networkInfo;
  final PlacesLocalStore? local;
  final _reads = RequestDeduper();
  final _changes = StreamController<void>.broadcast();
  final _knownPlaces = <String, SuggestedPlace>{};
  static const _interval = Duration(hours: 24);
  final _recommendations = TtlCache<List<SuggestedPlace>>(
    ttl: CachePolicy.placeRecommendations,
    maxEntries: 12,
  );
  static const _homeKey = 'placeRecommendations';

  @override
  List<SuggestedPlace>? cachedRecommendations() =>
      _recommendations.getStale(_homeKey);

  @override
  Future<List<SuggestedPlace>?> restoreRecommendations() async {
    try {
      final snapshot = await local?.recommendations();
      if (snapshot != null && cachedRecommendations() == null) {
        _recommendations.set(
          _homeKey,
          snapshot.places.map(remote.parsePlace).toList(growable: false),
          fetchedAt: snapshot.fetchedAt,
        );
      }
    } catch (_) {
      // A disk cache failure should leave the normal HTTPS read available.
    }
    final cached = cachedRecommendations();
    if (cached != null) return cached;
    try {
      final rows = await local?.places(const PlaceFilters(), limit: 8) ?? [];
      return rows.isEmpty ? null : rows.map(remote.parsePlace).toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getRecommendations({
    bool forceRefresh = false,
  }) => cachedRemote(
    networkInfo: networkInfo,
    cache: _recommendations,
    key: _homeKey,
    deduper: _reads,
    forceRefresh: forceRefresh,
    offlineRead: true,
    fetch: () async {
      final rows = await remote.recommendations();
      unawaited(
        local?.storeRecommendations(rows).catchError((_) {}) ??
            Future<void>.value(),
      );
      return rows.map(remote.parsePlace).toList(growable: false);
    },
  );

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getNearbyRecommendations({
    required double latitude,
    required double longitude,
  }) {
    final lat = latitude.toStringAsFixed(2);
    final lng = longitude.toStringAsFixed(2);
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _recommendations,
      key: '$_homeKey:$lat,$lng',
      deduper: _reads,
      offlineRead: true,
      fetch: () async {
        final rows = await remote.recommendations(
          latitude: lat,
          longitude: lng,
        );
        return rows.map(remote.parsePlace).toList(growable: false);
      },
    );
  }

  String? _catalogVersion;
  DateTime? _nextVersionCheck;
  Future<void>? _checkingVersion;
  bool _loadedViewport = false;

  @override
  Stream<void> get catalogChanges => _changes.stream;

  @override
  Future<void> checkCatalogVersion() => _checkingVersion ??= _checkVersion()
      .whenComplete(() => _checkingVersion = null);

  Future<void> _checkVersion() async {
    final now = DateTime.now();
    if (!_loadedViewport || (_nextVersionCheck?.isAfter(now) ?? false)) return;
    _nextVersionCheck = now.add(const Duration(minutes: 15));
    try {
      final version = await remote.catalogVersion();
      if (version != null &&
          _catalogVersion != null &&
          version != _catalogVersion) {
        await _regionQueue;
        await local?.invalidateCoverage();
        _viewportCache.invalidate();
        _definitionsCache.invalidate();
        _placeCache.invalidate();
        _placesCache.invalidate();
        _knownPlaces.clear();
        _changes.add(null);
      }
      _catalogVersion = version;
    } catch (_) {
      // Cached pages and explicit offline downloads remain usable.
    }
  }

  @override
  Future<({double lat, double lng, double? accuracy})?> previousFix(
    String owner,
  ) async {
    final row = await local?.previousFix(owner);
    if (row == null) return null;
    return (
      lat: row['lat'] as double,
      lng: row['lng'] as double,
      accuracy: row['accuracy'] as double?,
    );
  }

  @override
  Future<void> rememberFix(
    String owner,
    double lat,
    double lng,
    double? accuracy,
    DateTime measured,
  ) async {
    await local?.rememberFix(owner, lat, lng, accuracy, measured);
  }

  int _regionRevision = 0;
  Future<void> _regionQueue = Future.value();

  @override
  Future<void> savePrivate(String owner, SuggestedPlace p) =>
      local!.savePrivate(
        owner,
        p.id,
        p.name,
        p.latitude!,
        p.longitude!,
        p.categoryId,
        p.address,
      );
  @override
  Future<void> deletePrivate(String owner, String id) =>
      local!.deletePrivate(owner, id);

  @override
  Stream<List<SuggestedPlace>> viewport(
    PlaceFilters filters, {
    required Future<void> cancelled,
    String? owner,
    bool privateOnly = false,
  }) async* {
    var obsolete = false;
    unawaited(cancelled.then((_) => obsolete = true));
    final store = local;
    final bounds = filters.bounds!;
    if (store == null || await store.open() == null) {
      if (privateOnly) {
        yield [];
        return;
      }
      if (!await networkInfo.isConnected) {
        yield [];
        return;
      }
      final rows = await _regionRecords(bounds, () => obsolete, cancelled);
      if (!obsolete) {
        yield rows
            .map(remote.parsePlace)
            .where((p) => filters.matches(p.toOutingPlace()))
            .toList();
      }
      return;
    }
    Future<List<SuggestedPlace>> snapshot() async {
      final timer = kDebugMode ? (Stopwatch()..start()) : null;
      final rows = privateOnly
          ? <Map<String, dynamic>>[]
          : await store.places(filters, limit: -1);
      var private = <Map<String, dynamic>>[];
      if (owner != null) {
        try {
          private = await store.privatePlaces(owner, filters);
        } catch (_) {
          if (privateOnly) rethrow;
        }
      }
      if (kDebugMode) {
        debugPrint(
          'Map SQLite viewport ${timer!.elapsedMilliseconds} ms rows=${rows.length + private.length}',
        );
      }
      return [
        ...rows.map(remote.parsePlace),
        ...private
            .map(remote.parsePlace)
            .where((p) => filters.matches(p.toOutingPlace())),
      ];
    }

    final before = _regionRevision;
    final cached = await snapshot();
    if (obsolete) return;
    if (cached.isNotEmpty || privateOnly) yield cached;
    if (privateOnly) return;

    // Serialize overlapping geographic reads, then subtract coverage inside the lock.
    final operation = _regionQueue.then((_) async {
      if (obsolete) return;
      final missing = await store.missing(bounds);
      RequestDiagnostics.instance.recordLocal(
        method: 'GET', endpoint: '/api/places', feature: 'Discover',
        source: 'PlacesLocalStore',
        outcome: missing.isEmpty ? RequestOutcome.cache : RequestOutcome.cacheMiss,
      );
      _loadedViewport = true;
      for (final region in missing) {
        if (obsolete || !await networkInfo.isConnected) return;
        final rows = await _regionRecords(region.key, () => obsolete, cancelled);
        final timer = kDebugMode ? (Stopwatch()..start()) : null;
        if (obsolete) return;
        await store.completeRegion(region, rows);
        if (kDebugMode) {
          debugPrint(
            'Map SQLite bulk upsert ${timer!.elapsedMilliseconds} ms rows=${rows.length}',
          );
        }
        _regionRevision++;
      }
      if (missing.isNotEmpty && !obsolete) await store.evictOutside(bounds);
    });
    _regionQueue = operation.catchError((_) {});
    await operation;
    if (!obsolete && (before != _regionRevision || cached.isEmpty)) {
      yield await snapshot();
    }
  }

  Future<List<Map<String, dynamic>>> _regionRecords(
    String bounds,
    bool Function() obsolete,
    Future<void> cancelled,
  ) async {
    final records = <String, Map<String, dynamic>>{};
    final cursors = <String>{};
    String? cursor;
    do {
      if (obsolete()) throw const NetworkException();
      final page = await remote.areaPage(bounds, cursor, compact: true, cancelled: cancelled);
      for (final row in page.rows) {
        records[row['id'] as String] = row;
      }
      cursor = page.cursor;
      if (cursor != null && !cursors.add(cursor)) {
        throw const FormatException('Repeated viewport cursor');
      }
    } while (cursor != null);
    return records.values.toList();
  }

  final _savedCache = TtlCache<List<SuggestedPlace>>(ttl: CachePolicy.discover);
  @override
  Future<Either<Failure, List<SuggestedPlace>>> getSavedPlaces({
    bool forceRefresh = false,
  }) => cachedRemote(
    networkInfo: networkInfo,
    cache: _savedCache,
    key: 'discoverSavedPlaces',
    forceRefresh: forceRefresh,
    offlineRead: true,
    fetch: remote.savedPlaces,
  );

  @override
  Future<Either<Failure, void>> setPlaceSaved(String id, bool saved) async {
    if (id.startsWith('private:')) {
      return const Left(NetworkFailure('Device-local place'));
    }
    final result = await guardRemote(
      networkInfo,
      () => remote.setSaved(id, saved),
      reason: 'savePlace',
    );
    if (result.isRight()) _savedCache.invalidate();
    return result;
  }

  final _definitionsCache = TtlCache<List<CatalogDefinition>>(ttl: _interval);

  @override
  Future<Either<Failure, List<CatalogDefinition>>> getDefinitions(
    String kind, {
    bool forceRefresh = false,
  }) async {
    final singular = kind == 'vibes' ? 'vibe' : 'category';
    final records = await local?.definitions(singular) ?? [];
    if (!forceRefresh && records.isNotEmpty) {
      return Right(records.map(CatalogDefinition.fromJson).toList());
    }
    final result = await cachedRemote(
      networkInfo: networkInfo,
      cache: _definitionsCache,
      key: 'placeDefinitions:$kind',
      deduper: _reads,
      forceRefresh: forceRefresh,
      offlineRead: true,
      fetch: () async {
        final rows = await remote.definitionRecords(kind);
        await local?.seed(singular, rows);
        return rows.map(CatalogDefinition.fromJson).toList();
      },
    );
    return records.isEmpty
        ? result
        : result.fold(
            (_) => Right(records.map(CatalogDefinition.fromJson).toList()),
            Right.new,
          );
  }

  @override
  Future<Either<Failure, List<SuggestedPlace>>> queryPlaces(
    PlaceFilters filters, {
    int offset = 0,
    bool forceRefresh = false,
    Future<void>? cancelled,
  }) => filters.compact
      ? _viewport(filters, offset, forceRefresh, cancelled)
      : _query(
          filters,
          offset: offset,
          limit: filters.pageSize,
          forceRefresh: forceRefresh,
          cancelled: cancelled,
        );

  final _viewportCache = TtlCache<List<SuggestedPlace>>(
    ttl: const Duration(minutes: 5),
    maxEntries: 32,
  );

  Future<Either<Failure, List<SuggestedPlace>>> _viewport(
    PlaceFilters filters,
    int offset,
    bool forceRefresh,
    Future<void>? cancelled,
  ) async {
    final key = filters.key(offset);
    final fresh = _viewportCache.get(key);
    if (!forceRefresh && fresh != null) return Right(fresh);

    final version = _catalogVersion;
    var obsolete = false;
    if (cancelled != null) unawaited(cancelled.then((_) => obsolete = true));
    final result = await guardRemote(
      networkInfo,
      () async {
        final rows = await remote.queryRecords(
          filters.query(offset: offset),
          useSnapshots: false,
          cancelled: cancelled,
        );
        return rows.map(remote.parsePlace).toList(growable: false);
      },
      reason: 'discoverViewport',
      offlineRead: true,
    );
    if (obsolete) return const Left(NetworkFailure('Viewport superseded'));
    return result.fold(
      (failure) async {
        final stale = _viewportCache.getStale(key);
        if (stale != null) return Right(stale);
        try {
          final rows = await local?.places(
            filters,
            skip: offset,
            limit: filters.pageSize,
          );
          if (rows != null && rows.isNotEmpty) {
            return Right(rows.map(remote.parsePlace).toList(growable: false));
          }
        } catch (_) {
          // A failed disk fallback must still complete the viewport request.
        }
        return Left(failure);
      },
      (places) async {
        if (version == _catalogVersion) {
          _loadedViewport = true;
          _viewportCache.set(key, places);
          _remember(places);
        }
        return Right(places);
      },
    );
  }

  Future<Either<Failure, List<SuggestedPlace>>> _query(
    PlaceFilters filters, {
    int offset = 0,
    required int limit,
    bool featured = false,
    OutingVibe? vibe,
    bool localOnly = false,
    bool forceRefresh = false,
    Future<void>? cancelled,
  }) async {
    var obsolete = false;
    if (cancelled != null) unawaited(cancelled.then((_) => obsolete = true));
    final records =
        await local?.places(
          filters,
          skip: offset,
          limit: limit,
          featured: featured,
          vibe: vibe,
        ) ??
        [];
    List<SuggestedPlace> convert(List<Map<String, dynamic>> rows) {
      final places = rows.map(remote.parsePlace).toList(growable: false);
      _remember(places);
      return places;
    }

    final state = await local?.state();
    if (localOnly && records.isNotEmpty) {
      return Right(convert(records));
    }
    if (localOnly && state != null) return const Right([]);

    final params = {
      ...filters.query(offset: offset),
      'limit': limit.clamp(1, 100),
      if (featured) 'featured': 'true',
      if (vibe != null) 'vibe': vibe.name,
    };
    final key = RequestDeduper.keyFor(
      method: 'GET',
      path: 'places',
      query: params,
    );
    final result = await cachedRemote(
      networkInfo: networkInfo,
      cache: _placesCache,
      key: key,
      deduper: _reads,
      forceRefresh: forceRefresh,
      offlineRead: true,
      reason: 'discoverQuery',
      fetch: () async {
        if (obsolete) throw const NetworkException();
        _requireDemandAvailable();
        try {
          final rows = await RequestScope.run(() => remote.queryRecords(params,
            useSnapshots: state == null, cancelled: cancelled),
            origin: 'DiscoverRepositoryImpl', trigger: offset > 0 ? 'pagination' :
              filters.search.trim().isNotEmpty ? 'search' : null);
          if (obsolete) throw const NetworkException();
          await local?.seed('place', rows);
          return convert(rows);
        } catch (error) {
          if (error is NetworkException && !obsolete) _holdFailedDemand();
          rethrow;
        }
      },
    );
    return records.isEmpty
        ? result
        : result.fold((_) => Right(convert(records)), Right.new);
  }

  static const _demandBackoff = Duration(seconds: 15);
  DateTime? _demandRetryAfter;
  void _requireDemandAvailable() {
    if (_demandRetryAfter?.isAfter(DateTime.now()) ?? false) {
      throw const NetworkException();
    }
  }

  void _holdFailedDemand() {
    _demandRetryAfter = DateTime.now().add(_demandBackoff);
  }

  void _remember(Iterable<SuggestedPlace> items) {
    for (final place in items) {
      _knownPlaces[place.id] = place;
    }
    while (_knownPlaces.length > 160) {
      _knownPlaces.remove(_knownPlaces.keys.first);
    }
  }

  final _placesCache = TtlCache<List<SuggestedPlace>>(
    ttl: _interval,
    maxEntries: 48,
  );
  final _placeCache = TtlCache<SuggestedPlace>(ttl: _interval, maxEntries: 96);

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    OutingVibe? vibe,
  }) => _query(
    PlaceFilters(latitude: latitude, longitude: longitude, radiusKm: 5),
    limit: 6,
    vibe: vibe,
    localOnly: true,
  );

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getPlaces({
    OutingVibe? vibe,
    bool forceRefresh = false,
  }) => _query(
    const PlaceFilters(),
    limit: 12,
    vibe: vibe,
    forceRefresh: forceRefresh,
  );

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getFeaturedPlaces({
    bool forceRefresh = false,
  }) => _query(const PlaceFilters(), limit: 6, featured: true, localOnly: true);

  @override
  Future<Either<Failure, SuggestedPlace>> getPlace(
    String placeId, {
    bool forceRefresh = false,
  }) async {
    final record = await local?.place(placeId);
    final cached = record == null
        ? _knownPlaces[placeId]
        : remote.parsePlace(record);
    if (cached != null &&
        (record?.containsKey('place_images') == true ||
            !await networkInfo.isConnected)) {
      return Right(cached);
    }

    final result = await cachedRemote(
      networkInfo: networkInfo,
      cache: _placeCache,
      key: placeId,
      deduper: _reads,
      offlineRead: true,
      fetch: () async {
        try {
          final state = await local?.state();
          if (state != null) _requireDemandAvailable();
          final row = await remote.placeRecord(
            placeId,
            useSnapshots: state == null,
          );
          await local?.seed('place', [row], detailed: true);
          return remote.parsePlace(row);
        } on NetworkException {
          _holdFailedDemand();
          rethrow;
        }
      },
    );
    return cached == null
        ? result
        : result.fold((_) => Right(cached), (place) => Right(place));
  }

  @override
  Stream<List<SuggestedPlace>> placesForOfflineRegion(String bounds) async* {
    final store = local;
    if (store == null || await store.open() == null) {
      throw StateError('Offline catalog storage unavailable');
    }
    if ((await store.state())?.syncedAt != null) {
      final filters = PlaceFilters(bounds: bounds);
      for (var offset = 0; ; offset += 100) {
        final rows = await store.places(filters, skip: offset, limit: 100);
        if (rows.isEmpty) return;
        yield rows.map(remote.parsePlace).toList();
        if (rows.length < 100) return;
      }
    }
    String? cursor;
    do {
      if (!await networkInfo.isConnected) throw const NetworkException();
      final page = await remote.areaPage(bounds, cursor);
      await store.seed('place', page.rows, detailed: true);
      yield page.rows.map(remote.parsePlace).toList();
      cursor = page.cursor;
    } while (cursor != null);
  }

  @override
  List<Place> catalogPlaces() => [
    for (final place in _knownPlaces.values)
      if (place.status == 'active') place.toOutingPlace(),
  ];

  @override
  void clearCache() => _savedCache.invalidate();
}

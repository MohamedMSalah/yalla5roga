import 'package:dartz/dartz.dart';

import 'dart:async';

import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  DiscoverRepositoryImpl({required this.remote, required this.networkInfo});

  final DiscoverRemoteDataSource remote;
  final NetworkInfo networkInfo;
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
    final result = await guardRemote(
      networkInfo,
      () => remote.setSaved(id, saved),
      reason: 'savePlace',
    );
    if (result.isRight()) _savedCache.invalidate();
    return result;
  }

  final _changes = StreamController<void>.broadcast();
  final _knownPlaces = <String, SuggestedPlace>{};
  String? _version;
  Future<void>? _checkingVersion;
  @override
  Stream<void> get catalogChanges => _changes.stream;
  @override
  Future<void> checkCatalogVersion() => _checkingVersion ??= _checkVersion()
      .whenComplete(() => _checkingVersion = null);
  Future<void> _checkVersion() async {
    if (!await networkInfo.isConnected) return;
    try {
      final version = await remote.catalogVersion();
      if (version != _version) {
        _version = version;
        clearCache();
        _changes.add(null);
      }
    } catch (_) {
      /* Existing snapshots remain usable until the next recovery. */
    }
  }

  final _definitionsCache = TtlCache<List<CatalogDefinition>>(
    ttl: CachePolicy.discover,
  );
  @override
  Future<Either<Failure, List<CatalogDefinition>>> getDefinitions(
    String kind, {
    bool forceRefresh = false,
  }) => cachedRemote(
    networkInfo: networkInfo,
    cache: _definitionsCache,
    key: 'placeDefinitions:$kind',
    forceRefresh: forceRefresh,
    offlineRead: true,
    fetch: () => remote.definitions(kind),
  );
  @override
  Future<Either<Failure, List<SuggestedPlace>>> queryPlaces(
    PlaceFilters filters, {
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final result = await cachedRemote(
      networkInfo: networkInfo,
      cache: _placesCache,
      key: 'catalog:${filters.key(offset)}',
      forceRefresh: forceRefresh,
      offlineRead: true,
      fetch: () => remote.queryPlaces(filters, offset),
    );
    result.fold((_) {}, (places) {
      for (final place in places) {
        _knownPlaces[place.id] = place;
      }
    });
    if (result.isLeft() &&
        !await networkInfo.isConnected &&
        _knownPlaces.isNotEmpty) {
      final matches = _knownPlaces.values
          .where((p) => filters.matches(p.toOutingPlace()))
          .toList();
      return Right(matches.skip(offset).take(50).toList());
    }
    return result;
  }

  final _placesCache = TtlCache<List<SuggestedPlace>>(
    ttl: CachePolicy.discover,
  );
  final _featuredCache = TtlCache<List<SuggestedPlace>>(
    ttl: CachePolicy.discover,
  );
  final _placeCache = TtlCache<SuggestedPlace>(ttl: CachePolicy.discover);

  static const _featuredKey = 'featured';

  String _placesKey(OutingVibe? vibe) => 'places:${vibe?.name ?? 'all'}';

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    OutingVibe? vibe,
  }) {
    return guardRemote(
      networkInfo,
      () => remote.getNearbyPlaces(
        latitude: latitude,
        longitude: longitude,
        vibe: vibe,
      ),
      reason: 'discoverNearbyPlaces',
    );
  }

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getPlaces({
    OutingVibe? vibe,
    bool forceRefresh = false,
  }) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _placesCache,
      key: _placesKey(vibe),
      forceRefresh: forceRefresh,
      reason: 'discoverPlaces',
      feature: 'discover',
      source: 'DiscoverRepositoryImpl',
      fetch: () => remote.getPlaces(vibe: vibe),
    );
  }

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getFeaturedPlaces({
    bool forceRefresh = false,
  }) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _featuredCache,
      key: _featuredKey,
      forceRefresh: forceRefresh,
      reason: 'discoverFeatured',
      feature: 'discover',
      source: 'DiscoverRepositoryImpl',
      fetch: remote.getFeaturedPlaces,
    );
  }

  @override
  Future<Either<Failure, SuggestedPlace>> getPlace(
    String placeId, {
    bool forceRefresh = false,
  }) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _placeCache,
      key: placeId,
      forceRefresh: forceRefresh,
      offlineRead: true,
      reason: 'discoverPlace',
      feature: 'discover',
      source: 'DiscoverRepositoryImpl',
      fetch: () => remote.getPlace(placeId),
    );
  }

  @override
  List<Place> catalogPlaces() => _knownPlaces.isNotEmpty
      ? _knownPlaces.values
            .where((p) => p.status == 'active')
            .map((p) => p.toOutingPlace())
            .toList()
      : remote.catalogPlaces();

  @override
  void clearCache() {
    _savedCache.invalidate();
    _knownPlaces.clear();
    _definitionsCache.invalidate();
    _placesCache.invalidate();
    _featuredCache.invalidate();
    _placeCache.invalidate();
  }
}

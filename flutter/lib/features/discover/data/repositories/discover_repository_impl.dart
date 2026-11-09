import 'package:dartz/dartz.dart';
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

class DiscoverRepositoryImpl implements DiscoverRepository {
  DiscoverRepositoryImpl({required this.remote, required this.networkInfo});

  final DiscoverRemoteDataSource remote;
  final NetworkInfo networkInfo;

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
      reason: 'discoverPlace',
      feature: 'discover',
      source: 'DiscoverRepositoryImpl',
      fetch: () => remote.getPlace(placeId),
    );
  }

  @override
  List<Place> catalogPlaces() => remote.catalogPlaces();

  @override
  void clearCache() {
    _placesCache.invalidate();
    _featuredCache.invalidate();
    _placeCache.invalidate();
  }
}

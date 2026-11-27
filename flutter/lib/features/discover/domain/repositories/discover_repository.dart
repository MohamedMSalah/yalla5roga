import 'package:dartz/dartz.dart';

import 'dart:async';

import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';

typedef RatingPlacePage = ({
  List<SuggestedPlace> places,
  String? nextCursor,
  bool? rankingAvailable,
});

abstract interface class ViewportCatalog {
  Future<({double lat, double lng, double? accuracy})?> previousFix(
    String owner,
  );
  Future<void> rememberFix(
    String owner,
    double lat,
    double lng,
    double? accuracy,
    DateTime measured,
  );
  Stream<List<SuggestedPlace>> viewport(
    PlaceFilters filters, {
    required Future<void> cancelled,
    String? owner,
    bool privateOnly = false,
  });
  Future<void> savePrivate(String owner, SuggestedPlace place);
  Future<void> deletePrivate(String owner, String id);
}

abstract interface class OfflinePlaceCatalog {
  Stream<List<SuggestedPlace>> placesForOfflineRegion(String bounds);
}

abstract class DiscoverRepository {
  List<SuggestedPlace>? cachedRecommendations();
  Future<List<SuggestedPlace>?> restoreRecommendations();
  Future<Either<Failure, List<SuggestedPlace>>> getRecommendations({
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<SuggestedPlace>>> getNearbyRecommendations({
    required double latitude,
    required double longitude,
  });
  Future<Either<Failure, List<SuggestedPlace>>> getSavedPlaces({
    bool forceRefresh = false,
  });
  Future<Either<Failure, void>> setPlaceSaved(String id, bool saved);
  Stream<void> get catalogChanges;
  Future<void> checkCatalogVersion({bool force = false});
  Future<Either<Failure, List<CatalogDefinition>>> getDefinitions(
    String kind, {
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<SuggestedPlace>>> queryPlaces(
    PlaceFilters filters, {
    int offset = 0,
    bool forceRefresh = false,
    Future<void>? cancelled,
  });
  Future<Either<Failure, RatingPlacePage>> queryRatingPage(
    PlaceFilters filters, {
    String? cursor,
    Future<void>? cancelled,
  });
  Future<Either<Failure, List<SuggestedPlace>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    OutingVibe? vibe,
  });

  Future<Either<Failure, List<SuggestedPlace>>> getPlaces({
    OutingVibe? vibe,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<SuggestedPlace>>> getFeaturedPlaces({
    bool forceRefresh = false,
  });

  Future<Either<Failure, SuggestedPlace>> getPlace(
    String placeId, {
    bool forceRefresh = false,
  });

  List<Place> catalogPlaces();

  void clearCache();
}

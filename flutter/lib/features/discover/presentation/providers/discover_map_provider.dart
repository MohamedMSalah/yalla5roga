import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';

/// Mounted Discover state, sharing the existing cancellable catalog/cache path.
class DiscoverMapProvider extends PlaceCatalogProvider {
  DiscoverMapProvider(super.repository, {required this.location})
    : super(searchAcrossBounds: true) {
    mapController.addListener(_mapStateChanged);
  }

  void _mapStateChanged() {
    // A basemap failure must not prevent cached database cards from loading.
    if (mapController.failed && !hasQueried) load();
  }

  final MapLocation location;
  String? selectedPlaceId;
  LatLng? userLocation;
  MapLocationIssue? locationIssue;
  bool locating = false;
  bool hasQueried = false;
  bool _alive = true;
  bool _followViewport = true;
  String? _visibleBounds;

  SuggestedPlace? get selectedPlace =>
      places.where((p) => p.id == selectedPlaceId).firstOrNull;

  void select(SuggestedPlace place) {
    if (place.id == selectedPlaceId) return;
    selectedPlaceId = place.id;
    // Selection camera movements must not refetch/reorder the carousel.
    _followViewport = false;
    notifyListeners();
    if (place.latitude != null && place.longitude != null) {
      mapController.focusSelection(LatLng(place.latitude!, place.longitude!));
    }
  }

  @override
  void cameraMoving() {
    _followViewport = true;
    // Search spans the catalog, so a pan must not retire its pending request.
    if (filters.search.trim().isNotEmpty) return;
    super.cameraMoving();
  }

  @override
  void setBounds(String value) {
    _visibleBounds = value;
    if (!_followViewport || filters.search.trim().isNotEmpty) return;
    super.setBounds(value);
  }

  void search(String value) {
    if (value == filters.search) return;
    selectedPlaceId = null;
    if (value.trim().isEmpty) _followViewport = true;
    update(
      filters.copyWith(
        search: value,
        bounds: value.trim().isEmpty ? _visibleBounds : null,
      ),
      debounce: true,
    );
  }

  @override
  Future<void> update(PlaceFilters value, {bool debounce = false}) {
    // A changed search/filter is a new result set; camera focus isn't one.
    selectedPlaceId = null;
    return super.update(value, debounce: debounce);
  }

  double? distanceKm(SuggestedPlace place) {
    final origin = userLocation;
    if (origin == null || place.latitude == null || place.longitude == null) {
      return null;
    }
    return const Distance().as(
      LengthUnit.Kilometer,
      origin,
      LatLng(place.latitude!, place.longitude!),
    );
  }

  @override
  Future<void> load({bool more = false, bool force = false}) async {
    hasQueried = true;
    await super.load(more: more, force: force);
    if (!_alive) return;
    if (userLocation != null) {
      places = List<SuggestedPlace>.of(places)
        ..sort((a, b) {
          final order = (distanceKm(a) ?? double.infinity).compareTo(
            distanceKm(b) ?? double.infinity,
          );
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
    }
    if (selectedPlace == null) selectedPlaceId = null;
    notifyListeners();
  }

  Future<void> locate({bool requestPermission = true}) async {
    if (locating) return;
    locating = true;
    locationIssue = null;
    notifyListeners();
    final result = await location.locate(requestPermission: requestPermission);
    if (!_alive) return;
    locating = false;
    locationIssue = result.issue;
    if (result.point case final point?) {
      userLocation = point;
      _followViewport = true;
      mapController.focus(point, zoom: 13);
      // Native idle supplies the new bounds. Distance is computed from the
      // actual user, so exploring elsewhere never remains radius-restricted.
      places = List<SuggestedPlace>.of(places)
        ..sort(
          (a, b) => (distanceKm(a) ?? double.infinity).compareTo(
            distanceKm(b) ?? double.infinity,
          ),
        );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    mapController.removeListener(_mapStateChanged);
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';

/// Mounted Discover state, sharing the existing cancellable catalog/cache path.
class DiscoverMapProvider extends PlaceCatalogProvider {
  DiscoverMapProvider(
    super.repository, {
    required this.location,
    this.preferences,
    this.preferenceKey = 'discover.map',
  }) : super() {
    filters = const PlaceFilters(compact: true);
    mapController.addListener(_mapStateChanged);
  }

  void _mapStateChanged() {
    // A basemap failure must not prevent cached database cards from loading.
    if (!mapController.failed || hasQueried) return;
    final camera = mapController.camera.position;
    final lat =
        (camera?.target.latitude ??
                userLocation?.latitude ??
                cairoMapCenter.latitude)
            .clamp(-85, 85);
    final lng =
        camera?.target.longitude ??
        userLocation?.longitude ??
        cairoMapCenter.longitude;
    double wrap(double value) => (value + 180) % 360 - 180;
    setBounds(
      [
        wrap(lng - .15),
        (lat - .15).clamp(-85, 85),
        wrap(lng + .15),
        (lat + .15).clamp(-85, 85),
      ].map((coordinate) => coordinate.toStringAsFixed(4)).join(','),
      zoom: camera?.zoom,
    );
  }

  final MapLocation location;
  final SharedPreferences? preferences;
  final String preferenceKey;
  String? _persisted;
  bool get hasSavedCamera => mapController.camera.position != null;

  void restore() {
    final raw = preferences?.getString(preferenceKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final zoom = (data['zoom'] as num).toDouble();
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      if (zoom < 3 || zoom > 20 || lat.abs() > 85 || lng.abs() > 180) return;
      mapController.camera.position = ml.CameraPosition(
        target: ml.LatLng(lat, lng),
        zoom: zoom,
        bearing: (data['bearing'] as num).toDouble(),
      );
      filters = PlaceFilters(
        compact: true,
        categories: (data['categories'] as List).cast<String>().toSet(),
        vibes: (data['vibes'] as List).cast<String>().toSet(),
        search: data['search'] as String? ?? '',
      );
      final bounds = data['bounds'] as String?;
      _persisted = raw;
      if (bounds != null) {
        setBounds(bounds, zoom: zoom);
      }
    } on FormatException {
      // Ignore malformed preferences from interrupted or older installations.
    } on TypeError {
      // A previously installed preference schema may have different fields.
    }
  }

  void viewportChanged(String bounds, ml.CameraPosition position) {
    setBounds(bounds, zoom: position.zoom);
    _savePreferences();
  }

  void _savePreferences() {
    final prefs = preferences;
    final camera = mapController.camera.position;
    if (prefs == null || camera == null) return;
    final raw = jsonEncode({
      'lat': camera.target.latitude,
      'lng': camera.target.longitude,
      'zoom': camera.zoom,
      'bearing': camera.bearing,
      'bounds': _visibleBounds,
      'categories': filters.categories.toList(),
      'vibes': filters.vibes.toList(),
      'search': filters.search,
    });
    if (raw == _persisted) return;
    _persisted = raw;
    unawaited(prefs.setString(preferenceKey, raw));
  }

  String? selectedPlaceId;
  LatLng? userLocation;
  double? locationAccuracy;
  bool locationApproximate = true;
  Timer? _locationExpiry;
  MapLocationIssue? locationIssue;
  bool locating = false;
  bool hasQueried = false;
  int _manualMoves = 0;
  bool _alive = true;
  String? _visibleBounds;

  SuggestedPlace? get selectedPlace =>
      places.where((p) => p.id == selectedPlaceId).firstOrNull;

  void revealBranch(SuggestedPlace place) {
    cancelPending();
    if (!places.any((p) => p.id == place.id)) {
      places = [...places, place];
    }
    select(place);
  }

  void toggleMarker(SuggestedPlace place) {
    if (selectedPlaceId != place.id) {
      select(place);
      return;
    }
    clearSelection();
  }

  void clearSelection() {
    if (selectedPlaceId == null) return;
    selectedPlaceId = null;
    notifyListeners();
  }

  void select(SuggestedPlace place) {
    if (place.id == selectedPlaceId) return;
    selectedPlaceId = place.id;
    notifyListeners();
    if (place.latitude != null && place.longitude != null) {
      mapController.focusSelection(LatLng(place.latitude!, place.longitude!));
    }
  }

  @override
  void cameraMoving() {
    _manualMoves++;
    super.cameraMoving();
  }

  @override
  void setBounds(String value, {double? zoom}) {
    final bounds = _parseBounds(value);
    if (bounds == null) return;
    _visibleBounds = value;

    super.setBounds(value, zoom: zoom);
  }

  List<double>? _parseBounds(String value) {
    final coordinates = value.split(',').map(double.tryParse).toList();
    if (coordinates.length != 4 ||
        coordinates.any((number) => number == null || !number.isFinite)) {
      return null;
    }
    final bounds = coordinates.cast<double>();
    final [west, south, east, north] = bounds;
    if (west.abs() > 180 ||
        east.abs() > 180 ||
        south < -90 ||
        north > 90 ||
        south >= north ||
        west == east ||
        (west == 180 && east == -180)) {
      return null;
    }
    return bounds;
  }

  void search(String value) {
    if (value == filters.search) return;
    selectedPlaceId = null;
    update(
      filters.copyWith(search: value, bounds: _visibleBounds),
      debounce: true,
    );
  }

  @override
  Future<void> update(
    PlaceFilters value, {
    bool debounce = false,
    bool retainPlaces = false,
  }) {
    // A changed search/filter is a new result set; camera focus isn't one.
    if (!retainPlaces) selectedPlaceId = null;
    final result = super.update(
      value.copyWith(compact: true),
      debounce: debounce,
      retainPlaces: retainPlaces,
    );
    _savePreferences();
    return result;
  }

  double? distanceKm(SuggestedPlace place) {
    final origin = userLocation;
    if (origin == null ||
        locationApproximate ||
        place.latitude?.isFinite != true ||
        place.longitude?.isFinite != true) {
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
    if (filters.bounds == null) return;
    hasQueried = true;
    await super.load(more: more, force: force);
  }

  @override
  List<SuggestedPlace> orderResults(List<SuggestedPlace> results) {
    if (!results.any((place) => place.id == selectedPlaceId)) {
      selectedPlaceId = null;
    }
    if (userLocation != null && !filters.topRated) {
      final distances = {
        for (final place in results)
          place.id: distanceKm(place) ?? double.infinity,
      };
      results.sort((a, b) {
        final order = distances[a.id]!.compareTo(distances[b.id]!);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    }
    return results;
  }

  Future<void> locate({
    bool requestPermission = true,
    bool recenter = true,
  }) async {
    if (locating) return;
    locating = true;
    locationIssue = null;
    notifyListeners();
    final moves = _manualMoves;
    var freshDone = false;
    final owner = privateOwner;
    final repo = repository;
    if (userLocation == null) {
      unawaited(() async {
        try {
          LatLng? point;
          double? accuracy;
          if (owner != null &&
              repo is ViewportCatalog &&
              await location.permitted) {
            final saved = await (repo as ViewportCatalog).previousFix(owner);
            if (saved != null) {
              point = LatLng(saved.lat, saved.lng);
              accuracy = saved.accuracy;
            }
          }
          if (point == null) {
            final old = await location.previous();
            point = old?.point;
            accuracy = old?.accuracy;
          }
          if (!_alive || freshDone || point == null) return;
          userLocation = point;
          locationAccuracy = accuracy;
          locationApproximate = true;
          notifyListeners();
        } catch (_) {
          /* Previous fixes are optional. */
        }
      }());
    }
    final result = await location.locateFix(
      requestPermission: requestPermission,
    );
    if (!_alive) return;
    freshDone = result.point != null;
    locating = false;
    locationIssue = result.issue;
    if (result.point case final point?) {
      if (owner != null &&
          repo is ViewportCatalog &&
          result.timestamp != null) {
        unawaited(
          (repo as ViewportCatalog)
              .rememberFix(
                owner,
                point.latitude,
                point.longitude,
                result.accuracy,
                result.timestamp!,
              )
              .catchError((_) {}),
        );
      }
      userLocation = point;
      locationAccuracy = result.accuracy;
      _locationExpiry?.cancel();
      final timestamp = result.timestamp;
      final remaining = timestamp
          ?.add(const Duration(minutes: 2))
          .difference(DateTime.now());
      locationApproximate =
          remaining == null ||
          remaining <= Duration.zero ||
          !(locationAccuracy?.isFinite ?? false) ||
          locationAccuracy! <= 0 ||
          locationAccuracy! > 100;
      if (remaining != null && !locationApproximate) {
        _locationExpiry = Timer(remaining, () {
          locationApproximate = true;
          notifyListeners();
        });
      }
      if (recenter && moves == _manualMoves) {
        mapController.focusSelection(point, zoom: 13);
      }
      // Native idle supplies the new bounds. Distance is computed from the
      // actual user, so exploring elsewhere never remains radius-restricted.
      if (places.isNotEmpty) places = orderResults(List.of(places));
    } else if (userLocation != null) {
      locationApproximate = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    _locationExpiry?.cancel();
    mapController.removeListener(_mapStateChanged);
    super.dispose();
  }
}

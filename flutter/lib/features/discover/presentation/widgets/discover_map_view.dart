import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_map_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/widgets/personal_locations_map.dart';

/// Retains the native map and converted input across selection changes.
class DiscoverMapView extends StatefulWidget {
  const DiscoverMapView({
    super.key,
    required this.catalog,
    required this.bottomInset,
    this.darkBasemap,
    required this.onPoint,
    this.pending,
    this.showLocationToggle = true,
  });
  final DiscoverMapProvider catalog;
  final double bottomInset;
  final bool? darkBasemap;
  final ValueChanged<LatLng> onPoint;
  final Place? pending;
  final bool showLocationToggle;
  @override
  State<DiscoverMapView> createState() => _DiscoverMapViewState();
}

class _DiscoverMapViewState extends State<DiscoverMapView> {
  List<SuggestedPlace>? _source;
  List<Place> _places = const [], _privatePlaces = const [];
  ({
    List<Place> places,
    List<Place> privatePlaces,
    List<CatalogDefinition> categories,
    LatLng? location,
    double? accuracy,
    bool approximate,
    bool? dark,
    String? selected,
    Place? pending,
    double inset,
    bool showLocationToggle,
  })?
  _inputs;
  Widget? _view;
  bool _sameFeatures(List<Place> a, List<Place> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if ((
            x.id,
            x.name,
            x.nameAr,
            x.nameEn,
            x.categoryId,
            x.latitude,
            x.longitude,
          ) !=
          (
            y.id,
            y.name,
            y.nameAr,
            y.nameEn,
            y.categoryId,
            y.latitude,
            y.longitude,
          )) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    if (!identical(_source, catalog.places)) {
      _source = catalog.places;
      final public = <Place>[], private = <Place>[];
      for (final p in catalog.places) {
        (p.id.startsWith('private:') ? private : public).add(p.toOutingPlace());
      }
      if (!_sameFeatures(_places, public)) _places = public;
      if (!_sameFeatures(_privatePlaces, private)) _privatePlaces = private;
    }
    catalog.mapController.selectionTop = 0;
    final inputs = (
      places: _places,
      privatePlaces: _privatePlaces,
      categories: catalog.categories,
      location: catalog.userLocation,
      accuracy: catalog.locationAccuracy,
      approximate: catalog.locationApproximate,
      dark: widget.darkBasemap,
      selected: catalog.selectedPlaceId,
      pending: widget.pending,
      inset: widget.bottomInset,
      showLocationToggle: widget.showLocationToggle,
    );
    if (_inputs == inputs && _view != null) return _view!;
    _inputs = inputs;
    return _view = PersonalLocationsMap(
      controller: catalog.mapController,
      showToggle: widget.showLocationToggle,
      toggleAlignment: AlignmentDirectional.bottomStart,
      togglePadding: EdgeInsetsDirectional.only(
        start: 12,
        bottom: widget.bottomInset + 10,
      ),
      builder: (context, markers, onTap) => YallaMapView(
        controller: catalog.mapController,
        personalLocations: markers,
        onPersonalLocationTap: onTap,
        center: catalog.userLocation ?? cairoMapCenter,
        userLocation: catalog.userLocation,
        selectionBottom: widget.bottomInset,
        userAccuracy: catalog.locationAccuracy,
        userLocationApproximate: catalog.locationApproximate,
        darkBasemap: widget.darkBasemap,
        customControls: true,
        controlsTop: 16,
        places: _places,
        privatePlaces: _privatePlaces,
        categories: catalog.categories,
        selection: YallaMapPlaceSelection(
          focusedId: catalog.selectedPlaceId,
          selected: [?widget.pending],
        ),
        onPlaceTap: (place) {
          final match = catalog.places
              .where((p) => p.id == place.id)
              .firstOrNull;
          if (match != null) {
            FocusScope.of(context).unfocus();
            catalog.toggleMarker(match);
          }
        },
        onTap: widget.onPoint,
        onUserMove: catalog.cameraMoving,
        onViewportChanged: catalog.viewportChanged,
      ),
    );
  }
}

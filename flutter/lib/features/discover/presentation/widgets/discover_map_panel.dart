import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';

class DiscoverMapPanel extends StatelessWidget {
  const DiscoverMapPanel({
    super.key,
    required this.controller,
    required this.catalog,
    required this.center,
    required this.onSelect,
    this.selectedId,
    this.focusedPlace,
    this.userLocation,
  });
  final YallaMapController controller;
  final PlaceCatalogProvider catalog;
  final LatLng center;
  final LatLng? userLocation;
  final String? selectedId;
  final SuggestedPlace? focusedPlace;
  final ValueChanged<SuggestedPlace> onSelect;
  @override
  Widget build(BuildContext context) => YallaMapView(
    controller: controller,
    center: center,
    userLocation: userLocation,
    selectionBottom: controller.selectionBottom,
    controlsTop: 200,
    onUserMove: catalog.cameraMoving,
    places: catalog.places.map((p) => p.toOutingPlace()).toList(),
    categories: catalog.categories,
    selection: YallaMapPlaceSelection(
      focusedId: selectedId,
      selected: [if (focusedPlace != null) focusedPlace!.toOutingPlace()],
    ),
    onBoundsChanged: catalog.setBounds,
    onPlaceTap: (p) {
      final place = catalog.places.where((item) => item.id == p.id).firstOrNull;
      if (place != null) onSelect(place);
    },
  );
}

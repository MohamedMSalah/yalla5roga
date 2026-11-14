import 'package:flutter/widgets.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_map_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

/// Retains the native map and converted input across selection changes.
class DiscoverMapView extends StatefulWidget {
  const DiscoverMapView({
    super.key,
    required this.catalog,
    required this.bottomInset,
  });
  final DiscoverMapProvider catalog;
  final double bottomInset;
  @override
  State<DiscoverMapView> createState() => _DiscoverMapViewState();
}

class _DiscoverMapViewState extends State<DiscoverMapView> {
  List<SuggestedPlace>? _source;
  List<Place> _places = const [];
  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    if (!identical(_source, catalog.places)) {
      _source = catalog.places;
      _places = catalog.places.map((p) => p.toOutingPlace()).toList();
    }
    catalog.mapController.selectionTop =
        MediaQuery.paddingOf(context).top + 120;
    return YallaMapView(
      controller: catalog.mapController,
      center: catalog.userLocation ?? cairoMapCenter,
      userLocation: catalog.userLocation,
      selectionBottom: widget.bottomInset,
      controlsTop: 128,
      controlsBottom: widget.bottomInset + 48,
      places: _places,
      categories: catalog.categories,
      selection: YallaMapPlaceSelection(focusedId: catalog.selectedPlaceId),
      onPlaceTap: (place) {
        final match = catalog.places.where((p) => p.id == place.id).firstOrNull;
        if (match != null) {
          FocusScope.of(context).unfocus();
          catalog.select(match);
        }
      },
      onUserMove: catalog.cameraMoving,
      onBoundsChanged: catalog.setBounds,
    );
  }
}

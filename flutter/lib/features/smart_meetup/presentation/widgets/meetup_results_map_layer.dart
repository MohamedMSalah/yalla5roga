import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_markers.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

import '../../domain/entities/meetup_results.dart';

class MeetupResultsMapLayer extends StatefulWidget {
  const MeetupResultsMapLayer({
    super.key,
    required this.recommendations,
    required this.focusedId,
    required this.onPlaceTap,
  });

  final List<MeetupRecommendation> recommendations;
  final String? focusedId;
  final ValueChanged<String> onPlaceTap;

  @override
  State<MeetupResultsMapLayer> createState() => _MeetupResultsMapLayerState();
}

class _MeetupResultsMapLayerState extends State<MeetupResultsMapLayer> {
  final _map = YallaMapController();
  late List<Place> _places;

  @override
  void initState() {
    super.initState();
    _updatePlaces();
  }

  @override
  void didUpdateWidget(covariant MeetupResultsMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recommendations != oldWidget.recommendations) _updatePlaces();
    if (widget.focusedId != oldWidget.focusedId) _focus();
  }

  void _updatePlaces() {
    _places = widget.recommendations
        .map((row) => row.place.toOutingPlace())
        .where(YallaMapMarkers.validPoint)
        .toList(growable: false);
    final points = _places
        .map((place) => LatLng(place.latitude!, place.longitude!))
        .toSet()
        .toList();
    if (points.length == 1) {
      _map.focus(points.single, zoom: 14);
    } else if (points.isNotEmpty) {
      _map.fit(points, padding: const EdgeInsets.all(44));
    }
  }

  void _focus() {
    for (final place in _places) {
      if (place.id == widget.focusedId) {
        _map.focus(LatLng(place.latitude!, place.longitude!));
        break;
      }
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Responsive.radiusMd),
    child: YallaMapView(
      controller: _map,
      places: _places,
      placeLabelPrefixes: {
        for (final row in widget.recommendations)
          row.place.id: context.l10n.n(row.rank),
      },
      selection: YallaMapPlaceSelection(
        mode: YallaMapSelectionMode.multiple,
        focusedId: widget.focusedId,
        selected: _places,
      ),
      onPlaceTap: (place) => widget.onPlaceTap(place.id),
    ),
  );
}

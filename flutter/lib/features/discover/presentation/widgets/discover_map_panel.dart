import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_map.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';

class DiscoverMapPanel extends StatelessWidget {
  const DiscoverMapPanel({
    super.key,
    required this.mapKey,
    required this.center,
    required this.places,
    required this.query,
    required this.onSearch,
    required this.onSelect,
    required this.onLocate,
    this.selectedId,
    this.tileProvider,
    this.busy = false,
    this.userLocation,
  });
  final GlobalKey<AppMapState> mapKey;
  final LatLng center;
  final LatLng? userLocation;
  final List<SuggestedPlace> places;
  final TextEditingController query;
  final ValueChanged<String> onSearch;
  final ValueChanged<SuggestedPlace> onSelect;
  final VoidCallback onLocate;
  final String? selectedId;
  final TileProvider? tileProvider;
  final bool busy;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Responsive.radiusMd),
    child: SizedBox(
      height: Responsive.isWideLayout ? 460 : 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppMap(
            key: mapKey,
            center: center,
            zoom: 12,
            scrollWheelZoom: false,
            tileProvider: tileProvider,
            markers: [
              if (userLocation case final point?)
                Marker(
                  point: point,
                  child: Tooltip(
                    message: context.l10n.yourLocation,
                    child: Icon(
                      Icons.my_location,
                      color: context.palette.brandStrong,
                    ),
                  ),
                ),
              for (final place in places)
                if (place.latitude != null && place.longitude != null)
                  Marker(
                    key: ValueKey(place.id),
                    point: LatLng(place.latitude!, place.longitude!),
                    width: 48,
                    height: 48,
                    alignment: Alignment.bottomCenter,
                    child: MapPlaceMarker(
                      label: place.name,
                      selected: selectedId == place.id,
                      onPressed: () => onSelect(place),
                    ),
                  ),
            ],
          ),
          PositionedDirectional(
            start: 12,
            end: 12,
            top: 12,
            child: MapSearchBar(controller: query, onChanged: onSearch),
          ),
          PositionedDirectional(
            end: 12,
            bottom: 40,
            child: MapCurrentLocationButton(onPressed: onLocate, busy: busy),
          ),
        ],
      ),
    ),
  );
}

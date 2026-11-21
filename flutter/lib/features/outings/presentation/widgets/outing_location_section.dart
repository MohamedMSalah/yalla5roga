import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';

import 'outing_info_style.dart';

Future<void> openOutingVenue(
  BuildContext context,
  PlaceLocation location, {
  bool directions = true,
}) async {
  final launch = directions ? AppLauncher.openDirections : AppLauncher.openMaps;
  final opened = await launch(
    latitude: location.latitude,
    longitude: location.longitude,
    query: location.label,
  );
  if (!opened && context.mounted) {
    AppSnackBar.show(context.l10n.couldNotOpenLink);
  }
}

class OutingLocationSection extends StatefulWidget {
  const OutingLocationSection({
    super.key,
    required this.location,
    required this.canView,
  });
  final PlaceLocation? location;
  final bool Function(BuildContext) canView;

  @override
  State<OutingLocationSection> createState() => _OutingLocationSectionState();
}

class _OutingLocationSectionState extends State<OutingLocationSection> {
  static const _distanceFreshness = Duration(minutes: 2);
  Timer? _distanceExpiry;
  late final Future<MapLocationFix?> _previous = const MapLocation()
      .previous()
      .then((fix) {
        if (fix?.timestamp case final time? when mounted) {
          final remaining = time
              .add(_distanceFreshness)
              .difference(DateTime.now());
          if (remaining > Duration.zero) {
            _distanceExpiry = Timer(remaining, () {
              if (mounted) setState(() {});
            });
          }
        }
        return fix;
      });

  @override
  void dispose() {
    _distanceExpiry?.cancel();
    super.dispose();
  }

  void _viewMap(PlaceLocation location) {
    if (!location.hasCoordinates) {
      openOutingVenue(context, location, directions: false);
      return;
    }
    final canView = widget.canView;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OutingVenueMap(location: location, canView: canView),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final style = OutingInfoStyle(context);
    final l10n = context.l10n;
    if (location == null) {
      return OutingInfoPanel(
        child: Row(
          children: [
            Icon(Icons.place_outlined, color: style.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.outingLocationPending, style: style.type(14)),
            ),
          ],
        ),
      );
    }

    final placeId = location.placeId;
    final details = placeId == null || placeId.isEmpty
        ? null
        : () {
            Get.to(() => DiscoverPlaceDetailsPage(placeId: placeId));
          };
    return OutingInfoPanel(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, limits) {
          final narrow =
              limits.maxWidth < 255 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: details,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              style: style.type(15, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            if (location.vicinity.isNotEmpty ||
                                location.hasCoordinates)
                              FutureBuilder<MapLocationFix?>(
                                future: location.hasCoordinates
                                    ? _previous
                                    : null,
                                builder: (context, snapshot) {
                                  final fix = snapshot.data;
                                  final point = fix?.point;
                                  final timestamp = fix?.timestamp;
                                  final accuracy = fix?.accuracy;
                                  final km =
                                      point != null &&
                                          timestamp != null &&
                                          accuracy != null &&
                                          accuracy.isFinite &&
                                          accuracy > 0 &&
                                          accuracy <= 150 &&
                                          DateTime.now()
                                                  .difference(timestamp)
                                                  .abs() <
                                              const Duration(minutes: 2)
                                      ? const Distance().as(
                                          LengthUnit.Kilometer,
                                          point,
                                          LatLng(
                                            location.latitude!,
                                            location.longitude!,
                                          ),
                                        )
                                      : null;
                                  final text = [
                                    if (location.vicinity.isNotEmpty)
                                      location.vicinity,
                                    if (km != null && km.isFinite)
                                      l10n.catalogDistanceLabel(km),
                                  ].join(' · ');
                                  if (text.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        color: style.icon,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: style.type(
                                            12,
                                            color: style.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      if (details != null)
                        Icon(
                          Icons.arrow_forward_ios,
                          color: style.icon,
                          size: 13,
                        ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => _viewMap(location),
                  icon: Icon(
                    Icons.near_me_outlined,
                    size: 15,
                    color: style.icon,
                  ),
                  label: Text(l10n.viewOnMap),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: style.text,
                    textStyle: style.type(12, weight: FontWeight.w600),
                    side: BorderSide(color: style.accent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    minimumSize: const Size(48, 32),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                  ),
                ),
              ),
            ],
          );
          final preview = _OutingMapPreview(onTap: () => _viewMap(location));
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [preview, const SizedBox(height: 8), information],
            );
          }
          return Row(
            children: [
              preview,
              const SizedBox(width: 12),
              Expanded(child: information),
            ],
          );
        },
      ),
    );
  }
}

class _OutingMapPreview extends StatelessWidget {
  const _OutingMapPreview({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(12);
    final style = OutingInfoStyle(context);
    return Tooltip(
      message: context.l10n.viewOnMap,
      child: Material(
        borderRadius: border,
        color: style.dark ? const Color(0xFF152231) : style.control,
        child: InkWell(
          onTap: onTap,
          borderRadius: border,
          child: Container(
            width: 112,
            height: 75,
            decoration: BoxDecoration(
              border: Border.all(color: style.border),
              borderRadius: border,
            ),
            child: Icon(Icons.location_on, size: 32, color: style.accent),
          ),
        ),
      ),
    );
  }
}

class _OutingVenueMap extends StatefulWidget {
  const _OutingVenueMap({required this.location, required this.canView});
  final PlaceLocation location;
  final bool Function(BuildContext) canView;

  @override
  State<_OutingVenueMap> createState() => _OutingVenueMapState();
}

class _OutingVenueMapState extends State<_OutingVenueMap> {
  final _controller = YallaMapController();
  late final _location = widget.location;
  late final _places = [
    Place(
      id: _location.placeId?.isNotEmpty == true ? _location.placeId! : 'venue',
      name: _location.name,
      area: _location.area,
      categoryId: _location.categoryId,
      latitude: _location.latitude,
      longitude: _location.longitude,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canView(context)) {
      return Scaffold(
        appBar: AppPageBar(title: context.l10n.viewOnMap),
        body: Center(child: Text(context.l10n.dataLoadFailed)),
      );
    }
    return Scaffold(
      appBar: AppPageBar(title: _location.name),
      body: YallaMapView(
        controller: _controller,
        center: LatLng(_location.latitude!, _location.longitude!),
        zoom: 15,
        places: _places,
        controlsTop: 0,
      ),
    );
  }
}

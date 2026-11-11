import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_map.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/nearby_places_list.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/vibe_picker.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    this.tileProvider,
    this.location = const MapLocation(),
  });

  final TileProvider? tileProvider;
  final MapLocation location;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  String _query = '';
  String? _selectedId;
  LatLng? _nearbyCenter;
  List<SuggestedPlace>? _nearby;
  String? _error;
  bool _busy = false;
  bool _offerSettings = false;
  int _filter = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findNearby(requestPermission: false);
    });
  }

  Future<void> _findNearby({bool requestPermission = true}) async {
    if (_busy) return;
    final l10n = context.l10n;
    final discover = context.read<DiscoverProvider>();
    setState(() {
      _busy = true;
      _error = null;
      _offerSettings = false;
    });

    String? error;
    bool offerSettings = false;
    LatLng? center;
    List<SuggestedPlace>? results;
    final location = await widget.location.locate(
      requestPermission: requestPermission,
    );
    if (!mounted) return;
    center = location.point;
    if (center != null) {
      final result = await discover.getNearbyPlaces(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      result.fold(
        (failure) => error = FailureMessageMapper.localize(failure, l10n),
        (items) => results = items,
      );
    } else if (requestPermission) {
      error = switch (location.issue) {
        MapLocationIssue.disabled => l10n.locationDisabled,
        MapLocationIssue.denied ||
        MapLocationIssue.deniedForever => l10n.locationPermissionDenied,
        _ => l10n.couldNotGetLocation,
      };
      offerSettings = location.issue == MapLocationIssue.deniedForever;
    }

    if (!mounted) return;
    setState(() {
      if (results != null) {
        _nearby = results;
        _nearbyCenter = center;
        _selectedId = null;
      }
      _error = error;
      _offerSettings = offerSettings;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discover = context.watch<DiscoverProvider>();
    final vibe = _filter < 0 ? null : OutingVibe.values[_filter];
    final places = [
      for (final place in _nearby ?? discover.places)
        if ((vibe == null || place.vibe == vibe) &&
            '${place.name} ${place.area}'.toLowerCase().contains(_query))
          place,
    ];
    final palette = context.palette;
    final selected = places
        .where((place) => place.id == _selectedId)
        .firstOrNull;
    final firstCatalogPin = discover.places
        .where((place) => place.latitude != null && place.longitude != null)
        .firstOrNull;
    final center =
        _nearbyCenter ??
        (firstCatalogPin == null
            ? cairoMapCenter
            : LatLng(firstCatalogPin.latitude!, firstCatalogPin.longitude!));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: Responsive.pagePadding().add(
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.discover, style: context.texts.headlineSmall),
              ),
              const NotificationButton(),
            ],
          ),
          Responsive.spaceMd.gapH,
          SectionHeader(
            title: l10n.nearbyPlaces,
            subtitle: l10n.nearbyLocationHint,
          ),
          Responsive.spaceSm.gapH,
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _findNearby(),
            icon: const Icon(Icons.my_location),
            label: Text(l10n.findNearbyPlaces),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          if (_busy) ...[
            Responsive.spaceSm.gapH,
            const LinearProgressIndicator(),
          ],
          if (_error case final error?) ...[
            Responsive.spaceSm.gapH,
            Semantics(liveRegion: true, child: Text(error)),
            if (_offerSettings)
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: Text(l10n.openAppSettings),
              ),
          ],
          Responsive.spaceSm.gapH,
          SectionHeader(
            title: l10n.placeVibes,
            actionLabel: l10n.allVibes,
            onAction: _filter < 0 ? null : () => setState(() => _filter = -1),
          ),
          VibePicker(
            options: VibeOption.outingVibes(l10n),
            index: _filter,
            onChanged: (index) => setState(() => _filter = index),
          ),
          Responsive.spaceMd.gapH,
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.radiusMd),
            child: SizedBox(
              height: Responsive.isWideLayout ? 460 : 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppMap(
                    center: center,
                    zoom: _nearbyCenter == null ? 11 : 12,
                    scrollWheelZoom: false,
                    tileProvider: widget.tileProvider,
                    markers: [
                      if (_nearbyCenter case final point?)
                        Marker(
                          point: point,
                          child: Tooltip(
                            message: l10n.yourLocation,
                            child: Icon(
                              Icons.my_location,
                              color: palette.brandStrong,
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
                            child: Material(
                              color: Colors.transparent,
                              child: Semantics(
                                selected: selected?.id == place.id,
                                child: IconButton(
                                  tooltip: place.name,
                                  color: palette.brandStrong,
                                  icon: Icon(
                                    selected?.id == place.id
                                        ? Icons.location_on
                                        : Icons.place_outlined,
                                    shadows: [
                                      Shadow(
                                        color: palette.surface,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  iconSize: 34,
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _selectedId = place.id);
                                  },
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                  PositionedDirectional(
                    start: 12,
                    end: 12,
                    top: 12,
                    child: Material(
                      color: palette.surface,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.mapSearchHint,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected != null) ...[
            Responsive.spaceSm.gapH,
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(selected.name),
              subtitle: selected.area.isEmpty ? null : Text(selected.area),
              trailing: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedId = null),
              ),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  Get.to(() => CreateOutingPage(suggestedPlace: selected)),
              child: Text(l10n.createOutingAt(selected.name)),
            ),
          ],
          Responsive.spaceLg.gapH,
          if (_nearby != null || discover.hasLoaded)
            NearbyPlacesList(
              title: _nearby == null ? l10n.allPlaces : l10n.nearbyPlaces,
              places: places,
              emptyMessage: _query.isNotEmpty
                  ? l10n.mapNoResults
                  : _nearby != null
                  ? l10n.noNearbyPlaces
                  : null,
            )
          else if (!_busy)
            const LinearProgressIndicator(),
          if (_nearby == null && discover.errorMessage != null)
            TextButton(
              onPressed: () => discover.load(forceRefresh: true),
              child: Text(l10n.tryAgain),
            ),
        ],
      ),
    );
  }
}

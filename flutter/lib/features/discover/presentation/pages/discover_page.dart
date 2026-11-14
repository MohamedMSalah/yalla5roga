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
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/core/maps/location_repository.dart';
import 'package:yalla_5roga/core/maps/location_search_provider.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_results.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_map_panel.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';

import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/core/widgets/vibe_picker.dart';

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
  final _map = GlobalKey<AppMapState>();
  final _mapPanel = GlobalKey();
  final _searchText = TextEditingController();
  LocationSearchProvider? _search;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context.l10n.locale.languageCode;
    if (_search?.language == language) return;
    _search?.removeListener(_searchChanged);
    _search?.dispose();
    final repository = context.read<LocationRepository?>();
    if (repository != null) {
      _search = LocationSearchProvider(repository, language: language)
        ..addListener(_searchChanged);
      if (_query.isNotEmpty) _search!.search(_query);
    }
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  void _select(SuggestedPlace place) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedId = place.id);
    if (_mapPanel.currentContext case final mapContext?) {
      Scrollable.ensureVisible(
        mapContext,
        alignment: .1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
    }
    if (place.latitude != null && place.longitude != null) {
      _map.currentState?.focus(
        LatLng(place.latitude!, place.longitude!),
        zoom: 15,
      );
    }
  }

  @override
  void dispose() {
    _search?.removeListener(_searchChanged);
    _search?.dispose();
    _searchText.dispose();
    super.dispose();
  }

  String _query = '';
  String? _selectedId;
  LatLng? _nearbyCenter;
  LatLng? _userLocation;
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
    } else {
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
        _userLocation = center;
        _selectedId = null;
      }
      _error = error;
      _offerSettings = offerSettings;
      _busy = false;
    });
  }

  Future<void> _searchArea(LatLng point) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _map.currentState?.focus(point, zoom: 13);
    final result = await context.read<DiscoverProvider>().getNearbyPlaces(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (!mounted) return;
    setState(() {
      result.fold(
        (failure) =>
            _error = FailureMessageMapper.localize(failure, context.l10n),
        (items) {
          _nearby = items;
          _nearbyCenter = point;
          _selectedId = null;
        },
      );
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
    final selected = places
        .where((place) => place.id == _selectedId)
        .firstOrNull;
    final center = _nearbyCenter ?? cairoMapCenter;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: Responsive.pagePadding().add(
              EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            ),
            children: [
              AppOfflineIndicator(
                isOffline:
                    context.watch<AppSyncProvider?>()?.status ==
                    SyncStatus.offline,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.discover,
                      style: context.texts.headlineSmall,
                    ),
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
                onAction: _filter < 0
                    ? null
                    : () => setState(() => _filter = -1),
              ),
              MapVibeFilters(
                labels: VibeOption.outingVibes(l10n)
                    .map((option) => option.label)
                    .toList(),
                index: _filter,
                onChanged: (index) => setState(() {
                  _filter = index;
                  _selectedId = null;
                }),
              ),
              Responsive.spaceMd.gapH,
              DiscoverMapPanel(
                key: _mapPanel,
                mapKey: _map,
                center: center,
                places: places,
                query: _searchText,
                selectedId: _selectedId,
                userLocation: _userLocation,
                tileProvider: widget.tileProvider,
                busy: _busy,
                onSearch: (value) {
                  setState(() {
                    _query = value.trim().toLowerCase();
                    _selectedId = null;
                  });
                  _search?.search(value);
                },
                onSelect: _select,
                onLocate: () => _findNearby(),
              ),
              if (_search?.busy == true) const LinearProgressIndicator(),
              if (_query.isNotEmpty && _search != null)
                DiscoverLocationResults(
                  search: _search!,
                  busy: _busy,
                  onRetry: () => _search!.search(_searchText.text),
                  onChoose: (hit) {
                    FocusScope.of(context).unfocus();
                    _searchText.clear();
                    _search!.search('');
                    setState(() => _query = '');
                    _searchArea(LatLng(hit.latitude, hit.longitude));
                  },
                ),
              if (selected != null) ...[
                Responsive.spaceSm.gapH,
                MapPlacePreview(
                  title: selected.name,
                  subtitle:
                      '${selected.area} · ${l10n.priceLevelLabel(selected.priceLevel.name)}',
                  imageUrl: selected.coverImageUrl,
                  onDetails: () => Get.to(
                    () => DiscoverPlaceDetailsPage(
                      placeId: selected.id,
                      initialPlace: selected,
                    ),
                  ),
                  onClose: () => setState(() => _selectedId = null),
                  actionLabel: l10n.createOutingAt(selected.name),
                  onAction: () =>
                      Get.to(() => CreateOutingPage(suggestedPlace: selected)),
                ),
              ],
              Responsive.spaceLg.gapH,
              if (_nearby != null || discover.hasLoaded)
                DiscoverPlacesResults(
                  places: places,
                  title: _nearby == null ? l10n.allPlaces : l10n.nearbyPlaces,
                  emptyMessage: _query.isNotEmpty || _filter >= 0
                      ? l10n.mapNoResults
                      : l10n.noNearbyPlaces,
                  selectedId: _selectedId,
                  onSelect: _select,
                  onPlan: (place) =>
                      Get.to(() => CreateOutingPage(suggestedPlace: place)),
                )
              else if (!_busy && discover.errorMessage == null)
                const LinearProgressIndicator(),
              if (_nearby == null && discover.errorMessage != null)
                AppErrorState(
                  message: discover.errorMessage!,
                  onRetry: () => discover.load(forceRefresh: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

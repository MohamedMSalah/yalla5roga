import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_map_panel.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';

import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';

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
  TextEditingController get _searchText => _catalog.searchController;
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
    _catalog.removeListener(_catalogChanged);
    _catalog.dispose();
    super.dispose();
  }

  String _query = '';
  String? _selectedId;
  LatLng? _nearbyCenter;
  LatLng? _userLocation;
  String? _error;
  bool _busy = false;
  bool _offerSettings = false;
  late final PlaceCatalogProvider _catalog;
  void _catalogChanged() {
    if (mounted) {
      setState(() {
        _query = _catalog.filters.search.trim().toLowerCase();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _catalog = PlaceCatalogProvider(context.read<DiscoverProvider>().repository)
      ..addListener(_catalogChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _catalog.loadDefinitions();
        _catalog.load();
        _findNearby(requestPermission: false);
      }
    });
  }

  Future<void> _findNearby({bool requestPermission = true}) async {
    if (_busy) return;
    final l10n = context.l10n;
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
      await _catalog.update(
        _catalog.filters.copyWith(
          latitude: center.latitude,
          longitude: center.longitude,
        ),
      );
      results = _catalog.places;
      if (_catalog.error != null) error = l10n.mapLookupFailed;
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
    await _catalog.update(
      _catalog.filters.copyWith(
        latitude: point.latitude,
        longitude: point.longitude,
        search: '',
      ),
    );
    if (!mounted) return;
    setState(() {
      _nearbyCenter = point;
      _selectedId = null;
      if (_catalog.error != null) _error = context.l10n.mapLookupFailed;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final places = _catalog.places;
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
              PlaceCatalogFilters(catalog: _catalog),
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
                    _catalog.update(
                      _catalog.filters.copyWith(search: value),
                      debounce: true,
                    );
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
                  title: selected.localizedName(l10n),
                  subtitle: selected.localizedSummary(l10n),
                  imageUrl: selected.coverImageUrl,
                  onDetails: () => Get.to(
                    () => DiscoverPlaceDetailsPage(
                      placeId: selected.id,
                      initialPlace: selected,
                    ),
                  ),
                  onClose: () => setState(() => _selectedId = null),
                  actionLabel: l10n.createOutingAt(
                    selected.localizedName(l10n),
                  ),
                  onAction: () =>
                      Get.to(() => CreateOutingPage(suggestedPlace: selected)),
                ),
              ],
              Responsive.spaceLg.gapH,
              if (places.isNotEmpty ||
                  (!_catalog.loading && _catalog.error == null))
                DiscoverPlacesResults(
                  places: places,
                  title: _catalog.filters.latitude == null
                      ? l10n.allPlaces
                      : l10n.nearbyPlaces,
                  emptyMessage:
                      _query.isNotEmpty ||
                          _catalog.filters.categories.isNotEmpty ||
                          _catalog.filters.vibes.isNotEmpty
                      ? l10n.mapNoResults
                      : l10n.noNearbyPlaces,
                  selectedId: _selectedId,
                  onSelect: _select,
                  onPlan: (place) =>
                      Get.to(() => CreateOutingPage(suggestedPlace: place)),
                ),
              CatalogLoadMore(catalog: _catalog),
            ],
          ),
        ),
      ),
    );
  }
}

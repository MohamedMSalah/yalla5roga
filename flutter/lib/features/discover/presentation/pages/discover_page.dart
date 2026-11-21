import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/private_place_sheet.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_map_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_filter_chips.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_floating_search_bar.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_map_controls.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_map_view.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_place_carousel.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_places_bottom_panel.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key, this.location = const MapLocation()});
  final MapLocation location;
  @override
  Widget build(BuildContext context) {
    final owner = context.select((AuthProvider? p) => p?.user?.id);
    return _AccountDiscover(
      key: ValueKey(owner),
      owner: owner,
      location: location,
    );
  }
}

class _AccountDiscover extends StatefulWidget {
  const _AccountDiscover({
    super.key,
    required this.owner,
    required this.location,
  });
  final String? owner;
  final MapLocation location;
  @override
  State<_AccountDiscover> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<_AccountDiscover> {
  late final DiscoverMapProvider _catalog;
  bool _panelExpanded = false;
  DiscoverBasemap _basemap = DiscoverBasemap.automatic;

  @override
  void initState() {
    super.initState();
    _catalog = DiscoverMapProvider(
      context.read<DiscoverProvider>().repository,
      location: widget.location,
      preferences: context.read<SharedPreferences?>(),
      preferenceKey:
          'discover.map.${AppConfig.instance.apiBaseUrl}.${widget.owner ?? 'guest'}',
    );
    _catalog.privateOwner = widget.owner;
    _catalog.restore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _catalog.loadDefinitions();
      context.read<DiscoverProvider>().loadSavedPlaces();
      _catalog.locate(
        requestPermission: false,
        recenter: !_catalog.hasSavedCamera,
      );
      // First native idle supplies bounds; avoid an unbounded duplicate fetch.
    });
  }

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  Place? _pending;
  bool _sheetOpen = false;
  Future<void> _point(LatLng point, {SuggestedPlace? existing}) async {
    final owner = widget.owner;
    if (owner == null ||
        _sheetOpen ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return;
    }
    _sheetOpen = true;
    _catalog.clearSelection();
    setState(
      () => _pending = Place(
        name: existing?.name ?? context.l10n.customPlace,
        area: '',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
    final selected = await showModalBottomSheet<SuggestedPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PrivatePlaceSheet(
        catalog: _catalog,
        owner: owner,
        point: point,
        existing: existing,
      ),
    );
    _sheetOpen = false;
    if (!mounted || context.read<AuthProvider>().user?.id != owner) return;
    setState(() => _pending = null);
    if (selected != null) _create(selected);
  }

  void _create(SuggestedPlace place) {
    FocusScope.of(context).unfocus();
    Get.to(
      () => CreateOutingPage(
        suggestedPlace: place,
        suggestionOwner: place.id.startsWith('private:') ? widget.owner : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChangeNotifierProvider.value(
      value: _catalog,
      child: Theme(
        data: AppPalette.discoverTheme(theme),
        child: Consumer<DiscoverMapProvider>(
          builder: (context, catalog, _) {
            final palette = context.palette;
            return ColoredBox(
              color: palette.background,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topEnd,
                        end: AlignmentDirectional.bottomStart,
                        colors: [palette.surface, palette.background],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: Responsive.contentMaxWidth,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  16,
                                  10,
                                  16,
                                  8,
                                ),
                                child: DiscoverFloatingSearchBar(
                                  controller: catalog.searchController,
                                  onChanged: catalog.search,
                                ),
                              ),
                              DiscoverFilterChips(catalog: catalog),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildMap(context, catalog)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, DiscoverMapProvider catalog) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Scaffold.extendBody exposes the measured navigation bar and safe inset.
    final navInset = keyboard ? 0.0 : MediaQuery.paddingOf(context).bottom;
    final darkBasemap = switch (_basemap) {
      DiscoverBasemap.automatic => null,
      DiscoverBasemap.day => false,
      DiscoverBasemap.night => true,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final space = math.max(0.0, constraints.maxHeight - navInset);
        final textScale = MediaQuery.textScalerOf(context);
        final collapsed = math.min(
          156 + textScale.scale(36),
          math.max(128.0, space * .52),
        );
        final expanded = math.min(collapsed + 72, space * .66);
        final showCards =
            !keyboard && catalog.places.isNotEmpty && space >= 192;
        final canExpand = expanded > collapsed + 16;
        final height = _panelExpanded && canExpand ? expanded : collapsed;
        final bottom = navInset + (showCards ? height : 0);
        final availableMap = math.max(0.0, constraints.maxHeight - bottom);
        return Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: DiscoverMapView(
                catalog: catalog,
                pending: _pending,
                onPoint: _point,
                bottomInset: bottom,
                darkBasemap: darkBasemap,
              ),
            ),
            if (availableMap > 52)
              PositionedDirectional(
                top: 12,
                start: 12,
                end: keyboard ? 12 : (availableMap < 178 ? 124 : 76),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440,
                        maxHeight: availableMap - 24,
                      ),
                      child: _DiscoverMapMessages(catalog: catalog),
                    ),
                  ),
                ),
              ),
            if (!keyboard && availableMap >= 116)
              PositionedDirectional(
                end: 12,
                top: 12,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: DiscoverMapControls(
                    basemap: _basemap,
                    compact: availableMap < 178,
                    onBasemapChanged: (value) =>
                        setState(() => _basemap = value),
                    onResetNorth: catalog.mapController.resetOrientation,
                  ),
                ),
              ),
            if (!keyboard && availableMap >= 60)
              AnimatedPositionedDirectional(
                duration: AppMotion.of(context, AppMotion.standard),
                curve: AppMotion.settle,
                end: 12,
                bottom: bottom + 10,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: DiscoverMyLocationButton(
                    onLocate: () => catalog.locate(),
                    busy: catalog.locating,
                  ),
                ),
              ),
            if (showCards)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: Responsive.contentMaxWidth,
                        ),
                        child: AnimatedContainer(
                          duration: AppMotion.of(context, AppMotion.standard),
                          curve: AppMotion.settle,
                          height: height,
                          child: DiscoverPlacesBottomPanel(
                            expanded: _panelExpanded && canExpand,
                            expandable: canExpand,
                            onExpanded: (value) =>
                                setState(() => _panelExpanded = value),
                            child: DiscoverPlaceCarousel(
                              catalog: catalog,
                              onCreate: _create,
                              onDetails: (place) =>
                                  place.id.startsWith('private:')
                                  ? _point(
                                      LatLng(place.latitude!, place.longitude!),
                                      existing: place,
                                    )
                                  : Get.to(
                                      () => DiscoverPlaceDetailsPage(
                                        placeId: place.id,
                                        initialPlace: place,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: navInset,
                      width: double.infinity,
                      child: ColoredBox(color: context.palette.background),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DiscoverMapMessages extends StatelessWidget {
  const _DiscoverMapMessages({required this.catalog});

  final DiscoverMapProvider catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final issue = catalog.locationIssue;
    final failed = catalog.error != null;
    final message = failed
        ? l10n.mapLookupFailed
        : switch (issue) {
            MapLocationIssue.disabled => l10n.locationDisabled,
            MapLocationIssue.denied ||
            MapLocationIssue.deniedForever => l10n.locationPermissionDenied,
            MapLocationIssue.unavailable => l10n.couldNotGetLocation,
            null => null,
          };
    final onlineStatus = context.select(
      (AppSyncProvider? provider) => provider?.status,
    );
    final showSuggestions =
        catalog.filters.search.trim().isNotEmpty &&
        catalog.selectedPlaceId == null &&
        catalog.places.isNotEmpty;
    final radius = BorderRadius.circular(Responsive.radiusMd);
    final surface = context.palette.surface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppOfflineIndicator(
                  isOffline: onlineStatus == SyncStatus.offline,
                ),
                if (message != null)
                  Material(
                    color: surface,
                    borderRadius: radius,
                    child: ListTile(
                      dense: true,
                      title: Semantics(liveRegion: true, child: Text(message)),
                      trailing: failed
                          ? IconButton(
                              tooltip: l10n.catalogRetry,
                              icon: const Icon(Icons.refresh),
                              onPressed: () => catalog.load(force: true),
                            )
                          : issue == MapLocationIssue.deniedForever
                          ? TextButton(
                              onPressed: Geolocator.openAppSettings,
                              child: Text(l10n.openAppSettings),
                            )
                          : null,
                    ),
                  ),
                if (catalog.hasQueried &&
                    !catalog.loading &&
                    !failed &&
                    catalog.places.isEmpty)
                  Material(
                    color: surface,
                    borderRadius: radius,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(l10n.mapNoResults),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showSuggestions)
          Flexible(
            flex: 2,
            child: Material(
              color: surface,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: catalog.places.length,
                itemBuilder: (context, index) {
                  final place = catalog.places[index];
                  return MapSelectedLocationCard(
                    title: place.localizedName(l10n),
                    subtitle: place.localizedSummary(l10n),
                    imageUrl: place.coverImageUrl,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      catalog.select(place);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

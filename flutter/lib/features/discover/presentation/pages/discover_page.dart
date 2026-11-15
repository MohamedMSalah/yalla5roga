import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
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
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, this.location = const MapLocation()});
  final MapLocation location;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final DiscoverMapProvider _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = DiscoverMapProvider(
      context.read<DiscoverProvider>().repository,
      location: widget.location,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _catalog.loadDefinitions();
      _catalog.locate(requestPermission: false);
      // First native idle supplies bounds; avoid an unbounded duplicate fetch.
    });
  }

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  void _create(SuggestedPlace place) {
    FocusScope.of(context).unfocus();
    Get.to(() => CreateOutingPage(suggestedPlace: place));
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _catalog,
    child: Consumer<DiscoverMapProvider>(
      builder: (context, catalog, _) {
        final l10n = context.l10n;
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        // Scaffold.extendBody reports the actual bar + system inset here,
        // including wrapped/scaled nav labels. Do not guess its height.
        final navInset = MediaQuery.paddingOf(context).bottom + 8;
        return LayoutBuilder(
          builder: (context, constraints) {
            final height = math.min(
              140 + MediaQuery.textScalerOf(context).scale(42),
              constraints.maxHeight * .4,
            );
            final showCards = !keyboard && catalog.places.isNotEmpty;
            final bottom = navInset + (showCards ? height + 8 : 0);
            final issue = catalog.locationIssue;
            final message = catalog.error != null
                ? l10n.mapLookupFailed
                : issue == MapLocationIssue.disabled
                ? l10n.locationDisabled
                : issue == MapLocationIssue.denied ||
                      issue == MapLocationIssue.deniedForever
                ? l10n.locationPermissionDenied
                : issue != null
                ? l10n.couldNotGetLocation
                : null;
            return Stack(
              fit: StackFit.expand,
              children: [
                DiscoverMapView(catalog: catalog, bottomInset: bottom),
                PositionedDirectional(
                  top: 0,
                  start: 12,
                  end: 12,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: Responsive.contentMaxWidth,
                          maxHeight: math.max(
                            56,
                            constraints.maxHeight -
                                MediaQuery.paddingOf(context).top -
                                navInset -
                                8,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DiscoverFloatingSearchBar(
                                controller: catalog.searchController,
                                onChanged: catalog.search,
                              ),
                              const SizedBox(height: 6),
                              DiscoverFilterChips(catalog: catalog),
                              AppOfflineIndicator(
                                isOffline:
                                    context.watch<AppSyncProvider?>()?.status ==
                                    SyncStatus.offline,
                              ),
                              if (message != null)
                                Material(
                                  color: context.palette.surface,
                                  borderRadius: BorderRadius.circular(
                                    Responsive.radiusMd,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    title: Semantics(
                                      liveRegion: true,
                                      child: Text(message),
                                    ),
                                    trailing: catalog.error != null
                                        ? IconButton(
                                            tooltip: l10n.catalogRetry,
                                            icon: const Icon(Icons.refresh),
                                            onPressed: () =>
                                                catalog.load(force: true),
                                          )
                                        : issue ==
                                              MapLocationIssue.deniedForever
                                        ? TextButton(
                                            onPressed:
                                                Geolocator.openAppSettings,
                                            child: Text(l10n.openAppSettings),
                                          )
                                        : null,
                                  ),
                                ),
                              if (catalog.filters.search.trim().isNotEmpty &&
                                  catalog.selectedPlaceId == null &&
                                  catalog.places.isNotEmpty)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: constraints.maxHeight * .28,
                                  ),
                                  child: Material(
                                    color: context.palette.surface,
                                    borderRadius: BorderRadius.circular(
                                      Responsive.radiusMd,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: catalog.places.length,
                                      itemBuilder: (context, index) {
                                        final place = catalog.places[index];
                                        return MapSelectedLocationCard(
                                          title: place.localizedName(l10n),
                                          subtitle: place.localizedSummary(
                                            l10n,
                                          ),
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
                              if (catalog.hasQueried &&
                                  !catalog.loading &&
                                  catalog.error == null &&
                                  catalog.places.isEmpty)
                                Material(
                                  color: context.palette.surface,
                                  borderRadius: BorderRadius.circular(
                                    Responsive.radiusMd,
                                  ),
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
                    ),
                  ),
                ),
                if (!keyboard)
                  PositionedDirectional(
                    end: 12,
                    bottom: bottom + 48,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: DiscoverMapControls(
                        onLocate: () => catalog.locate(),
                        busy: catalog.locating,
                      ),
                    ),
                  ),
                if (showCards)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: navInset,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: Responsive.contentMaxWidth,
                        ),
                        child: SizedBox(
                          height: height,
                          child: DiscoverPlaceCarousel(
                            catalog: catalog,
                            onCreate: _create,
                            onDetails: (place) => Get.to(
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
              ],
            );
          },
        );
      },
    ),
  );
}

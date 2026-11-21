import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_branch_picker.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/pick_location_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_step_header.dart';

class CreateOutingLocationStep extends StatefulWidget {
  const CreateOutingLocationStep({
    super.key,
    required this.form,
    required this.onNext,
  });

  final CreateOutingProvider form;
  final VoidCallback onNext;

  @override
  State<CreateOutingLocationStep> createState() =>
      _CreateOutingLocationStepState();
}

class _CreateOutingLocationStepState extends State<CreateOutingLocationStep> {
  late final _catalog = widget.form.placeCatalog!;
  late final _map = _catalog.mapController;
  late final _lookup = PickLocationProvider(
    geocoding: context.read<LocationRepository>(),
    catalog: const [],
    language: context.l10n.locale.languageCode,
    maxSelections: 1,
  );

  final _searchFocus = FocusNode();
  final _selectedCards = ScrollController();
  bool _draggingCards = false;
  final _panelKey = GlobalKey();
  final _panelInset = ValueNotifier<double>(0);
  List<SuggestedPlace>? _catalogResults;
  List<Place> _places = const [], _privatePlaces = const [];
  bool _previewOpen = false;
  bool _locating = false;
  bool _watchingQuery = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_searchFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watchingQuery) return;
    _watchingQuery = true;
    _catalog.searchController.addListener(_updateGeocoderQuery);
    _updateGeocoderQuery();
  }

  void _updateGeocoderQuery() => _lookup.search(_catalog.searchController.text);

  @override
  void dispose() {
    _catalog.searchController.removeListener(_updateGeocoderQuery);
    _searchFocus.removeListener(_searchFocusChanged);
    _searchFocus.dispose();
    _panelInset.dispose();
    _selectedCards.dispose();
    _lookup.dispose();
    super.dispose();
  }

  void _searchFocusChanged() => setState(() {});

  void _search(String query) {
    unawaited(
      _catalog.update(
        _catalog.filters.copyWith(search: query, compact: true),
        debounce: true,
      ),
    );
  }

  void _focus(Place place) {
    if (place.hasCoordinates) {
      _map.focusSelection(LatLng(place.latitude!, place.longitude!));
    }
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await _lookup.location.locateFix(requestPermission: true);
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.point case final point?) {
      if (!_previewOpen) _map.focusSelection(point, zoom: 15);
      widget.form.setDistanceOrigin(
        (result.accuracy ?? double.infinity) <= 250 &&
                result.timestamp != null &&
                DateTime.now().difference(result.timestamp!) <
                    const Duration(minutes: 2)
            ? point
            : null,
      );
      return;
    }
    final l10n = context.l10n;
    final message = switch (result.issue) {
      MapLocationIssue.disabled => l10n.locationDisabled,
      MapLocationIssue.denied ||
      MapLocationIssue.deniedForever => l10n.locationPermissionDenied,
      MapLocationIssue.unavailable => l10n.couldNotGetLocation,
      null => null,
    };
    if (message == null) return;
    final settings = switch (result.issue) {
      MapLocationIssue.disabled => Geolocator.openLocationSettings,
      MapLocationIssue.deniedForever => Geolocator.openAppSettings,
      _ => null,
    };
    AppSnackBar.showError(
      message,
      actionLabel: settings == null ? null : l10n.openAppSettings,
      onAction: settings == null ? null : () => unawaited(settings()),
    );
  }

  void _pin(LatLng point) {
    if (_previewOpen) return;
    final l10n = context.l10n;
    _map.focusSelection(point, zoom: _map.camera.position?.zoom ?? 15);
    unawaited(_lookup.pin(point, l10n.customPlace));
    unawaited(_preview(custom: true));
  }

  void _openPlace(Place place) {
    if (_previewOpen) return;
    _revealSelectedCard(place);
    _lookup.choose(place);
    _focus(place);
    unawaited(_preview(custom: place.id.isEmpty && place.sourceId.isNotEmpty));
  }

  void _revealSelectedCard(Place place) {
    if (!_selectedCards.hasClients) return;
    final index = widget.form.selectedPlaces.indexWhere(place.matchesSelection);
    if (index < 0) return;
    final position = _selectedCards.position;
    final start = index * _SelectedPanel.cardStride;
    if (start >= position.pixels &&
        start + _SelectedPanel.cardWidth <=
            position.pixels + position.viewportDimension) {
      return;
    }
    final offset =
        (start + (_SelectedPanel.cardWidth - position.viewportDimension) / 2)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    _draggingCards = false;
    if (AppMotion.reduce(context)) {
      _selectedCards.jumpTo(offset);
    } else {
      unawaited(
        _selectedCards.animateTo(
          offset,
          duration: AppMotion.standard,
          curve: AppMotion.enter,
        ),
      );
    }
  }

  bool _selectedCardsScrolled(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.horizontal) return false;
    if (event is ScrollStartNotification) {
      _draggingCards = event.dragDetails != null;
    }
    if (event is ScrollEndNotification && _draggingCards) {
      _draggingCards = false;
      final places = widget.form.selectedPlaces;
      if (places.length > 1) {
        final center =
            event.metrics.pixels + event.metrics.viewportDimension / 2;
        final index =
            ((center - _SelectedPanel.cardWidth / 2) /
                    _SelectedPanel.cardStride)
                .round()
                .clamp(0, places.length - 1);
        _focus(places[index]);
      }
    }
    return false;
  }

  Future<void> _preview({required bool custom}) async {
    _previewOpen = true;
    final owner = context.read<AuthProvider>().user?.id;
    _searchFocus.unfocus();
    try {
      await AppBottomSheet.show<void>(
        context: context,
        builder: (sheetContext) => ListenableBuilder(
          listenable: _lookup,
          builder: (context, _) {
            final account = context.watch<AuthProvider>().user?.id;
            final place = _lookup.candidate;
            if (!mounted || owner != account || place == null) {
              return const SizedBox.shrink();
            }
            final l10n = context.l10n;
            final form = widget.form;
            final selected = form.selectedPlaces.indexWhere(
              place.matchesSelection,
            );
            final canOpenDetails =
                place.id.isNotEmpty && !place.id.startsWith('private:');
            final message = place.status == 'permanently_closed'
                ? l10n.pickLocationRequired
                : selected < 0 &&
                      form.selectedPlaces.length >= form.maxSelections
                ? (form.specialEvent
                      ? l10n.creationEventOnePlace
                      : l10n.pickAtMostFivePlaces)
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlaceCard(
                  form: form,
                  catalog: _catalog,
                  place: place,
                  selected: selected >= 0,
                ),
                if (custom) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _lookup.nameController,
                    onChanged: _lookup.rename,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(labelText: l10n.chooseLocation),
                  ),
                ],
                if (_lookup.lookingUp)
                  Text(l10n.lookingUpLocation)
                else if (_lookup.lookupFailed)
                  Text(l10n.mapLookupFailed),
                if (custom)
                  if (_lookup.attribution case final credit?)
                    Text(credit, style: context.texts.bodySmall),
                if (message != null)
                  Text(message, style: TextStyle(color: context.colors.error)),
                const SizedBox(height: 8),
                if (selected >= 0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline),
                    label: Text(l10n.mapRemovePlace),
                    onPressed: () {
                      form.removePlace(place);
                      Navigator.of(sheetContext).pop();
                    },
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(l10n.mapAddPlace),
                    onPressed: !_lookup.lookingUp && form.canAddPlace(place)
                        ? () {
                            form.addPlace(place);
                            Navigator.of(sheetContext).pop();
                          }
                        : null,
                  ),
                if (selected >= 0 && form.multiPlaceMode)
                  Wrap(
                    children: [
                      if (selected > 0)
                        TextButton(
                          onPressed: () => _movePlace(
                            form,
                            selected,
                            selected - 1,
                            sheetContext,
                          ),
                          child: Text(l10n.mapMoveUp),
                        ),
                      if (selected + 1 < form.selectedPlaces.length)
                        TextButton(
                          onPressed: () => _movePlace(
                            form,
                            selected,
                            selected + 1,
                            sheetContext,
                          ),
                          child: Text(l10n.mapMoveDown),
                        ),
                    ],
                  ),
                if (canOpenDetails)
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Get.to(
                        () => DiscoverPlaceDetailsPage(
                          placeId: place.id,
                          coverUrl: place.imageUrl,
                        ),
                      );
                    },
                    child: Text(l10n.creationPlaceDetails),
                  ),
                if (canOpenDetails &&
                    place.brandId.isNotEmpty &&
                    place.branchCount > 1)
                  PlaceBranchesButton(
                    count: place.branchCount,
                    onPressed: () async {
                      final branch = await pickPlaceBranch(sheetContext, place);
                      if (!mounted || !sheetContext.mounted || branch == null) {
                        return;
                      }
                      final next = branch.toOutingPlace();
                      _lookup.choose(next);
                      _focus(next);
                    },
                  ),
              ],
            );
          },
        ),
      );
    } finally {
      _previewOpen = false;
      if (mounted) _lookup.clearCandidate();
    }
  }

  void _movePlace(
    CreateOutingProvider form,
    int from,
    int to,
    BuildContext sheet,
  ) {
    final places = [...form.selectedPlaces];
    places.insert(to, places.removeAt(from));
    form.replaceMapSelection(places);
    Navigator.of(sheet).pop();
  }

  void _readPanelSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _panelKey.currentContext?.size?.height ?? 0;
      if (_panelInset.value != height) _panelInset.value = height;
    });
  }

  Widget _mapRegion(BuildContext context, List<Place> selected) {
    final l10n = context.l10n;
    final searches = _searchFocus.hasFocus;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final style = OutingCreationStyle(context);
    final initial = selected.firstOrNull;
    final center = initial?.hasCoordinates == true
        ? LatLng(initial!.latitude!, initial.longitude!)
        : cairoMapCenter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelLimit = (constraints.maxHeight * .5).clamp(
          0.0,
          (constraints.maxHeight - 145).clamp(0.0, double.infinity),
        );
        final showPanel = !keyboard && panelLimit >= 44;
        _readPanelSize();
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              child: ColoredBox(
                color: style.dark ? const Color(0xFF111A2A) : style.field,
                child: ValueListenableBuilder(
                  valueListenable: _panelInset,
                  builder: (context, inset, _) => YallaMapView(
                    controller: _map,
                    center: center,
                    zoom: center == cairoMapCenter ? 12 : 15,
                    selectionBottom: inset,
                    controlsTop: 4,
                    customControls: true,
                    categories: _catalog.categories,
                    places: _places,
                    privatePlaces: _privatePlaces,
                    selection: YallaMapPlaceSelection(
                      mode: selected.length > 1
                          ? YallaMapSelectionMode.multiple
                          : YallaMapSelectionMode.single,
                      selected: selected,
                      showChecks: true,
                    ),
                    onPlaceTap: _openPlace,
                    onTap: _pin,
                    onUserMove: () {
                      if (_catalog.filters.search.trim().isEmpty) {
                        _catalog.cameraMoving();
                      }
                      _searchFocus.unfocus();
                    },
                    onViewportChanged: (bounds, camera) =>
                        _catalog.setBounds(bounds, zoom: camera.zoom),
                  ),
                ),
              ),
            ),
            if (_catalog.loading && !searches)
              const PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!searches)
              PositionedDirectional(
                top: 10,
                end: 7,
                child: Column(
                  children: [
                    CreationIconButton(
                      icon: Icons.near_me_outlined,
                      tooltip: l10n.currentLocation,
                      onPressed: _locating ? null : _locate,
                    ),
                    const SizedBox(height: 3),
                    CreationIconButton(
                      icon: Icons.layers_outlined,
                      tooltip: l10n.mapFilters,
                      onPressed: () => AppBottomSheet.show<void>(
                        context: context,
                        builder: (_) => PlaceCatalogFilters(catalog: _catalog),
                      ),
                    ),
                  ],
                ),
              ),
            if (showPanel)
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  key: _panelKey,
                  constraints: BoxConstraints(maxHeight: panelLimit),
                  child: _SelectedPanel(
                    form: widget.form,
                    catalog: _catalog,
                    onOpen: _openPlace,
                    scrollController: _selectedCards,
                    onScroll: _selectedCardsScrolled,
                  ),
                ),
              ),
            if (searches)
              ValueListenableBuilder(
                valueListenable: _panelInset,
                builder: (context, inset, _) => PositionedDirectional(
                  start: 8,
                  end: 8,
                  top: 0,
                  bottom: showPanel ? inset.clamp(0.0, panelLimit) + 8 : 2,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ListenableBuilder(
                      listenable: _lookup,
                      builder: (_, _) => _SearchResults(
                        catalog: _catalog,
                        lookup: _lookup,
                        selected: selected,
                        onChoose: _openPlace,
                        onDismiss: _searchFocus.unfocus,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final form = widget.form;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final selected = context.select(
      (CreateOutingProvider value) => value.selectedPlaces,
    );
    context.select((CreateOutingProvider value) => value.distanceOrigin);
    final offline = context.select(
      (AppSyncProvider value) => value.status == SyncStatus.offline,
    );
    return LayoutBuilder(
      builder: (context, size) {
        final compact = size.maxHeight < 415;
        final contents = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 15),
                child: CreationSectionHeading(
                  icon: Icons.location_on_rounded,
                  title: l10n.creationChooseLocation,
                  subtitle: form.specialEvent
                      ? l10n.creationFixedHint
                      : l10n.wizardMapHint,
                ),
              ),
            ],
            Padding(
              key: const ValueKey('place-search'),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 7),
              child: ValueListenableBuilder(
                valueListenable: _catalog.searchController,
                builder: (context, value, _) => TextField(
                  controller: _catalog.searchController,
                  focusNode: _searchFocus,
                  onChanged: _search,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 14.5, color: style.ink),
                  decoration: InputDecoration(
                    hintText: l10n.creationSearch,
                    hintStyle: TextStyle(color: style.muted),
                    filled: true,
                    fillColor: style.field,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: style.muted,
                      size: 23,
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.clearGroupSearch,
                            onPressed: () => _search(''),
                            icon: Icon(Icons.close, color: style.muted),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: style.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: style.active),
                    ),
                  ),
                ),
              ),
            ),
            if (offline && !compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Text(
                  l10n.syncOffline,
                  style: TextStyle(color: style.muted),
                ),
              ),
            Expanded(
              key: const ValueKey('location-map'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ListenableBuilder(
                  listenable: _catalog,
                  builder: (context, _) {
                    if (!identical(_catalogResults, _catalog.places)) {
                      _catalogResults = _catalog.places;
                      final places = _catalog.places
                          .map((p) => p.toOutingPlace())
                          .toList();
                      _places = places
                          .where((p) => !p.id.startsWith('private:'))
                          .toList();
                      _privatePlaces = places
                          .where((p) => p.id.startsWith('private:'))
                          .toList();
                    }
                    return _mapRegion(context, selected);
                  },
                ),
              ),
            ),
            if (!keyboard)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: CreationPrimaryButton(
                  label: l10n.creationNext,
                  icon: context.chevronForward,
                  trailing: true,
                  onPressed: form.validateLocation(l10n) == null
                      ? widget.onNext
                      : null,
                ),
              ),
          ],
        );
        final height = size.maxHeight.clamp(
          keyboard ? 170.0 : 385.0,
          double.infinity,
        );
        return SingleChildScrollView(
          physics: height > size.maxHeight
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(height: height, child: contents),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.catalog,
    required this.lookup,
    required this.selected,
    required this.onChoose,
    required this.onDismiss,
  });

  final PlaceCatalogProvider catalog;
  final PickLocationProvider lookup;
  final List<Place> selected;
  final ValueChanged<Place> onChoose;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final places = [
      ...catalog.places.map((p) => p.toOutingPlace()),
      ...lookup.results.where((p) => p.id.isEmpty),
    ];
    final busy = catalog.loading || lookup.searching;
    return Material(
      color: style.panel,
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                onPressed: onDismiss,
                tooltip: l10n.cancel,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
          if (busy)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (!busy &&
              places.isEmpty &&
              catalog.error == null &&
              !lookup.searchFailed)
            SliverToBoxAdapter(
              child: ListTile(title: Text(l10n.creationNoResults)),
            ),
          SliverList.builder(
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              final chosen = selected.any(place.matchesSelection);
              return ListTile(
                selected: chosen,
                leading: Icon(
                  chosen ? Icons.check_circle : Icons.place_outlined,
                ),
                title: Text(place.displayName(l10n.locale.languageCode)),
                subtitle: place.branchLabel.isEmpty
                    ? null
                    : Text(place.branchLabel),
                onTap: () => onChoose(place),
              );
            },
          ),
          if (lookup.searchFailed)
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(l10n.mapLookupFailed),
                trailing: IconButton(
                  tooltip: l10n.tryAgain,
                  onPressed: () =>
                      lookup.search(catalog.filters.search, retry: true),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          if (lookup.attribution case final credit?)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(credit, style: context.texts.bodySmall),
              ),
            ),
          if (catalog.hasMore || catalog.error != null)
            SliverToBoxAdapter(child: CatalogLoadMore(catalog: catalog)),
        ],
      ),
    );
  }
}

class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({
    required this.form,
    required this.catalog,
    required this.onOpen,
    required this.scrollController,
    required this.onScroll,
  });

  static const cardWidth = 258.0;
  static const cardGap = 8.0;
  static const cardStride = cardWidth + cardGap;

  final ScrollController scrollController;
  final NotificationListenerCallback<ScrollNotification> onScroll;
  final CreateOutingProvider form;
  final PlaceCatalogProvider catalog;
  final ValueChanged<Place> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final places = form.selectedPlaces;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: style.panel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
          bottom: Radius.circular(17),
        ),
        border: Border.all(color: style.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x36080411),
            blurRadius: 7,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (places.length == 1)
              _PlaceCard(
                form: form,
                catalog: catalog,
                place: places.single,
                selected: true,
                onTap: () => onOpen(places.single),
              ),
            if (places.length > 1)
              NotificationListener<ScrollNotification>(
                onNotification: onScroll,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final place in places)
                        Padding(
                          key: ValueKey((
                            place.id,
                            place.name,
                            place.latitude,
                            place.longitude,
                          )),
                          padding: const EdgeInsetsDirectional.only(
                            end: cardGap,
                          ),
                          child: SizedBox(
                            width: cardWidth,
                            child: _PlaceCard(
                              form: form,
                              catalog: catalog,
                              place: place,
                              selected: true,
                              compact: true,
                              onTap: () => onOpen(place),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  child: Icon(
                    places.isEmpty
                        ? Icons.location_on_outlined
                        : Icons.location_on_rounded,
                    size: 20,
                    color: style.active,
                  ),
                ),
                Expanded(
                  child: Text(
                    places.isEmpty
                        ? l10n.creationPickFirst
                        : l10n.creationSelectedCount(places.length),
                    style: TextStyle(fontSize: 12.5, color: style.muted),
                  ),
                ),
                if (places.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: style.active,
                    ),
                    onPressed: () => form.replaceMapSelection(const []),
                    child: Text(l10n.creationClear),
                  ),
              ],
            ),
            if (places.length > 1)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
                child: Text(
                  l10n.creationVoteHint,
                  style: TextStyle(fontSize: 12, color: style.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.form,
    required this.catalog,
    required this.place,
    required this.selected,
    this.compact = false,
    this.onTap,
  });

  final CreateOutingProvider form;
  final PlaceCatalogProvider catalog;
  final Place place;
  final bool selected, compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final language = l10n.locale.languageCode;
    final title = place.displayName(language);
    final category = catalog.categories
        .where((c) => c.id == place.categoryId)
        .firstOrNull
        ?.label(language);
    final subtitle = [
      if (category != null && category.isNotEmpty) category,
      if (form.placeDistanceKm(place) case final km?)
        l10n.catalogDistanceLabel(km),
    ].join(' · ');
    return Semantics(
      selected: selected,
      child: DecoratedBox(
        decoration: style.surface(raised: true),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  PlanningCover(
                    url: place.imageUrl,
                    art: PlanningCoverArt.outing,
                    width: compact ? 66 : 96,
                    height: compact ? 51 : 60,
                    radius: 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: style.ink,
                          ),
                        ),
                        if (subtitle.isNotEmpty || place.branchLabel.isNotEmpty)
                          Text(
                            subtitle.isEmpty ? place.branchLabel : subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: style.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: OutingCreationStyle.activeGradient,
                        ),
                        child: SizedBox.square(
                          dimension: 26,
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

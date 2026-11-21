import 'package:yalla_5roga/features/discover/presentation/widgets/place_branch_picker.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_markers.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/pick_location_provider.dart';

class PickLocationPage extends StatelessWidget {
  const PickLocationPage({
    super.key,
    required this.catalog,
    this.initial,
    this.placeCatalog,
    this.selected = const [],
    this.onConfirm,
    this.maxSelections = 1,
    this.location = const MapLocation(),
  });

  final List<Place> catalog;
  final PlaceCatalogProvider? placeCatalog;
  final Place? initial;
  final List<Place> selected;
  final int maxSelections;
  final ValueChanged<List<Place>>? onConfirm;
  final MapLocation location;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => PickLocationProvider(
      geocoding: context.read<LocationRepository>(),
      location: location,
      catalog: catalog,
      language: context.l10n.locale.languageCode == 'ar' ? 'ar' : 'en',
      initial: initial,
      selected: selected,
      maxSelections: maxSelections,
    ),
    child: _Picker(placeCatalog: placeCatalog, onConfirm: onConfirm),
  );
}

class _Picker extends StatefulWidget {
  const _Picker({this.placeCatalog, this.onConfirm});
  final ValueChanged<List<Place>>? onConfirm;
  final PlaceCatalogProvider? placeCatalog;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final _map = widget.placeCatalog?.mapController ?? YallaMapController();
  final _sheet = DraggableScrollableController();
  final _sheetInset = ValueNotifier<double>(0);
  final _searchFocus = FocusNode();
  final _query = TextEditingController();
  void _catalogChanged() {
    if (mounted) {
      setState(() {
        final search = widget.placeCatalog?.filters.search ?? '';
        if (_query.text != search) {
          _query.value = TextEditingValue(
            text: search,
            selection: TextSelection.collapsed(offset: search.length),
          );
        }
      });
    }
  }

  var _collapsed = .4;
  var _height = 0.0;

  PickLocationProvider get _picker => context.read<PickLocationProvider>();

  @override
  void initState() {
    super.initState();
    _query.text = widget.placeCatalog?.filters.search ?? '';
    widget.placeCatalog?.addListener(_catalogChanged);
    _searchFocus.addListener(_onSearchFocus);
    _sheet.addListener(_updateInset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateInset();
      if (_picker.multiple) {
        _fit();
      } else if (_picker.candidate case final place?
          when place.hasCoordinates) {
        _map.focusSelection(
          LatLng(place.latitude!, place.longitude!),
          zoom: 15,
        );
      }
    });
  }

  void _updateInset() {
    _sheetInset.value = _sheet.isAttached ? _sheet.pixels : 0;
    _map.attributionInset.value = _sheetInset.value;
  }

  void _onSearchFocus() {
    if (!_searchFocus.hasFocus && widget.placeCatalog == null) {
      _query.clear();
      _picker.search('');
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateInset();
    });
  }

  void _fit() {
    if (!_picker.multiple) return;
    final points = [
      for (final place in _picker.selected)
        if (place.hasCoordinates) LatLng(place.latitude!, place.longitude!),
    ];
    _map.fit(
      points,
      padding: EdgeInsets.fromLTRB(40, 100, 40, _height * _collapsed + 80),
    );
  }

  void _collapse() {
    FocusScope.of(context).unfocus();
    if (_sheet.isAttached) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _sheet.jumpTo(_collapsed);
      } else {
        unawaited(
          _sheet.animateTo(
            _collapsed,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  void _pin(LatLng point, {bool focus = false}) {
    if (focus) {
      _collapse();
      _map.focusSelection(point);
    }
    unawaited(_picker.pin(point, context.l10n.customPlace));
  }

  void _choose(Place place) {
    if (widget.placeCatalog == null) _query.clear();
    _collapse();
    _picker.choose(
      place.id.startsWith('private:') ? place.copyWith(id: '') : place,
    );
    if (place.hasCoordinates) {
      _map.focusSelection(LatLng(place.latitude!, place.longitude!));
    }
  }

  Future<void> _locate() async {
    final result = await _picker.locate();
    if (!mounted) return;
    if (result.point case final point?) {
      _pin(point, focus: true);
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

  void _confirm() {
    final picker = _picker;
    if (picker.multiple) {
      _finish(picker.selected);
    } else if (picker.canUseCandidate) {
      _finish([picker.candidate!]);
    }
  }

  void _finish(List<Place> places) {
    if (widget.onConfirm case final confirm?) {
      confirm(places);
    } else {
      Navigator.of(context).pop(places);
    }
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocus);
    _searchFocus.dispose();
    widget.placeCatalog?.removeListener(_catalogChanged);
    _query.dispose();
    _sheet.dispose();
    _sheetInset.dispose();
    if (widget.placeCatalog == null) _map.dispose();
    if (widget.onConfirm == null) widget.placeCatalog?.clearBounds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picker = _picker;
    final initial = picker.candidate ?? picker.selected.firstOrNull;
    // The first map viewport is fixed for the route. Camera changes use the controller.
    final center = _initialCenter ??= initial?.hasCoordinates == true
        ? LatLng(initial!.latitude!, initial.longitude!)
        : cairoMapCenter;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final searching = _searchFocus.hasFocus;
    final embedded = widget.onConfirm != null;
    final mapBody = LayoutBuilder(
      builder: (context, constraints) {
        if (_height != constraints.maxHeight) {
          _height = constraints.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateInset();
          });
        }
        _collapsed = (242 / _height).clamp(.34, embedded ? .58 : .69);
        return Stack(
          fit: StackFit.expand,
          children: [
            Consumer<PickLocationProvider>(
              builder: (_, state, _) => YallaMapView(
                controller: _map,
                center: center,
                zoom: center == cairoMapCenter ? 12 : 15,
                selectionBottom: _height * _collapsed,
                onTap: (point) => _pin(point, focus: true),
                onUserMove: () {
                  widget.placeCatalog?.cameraMoving();
                  picker.startMoving();
                },
                onUserIdle: _pin,
                onBoundsChanged: widget.placeCatalog?.setBounds,
                categories: widget.placeCatalog?.categories ?? const [],
                places:
                    widget.placeCatalog?.places
                        .where((p) => !p.id.startsWith('private:'))
                        .map((p) => p.toOutingPlace())
                        .toList() ??
                    picker.catalog,
                privatePlaces:
                    widget.placeCatalog?.places
                        .where((p) => p.id.startsWith('private:'))
                        .map((p) => p.toOutingPlace())
                        .toList() ??
                    const [],
                selection: YallaMapPlaceSelection(
                  mode: picker.multiple
                      ? YallaMapSelectionMode.multiple
                      : YallaMapSelectionMode.single,
                  focusedId: state.candidate?.id,
                  selected: state.selected,
                ),
                onPlaceTap: _choose,
              ),
            ),
            if (!searching)
              Align(
                child: IgnorePointer(
                  child: Selector<PickLocationProvider, bool>(
                    selector: (_, picker) => picker.moving,
                    builder: (_, moving, _) => Transform.translate(
                      offset: Offset(0, -21 - _height * _collapsed / 2),
                      child: AnimatedSlide(
                        offset: moving ? const Offset(0, -.25) : Offset.zero,
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        child: Image.asset(
                          '${YallaMapMarkers.assetPath}/temporary.png',
                          width: 44,
                          height: 44,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!searching)
              Align(
                alignment: AlignmentDirectional.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth,
                  ),
                  child: DraggableScrollableSheet(
                    controller: _sheet,
                    expand: false,
                    initialChildSize: _collapsed,
                    minChildSize: _collapsed,
                    maxChildSize: .88,
                    shouldCloseOnMinExtent: false,
                    builder: (context, scrollController) => _Details(
                      scrollController: scrollController,
                      onConfirm: _confirm,
                      wizard: embedded,
                      onUseCenter: () => _pin(_map.selectionPoint),
                      onAdd: () {
                        if (picker.add()) {
                          _collapse();
                          _fit();
                        }
                      },
                      onRemove: (index) {
                        picker.remove(index);
                        _collapse();
                        _fit();
                      },
                      onFocusPlace: _choose,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.topCenter,
              child: SafeArea(
                bottom: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MapSearchBar(
                          controller: _query,
                          focusNode: _searchFocus,
                          onChanged: (value) {
                            picker.search(value);
                            widget.placeCatalog?.update(
                              widget.placeCatalog!.filters.copyWith(
                                search: value,
                              ),
                              debounce: true,
                            );
                          },
                          leading: embedded ? null : const BackButton(),
                          trailing: Selector<PickLocationProvider, bool>(
                            selector: (_, picker) => picker.locating,
                            builder: (_, locating, _) =>
                                MapCurrentLocationButton(
                                  busy: locating,
                                  onPressed: _locate,
                                ),
                          ),
                        ),
                        if (searching)
                          Flexible(
                            child: _SearchResults(
                              onChoose: _choose,
                              query: _query,
                              catalog: widget.placeCatalog,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    return embedded ? mapBody : Scaffold(body: mapBody);
  }

  LatLng? _initialCenter;
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.onChoose,
    required this.query,
    this.catalog,
  });
  final PlaceCatalogProvider? catalog;

  final ValueChanged<Place> onChoose;
  final TextEditingController query;

  @override
  Widget build(BuildContext context) {
    final picker = context.watch<PickLocationProvider>();
    final l10n = context.l10n;

    final places = catalog != null
        ? catalog!.places.map((p) => p.toOutingPlace()).toList()
        : (query.text.trim().isEmpty ? picker.catalog : picker.results)
              .where((p) => p.status == 'active')
              .toList();
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          if (catalog case final catalog?) ...[
            PlaceCatalogFilters(catalog: catalog),
            CatalogLoadMore(catalog: catalog),
          ],
          for (final place in places)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(place.displayName(l10n.locale.languageCode)),
              subtitle: place.area.isEmpty ? null : Text(place.area),
              onTap: () => onChoose(place),
            ),
          if (catalog != null && picker.results.any((p) => p.id.isEmpty)) ...[
            ListTile(title: Text(l10n.catalogSearchLocations)),
            for (final hit in picker.results.where((p) => p.id.isEmpty))
              ListTile(
                leading: const Icon(Icons.travel_explore),
                title: Text(hit.name),
                subtitle: Text(hit.area),
                onTap: () => onChoose(hit),
              ),
          ],
          if (!picker.searching && places.isEmpty && !picker.searchFailed)
            ListTile(title: Text(l10n.mapNoResults)),
          if (picker.searchFailed)
            ListTile(
              title: Text(l10n.mapLookupFailed),
              trailing: IconButton(
                tooltip: l10n.tryAgain,
                onPressed: () => picker.search(query.text, retry: true),
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (picker.attribution case final credit?)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                credit,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.scrollController,
    required this.onConfirm,
    required this.onUseCenter,
    required this.onAdd,
    required this.onRemove,
    required this.onFocusPlace,
    required this.wizard,
  });

  final ScrollController scrollController;
  final bool wizard;
  final VoidCallback onConfirm;
  final VoidCallback onUseCenter;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<Place> onFocusPlace;

  @override
  Widget build(BuildContext context) {
    final picker = context.watch<PickLocationProvider>();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final candidate = picker.candidate;
    final canContinue = picker.multiple
        ? !wizard ||
              (picker.selected.length >= 2 &&
                  picker.selected.every(_validSelection))
        : picker.canUseCandidate &&
              (!wizard || (candidate != null && _validSelection(candidate)));
    final confirm = CustomButton(
      label: wizard
          ? l10n.continueToDetails
          : picker.multiple
          ? l10n.mapUsePlaces
          : l10n.confirmLocation,
      onPressed: canContinue ? onConfirm : null,
    );
    final content = ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        wizard ? 6 : 16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          picker.multiple
              ? l10n.placesSelectedMax(
                  picker.selected.length,
                  picker.maxSelections,
                )
              : l10n.pickLocation,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        if (picker.moving || candidate == null) ...[
          Text(l10n.mapPinHint),
          if (!picker.moving &&
              (!picker.multiple ||
                  picker.selected.length < picker.maxSelections))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onUseCenter,
                child: Text(l10n.mapUseCenter),
              ),
            ),
        ] else if (candidate.id.isEmpty)
          TextField(
            controller: picker.nameController,
            onChanged: picker.rename,
            maxLength: 100,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.chooseLocation,
              helperText: candidate.area.isEmpty ? null : candidate.area,
              helperMaxLines: 2,
            ),
          )
        else
          MapSelectedLocationCard(
            title: candidate.name,
            subtitle: candidate.area,
            imageUrl: candidate.imageUrl,
            selected: true,
            trailing: wizard && !picker.multiple
                ? IconButton(
                    tooltip: l10n.mapRemovePlace,
                    onPressed: picker.clearCandidate,
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
        if (wizard &&
            candidate != null &&
            candidate.brandId.isNotEmpty &&
            candidate.branchCount > 1)
          PlaceBranchesButton(
            count: candidate.branchCount,
            onPressed: () async {
              final branch = await pickPlaceBranch(context, candidate);
              if (context.mounted && branch != null) {
                onFocusPlace(branch.toOutingPlace());
              }
            },
          ),
        if (wizard && !picker.multiple && candidate?.id.isEmpty == true)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: picker.clearCandidate,
              child: Text(l10n.mapRemovePlace),
            ),
          ),
        if (picker.lookingUp) ...[
          const SizedBox(height: 4),
          Semantics(liveRegion: true, child: Text(l10n.lookingUpLocation)),
        ],
        if (picker.lookupFailed) Text(l10n.mapLookupFailed),
        if (picker.duplicate) Text(l10n.mapAlreadySelected),
        const SizedBox(height: 8),
        if (picker.multiple && candidate != null)
          FilledButton.tonalIcon(
            onPressed: picker.canUseCandidate ? onAdd : null,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.mapAddPlace),
          ),
        if (!wizard) confirm,
        if (picker.attribution case final credit?)
          Text(credit, style: theme.textTheme.labelSmall),
        if (picker.multiple)
          for (final (index, place) in picker.selected.indexed)
            _SelectedPlace(
              place: place,
              index: index,
              count: picker.selected.length,
              onFocus: () => onFocusPlace(place),
              onRemove: () => onRemove(index),
              onMove: (delta) => picker.move(index, index + delta),
            ),
      ],
    );
    return Material(
      color: theme.colorScheme.surface,
      elevation: 5,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: wizard
          ? Column(
              children: [
                Expanded(child: content),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: confirm,
                ),
              ],
            )
          : content,
    );
  }

  bool _validSelection(Place place) =>
      place.status != 'permanently_closed' &&
      (place.id.isNotEmpty || place.hasCoordinates);
}

class _SelectedPlace extends StatelessWidget {
  const _SelectedPlace({
    required this.place,
    required this.index,
    required this.count,
    required this.onFocus,
    required this.onRemove,
    required this.onMove,
  });

  final Place place;
  final int index;
  final int count;
  final VoidCallback onFocus;
  final VoidCallback onRemove;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MapSelectedLocationCard(
      title: '${l10n.n(index + 1)}. ${place.name}',
      subtitle: place.area,
      imageUrl: place.imageUrl,
      onTap: onFocus,
      selected: true,
      trailing: PopupMenuButton<int>(
        tooltip: l10n.mapEditPlace(place.name),
        onSelected: (value) => value == 0 ? onRemove() : onMove(value),
        itemBuilder: (_) => [
          if (index > 0) PopupMenuItem(value: -1, child: Text(l10n.mapMoveUp)),
          if (index + 1 < count)
            PopupMenuItem(value: 1, child: Text(l10n.mapMoveDown)),
          PopupMenuItem(value: 0, child: Text(l10n.mapRemovePlace)),
        ],
      ),
    );
  }
}

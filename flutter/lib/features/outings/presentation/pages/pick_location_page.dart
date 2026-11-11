import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_map.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/pick_location_provider.dart';

class PickLocationPage extends StatelessWidget {
  const PickLocationPage({
    super.key,
    required this.catalog,
    this.initial,
    this.selected = const [],
    this.maxSelections = 1,
    this.tileProvider,
    this.location = const MapLocation(),
  });

  final List<Place> catalog;
  final Place? initial;
  final List<Place> selected;
  final int maxSelections;
  final TileProvider? tileProvider;
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
    child: _Picker(tileProvider: tileProvider),
  );
}

class _Picker extends StatefulWidget {
  const _Picker({this.tileProvider});

  final TileProvider? tileProvider;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final _map = GlobalKey<AppMapState>();
  final _sheet = DraggableScrollableController();
  final _sheetInset = ValueNotifier<double>(0);
  final _searchFocus = FocusNode();
  final _query = TextEditingController();
  var _collapsed = .4;
  var _height = 0.0;

  PickLocationProvider get _picker => context.read<PickLocationProvider>();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocus);
    _sheet.addListener(_updateInset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateInset();
      if (_picker.multiple) {
        _fit();
      } else if (_picker.candidate case final place?
          when place.hasCoordinates) {
        _map.currentState?.focusSelection(
          LatLng(place.latitude!, place.longitude!),
          zoom: 15,
        );
      }
    });
  }

  void _updateInset() {
    _sheetInset.value = _sheet.isAttached ? _sheet.pixels : 0;
  }

  void _onSearchFocus() {
    if (!_searchFocus.hasFocus) {
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
    _map.currentState?.fit(
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
      _map.currentState?.focusSelection(point);
    }
    unawaited(_picker.pin(point, context.l10n.customPlace));
  }

  void _choose(Place place) {
    _query.clear();
    _collapse();
    _picker.choose(place);
    if (place.hasCoordinates) {
      _map.currentState?.focusSelection(
        LatLng(place.latitude!, place.longitude!),
      );
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
      Navigator.of(context).pop(picker.selected);
    } else if (picker.canUseCandidate) {
      Navigator.of(context).pop([picker.candidate!]);
    }
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocus);
    _searchFocus.dispose();
    _query.dispose();
    _sheet.dispose();
    _sheetInset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picker = _picker;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initial = picker.candidate ?? picker.selected.firstOrNull;
    // The first map viewport is fixed for the route. Camera changes use the controller.
    final center = _initialCenter ??= initial?.hasCoordinates == true
        ? LatLng(initial!.latitude!, initial.longitude!)
        : cairoMapCenter;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final searching = _searchFocus.hasFocus;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_height != constraints.maxHeight) {
            _height = constraints.maxHeight;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateInset();
            });
          }
          _collapsed = (242 / _height).clamp(.34, .69);
          return Stack(
            fit: StackFit.expand,
            children: [
              Selector<PickLocationProvider, List<Place>>(
                selector: (_, picker) => picker.selected,
                shouldRebuild: (previous, next) => !identical(previous, next),
                builder: (_, places, _) => AppMap(
                  key: _map,
                  center: center,
                  zoom: center == cairoMapCenter ? 12 : 15,
                  tileProvider: widget.tileProvider,
                  attributionInset: _sheetInset,
                  selectionBottom: _height * _collapsed,
                  onTap: (point) => _pin(point, focus: true),
                  onUserMove: picker.startMoving,
                  onUserIdle: _pin,
                  markers: [
                    for (final (index, place) in places.indexed)
                      if (place.hasCoordinates)
                        Marker(
                          key: ValueKey((
                            place.id,
                            place.name,
                            place.latitude,
                            place.longitude,
                            index,
                          )),
                          point: LatLng(place.latitude!, place.longitude!),
                          width: 48,
                          height: 48,
                          child: Semantics(
                            selected: true,
                            child: IconButton.filled(
                              tooltip: l10n.mapSelectedPlace(place.name),
                              onPressed: () => _choose(place),
                              icon: Text(l10n.n(index + 1)),
                            ),
                          ),
                        ),
                  ],
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
                          child: Icon(
                            Icons.location_on,
                            size: 44,
                            color: scheme.primary,
                            shadows: [
                              Shadow(color: scheme.surface, blurRadius: 4),
                            ],
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
                        onUseCenter: () =>
                            _pin(_map.currentState?.selectionPoint ?? center),
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
                          Material(
                            color: scheme.surface,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              children: [
                                const BackButton(),
                                Expanded(
                                  child: TextField(
                                    controller: _query,
                                    focusNode: _searchFocus,
                                    onChanged: picker.search,
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText: l10n.mapSearchHint,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (searching)
                                  IconButton(
                                    tooltip: MaterialLocalizations.of(context)
                                        .closeButtonTooltip,
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _query.clear();
                                      _searchFocus.unfocus();
                                    },
                                  )
                                else
                                  Selector<PickLocationProvider, bool>(
                                    selector: (_, picker) => picker.locating,
                                    builder: (_, locating, _) => IconButton(
                                      tooltip: l10n.yourLocation,
                                      onPressed: locating ? null : _locate,
                                      icon: locating
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.my_location),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (searching)
                            Flexible(
                              child: _SearchResults(
                                onChoose: _choose,
                                query: _query,
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
      ),
    );
  }

  LatLng? _initialCenter;
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.onChoose, required this.query});

  final ValueChanged<Place> onChoose;
  final TextEditingController query;

  @override
  Widget build(BuildContext context) {
    final picker = context.watch<PickLocationProvider>();
    final l10n = context.l10n;
    if (query.text.trim().isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          if (picker.searching) const LinearProgressIndicator(),
          for (final place in picker.results)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(place.name),
              subtitle: place.area.isEmpty ? null : Text(place.area),
              onTap: () => onChoose(place),
            ),
          if (!picker.searching &&
              picker.results.isEmpty &&
              !picker.searchFailed)
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
  });

  final ScrollController scrollController;
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
    return Material(
      color: theme.colorScheme.surface,
      elevation: 5,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(candidate.name),
              subtitle: candidate.area.isEmpty ? null : Text(candidate.area),
            ),
          if (picker.lookingUp) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              label: l10n.lookingUpLocation,
              child: const LinearProgressIndicator(),
            ),
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
          FilledButton(
            onPressed: picker.multiple || picker.canUseCandidate
                ? onConfirm
                : null,
            child: Text(
              picker.multiple ? l10n.mapUsePlaces : l10n.confirmLocation,
            ),
          ),
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
      ),
    );
  }
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(l10n.n(index + 1))),
      title: Text(place.name),
      subtitle: place.area.isEmpty ? null : Text(place.area),
      onTap: onFocus,
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

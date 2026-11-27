import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/maps/personal_location_map_layer.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

import '../../domain/entities/default_starting_location.dart';
import '../../domain/entities/saved_location.dart';
import '../pages/add_edit_location_page.dart';
import '../providers/saved_locations_provider.dart';
import 'saved_location_card.dart';

typedef PersonalMapBuilder = Widget Function(
  BuildContext context,
  List<PersonalMapMarker> markers,
  void Function(String key, Place? catalogPlace) onTap,
);

class PersonalLocationsMap extends StatefulWidget {
  const PersonalLocationsMap({
    super.key,
    required this.controller,
    required this.builder,
    this.onCatalogPlaceSelected,
    this.toggleAlignment = AlignmentDirectional.topStart,
    this.togglePadding = const EdgeInsetsDirectional.only(top: 8, start: 12),
    this.showToggle = true,
  });

  final YallaMapController controller;
  final PersonalMapBuilder builder;
  final ValueChanged<Place>? onCatalogPlaceSelected;
  final AlignmentDirectional toggleAlignment;
  final EdgeInsetsGeometry togglePadding;
  final bool showToggle;

  @override
  State<PersonalLocationsMap> createState() => _PersonalLocationsMapState();
}

class _PersonalLocationsMapState extends State<PersonalLocationsMap>
    with WidgetsBindingObserver {
  SavedLocationsProvider? _provider;
  int? _requestedSession;
  bool _visible = true;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = _provider;
    if (state == AppLifecycleState.resumed &&
        _visible &&
        provider != null &&
        provider.hasAccount) {
      unawaited(provider.refresh());
    }
  }

  List<_MapLocation> _entries(SavedLocationsProvider provider) {
    final selected = provider.defaultLocation;
    final bookmark = selected?.source == StartingLocationSource.savedPlace
        ? selected
        : null;
    final bookmarkPoint = bookmark == null ? null : _point(bookmark);
    var bookmarkMerged = false;
    final entries = <_MapLocation>[];
    for (final location in provider.locations) {
      final reference = DefaultStartingLocation.personal(location);
      final merge =
          !bookmarkMerged &&
          bookmarkPoint != null &&
          bookmark!.referenceId == location.placeId &&
          PersonalLocationMapLayer.overlaps(_point(reference), bookmarkPoint);
      bookmarkMerged |= merge;
      entries.add(
        _MapLocation(
          reference,
          personal: location,
          isDefault:
              merge ||
              (selected?.matches(reference.source, reference.referenceId) ??
                  false),
        ),
      );
    }
    if (bookmark != null && !bookmarkMerged) {
      entries.add(_MapLocation(bookmark, isDefault: true));
    }
    return entries
        .where((entry) {
          final point = entry.marker.point;
          return point.latitude.abs() <= 85.051129 &&
              point.longitude.abs() <= 180;
        })
        .toList(growable: false);
  }

  _MapLocation? _entry(SavedLocationsProvider provider, String key) =>
      _entries(provider).where((entry) => entry.key == key).firstOrNull;

  Future<void> _openDetails(String key, Place? catalogPlace) async {
    final provider = _provider;
    if (_detailsOpen || !_visible || provider == null || !provider.hasAccount) {
      return;
    }
    final session = provider.session;
    if (_entry(provider, key) == null) return;
    final canSelectPlace =
        widget.onCatalogPlaceSelected != null && catalogPlace != null;
    _detailsOpen = true;
    try {
      final action = await AppBottomSheet.show<_LocationAction>(
        context: context,
        builder: (context) => ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            final entry = provider.matchesSession(session)
                ? _entry(provider, key)
                : null;
            if (entry == null) return const SizedBox.shrink();
            return _PersonalLocationDetails(
              entry: entry,
              isStarting: entry.represents(provider.startingLocation),
              isSaving: provider.isSaving,
              canSelectPlace: canSelectPlace,
            );
          },
        ),
      );
      if (!mounted || action == null || !provider.matchesSession(session)) {
        return;
      }
      final entry = _entry(provider, key);
      if (entry == null) return;
      await _act(action, entry, catalogPlace, provider, session);
    } finally {
      _detailsOpen = false;
    }
  }

  Future<void> _act(
    _LocationAction action,
    _MapLocation entry,
    Place? catalogPlace,
    SavedLocationsProvider provider,
    int session,
  ) async {
    final reference = entry.reference;
    final id = reference.referenceId;
    switch (action) {
      case _LocationAction.edit:
        final result = await provider.get(id);
        if (!mounted || !provider.matchesSession(session)) return;
        await result.fold<Future<void>>(
          (failure) async {
            if (failure.statusCode == 404) unawaited(provider.refresh());
            AppErrorFeedback.report(failure, kind: AppErrorKind.load);
          },
          (saved) async {
            await Get.to(() => AddEditLocationPage(existing: saved));
          },
        );
      case _LocationAction.delete:
        await _delete(entry, provider, session);
      case _LocationAction.setDefault:
        if (!await provider.setDefault(reference.source, id)) {
          _reportWriteFailure(provider, session);
        }
      case _LocationAction.use:
        if (provider.useAsStartingLocation(reference.source, id)) {
          widget.controller.focusSelection(_point(reference));
          AppSnackBar.show(context.l10n.startingLocationUsed);
        }
      case _LocationAction.placeDetails:
        if (entry.placeId case final placeId?) {
          await Get.to(() => DiscoverPlaceDetailsPage(placeId: placeId));
        }
      case _LocationAction.selectPlace:
        if (catalogPlace != null) {
          widget.onCatalogPlaceSelected?.call(catalogPlace);
        }
    }
  }

  Future<void> _delete(
    _MapLocation entry,
    SavedLocationsProvider provider,
    int session,
  ) async {
    final l = context.l10n;
    final personal = entry.personal;
    final label = personal == null ? l.unsavePlace : l.savedLocationDelete;
    final confirmed = await AppAlert.confirm(
      title: label,
      message: personal == null
          ? l.startingRemoveSavedPlacePrompt
          : l.savedLocationDeletePrompt,
      confirmText: label,
      cancelText: l.cancel,
      destructive: true,
    );
    if (!mounted || !confirmed || !provider.matchesSession(session)) return;
    if (personal != null) {
      if (!await provider.delete(personal.id)) {
        _reportWriteFailure(provider, session);
      }
    } else {
      final removed = await context.read<DiscoverProvider>().removeSavedPlace(
        entry.reference.referenceId,
      );
      if (!removed && mounted && provider.matchesSession(session)) {
        AppSnackBar.showError(l.dataSendFailed);
        unawaited(provider.refresh());
      }
    }
  }

  void _reportWriteFailure(SavedLocationsProvider provider, int session) {
    if (!mounted || !provider.matchesSession(session)) return;
    if (provider.writeFailure case final failure?) {
      AppErrorFeedback.report(failure, kind: AppErrorKind.send);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedLocationsProvider?>();
    final session = provider?.session;
    if (!identical(provider, _provider) || _requestedSession != session) {
      _provider = provider;
      _requestedSession = session;
      _visible = true;
      if (provider != null && session != null && provider.hasAccount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(provider, _provider) &&
              provider.matchesSession(session)) {
            unawaited(provider.refresh());
          }
        });
      }
    }
    final enabled = provider != null && provider.hasAccount;
    final markers = enabled && _visible
        ? _entries(provider)
              .map((entry) => entry.marker)
              .toList(growable: false)
        : const <PersonalMapMarker>[];
    return Stack(
      fit: StackFit.expand,
      children: [
        // Drop the native surface when its owner changes so a queued style
        // operation cannot leave the previous owner's source on screen.
        KeyedSubtree(
          key: ValueKey((provider, session)),
          child: widget.builder(context, markers, _openDetails),
        ),
        if (enabled && widget.showToggle)
          Align(
            alignment: widget.toggleAlignment,
            child: Padding(
              padding: widget.togglePadding,
              child: FilterChip(
                avatar: const Icon(Icons.bookmark_outline, size: 18),
                label: Text(context.l10n.myLocations),
                showCheckmark: false,
                selected: _visible,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (visible) {
                  setState(() => _visible = visible);
                  if (visible) unawaited(provider.refresh());
                },
              ),
            ),
          ),
      ],
    );
  }
}

LatLng _point(DefaultStartingLocation location) =>
    LatLng(location.latitude, location.longitude);

class _MapLocation {
  const _MapLocation(this.reference, {this.personal, required this.isDefault});

  final DefaultStartingLocation reference;
  final SavedLocation? personal;
  final bool isDefault;

  String get key => '${reference.source.name}:${reference.referenceId}';
  String? get placeId =>
      personal == null ? reference.referenceId : personal!.placeId;
  IconData get icon => personal?.type.icon ?? Icons.place_outlined;
  bool represents(DefaultStartingLocation? location) {
    if (location == null) return false;
    return location.matches(reference.source, reference.referenceId) ||
        (isDefault &&
            location.source == StartingLocationSource.savedPlace &&
            location.referenceId == placeId &&
            PersonalLocationMapLayer.overlaps(
              _point(location),
              _point(reference),
            ));
  }

  PersonalMapMarker get marker => (
    key: key,
    point: _point(reference),
    icon: icon,
    isDefault: isDefault,
    catalogPlaceId: placeId,
  );
}

enum _LocationAction {
  edit,
  delete,
  setDefault,
  use,
  placeDetails,
  selectPlace,
}

class _PersonalLocationDetails extends StatelessWidget {
  const _PersonalLocationDetails({
    required this.entry,
    required this.isStarting,
    required this.isSaving,
    required this.canSelectPlace,
  });

  final _MapLocation entry;
  final bool isStarting, isSaving, canSelectPlace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final personal = entry.personal;
    void close(_LocationAction action) => Navigator.of(context).pop(action);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(entry.icon, color: context.palette.brandStrong),
          title: Text(entry.reference.name),
          subtitle: Text(
            [
              personal?.type.label(l) ?? l.startingSavedPlace,
              ?entry.reference.approximateArea,
              entry.isDefault
                  ? l.startingDefaultIndicator
                  : l.startingNotDefault,
              if (isStarting) l.startingLocationInUse,
            ].join(' · '),
          ),
        ),
        FilledButton.icon(
          onPressed: () => close(_LocationAction.use),
          icon: const Icon(Icons.trip_origin),
          label: Text(l.startingUseLocation),
        ),
        if (personal != null)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.savedLocationEdit),
            onTap: isSaving ? null : () => close(_LocationAction.edit),
          ),
        ListTile(
          leading: const Icon(Icons.star_outline),
          title: Text(l.startingSetDefault),
          enabled: !isSaving && !entry.isDefault,
          onTap: isSaving || entry.isDefault
              ? null
              : () => close(_LocationAction.setDefault),
        ),
        if (entry.placeId != null)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.discoverPlaceDetails),
            onTap: () => close(_LocationAction.placeDetails),
          ),
        if (canSelectPlace)
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: Text(l.chooseLocation),
            onTap: () => close(_LocationAction.selectPlace),
          ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(personal == null ? l.unsavePlace : l.savedLocationDelete),
          onTap: isSaving ? null : () => close(_LocationAction.delete),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/pages/add_edit_location_page.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/providers/saved_locations_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/widgets/location_source_selector.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_selector.dart';

import '../../domain/entities/effective_starting_location.dart';
import '../../domain/repositories/starting_location_repository.dart';
import '../providers/starting_location_provider.dart';
import 'effective_starting_location_card.dart';
import 'starting_location_pickers.dart';

class StartingLocationEditor extends StatelessWidget {
  const StartingLocationEditor({
    super.key,
    required this.scope,
    this.inputVersion,
    this.onChanged,
    this.actionOnly = false,
  });

  final StartingLocationScope scope;
  final int? inputVersion;
  final Future<void> Function()? onChanged;
  final bool actionOnly;

  @override
  Widget build(BuildContext context) {
    final account = context.select(
      (AuthProvider auth) => auth.isAuthenticated ? auth.user?.id : null,
    );
    final generation = context.select((SavedLocationsProvider p) => p.session);
    if (account == null) return const SizedBox.shrink();
    return _AccountEditor(
      key: ValueKey((account, generation, scope)),
      account: account,
      generation: generation,
      scope: scope,
      inputVersion: inputVersion,
      onChanged: onChanged,
      actionOnly: actionOnly,
    );
  }
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({
    super.key,
    required this.account,
    required this.generation,
    required this.scope,
    this.inputVersion,
    this.onChanged,
    required this.actionOnly,
  });

  final String account;
  final int generation;
  final StartingLocationScope scope;
  final int? inputVersion;
  final Future<void> Function()? onChanged;
  final bool actionOnly;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor>
    with WidgetsBindingObserver {
  late final StartingLocationProvider _location;
  late final AppSyncProvider _sync;
  late SyncStatus _status;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final saved = context.read<SavedLocationsProvider>();
    final account = widget.account;
    final generation = widget.generation;
    _location = StartingLocationProvider(
      context.read<StartingLocationRepository>(),
      account,
      widget.scope,
      () =>
          auth.isAuthenticated &&
          auth.user?.id == account &&
          saved.matchesSession(generation),
    );
    _sync = context.read<AppSyncProvider>()..addListener(_syncChanged);
    _status = _sync.status;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_location.reload());
    });
  }

  @override
  void didUpdateWidget(covariant _AccountEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inputVersion != oldWidget.inputVersion &&
        widget.inputVersion != _location.value?.inputVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_location.reload());
      });
    }
  }

  void _syncChanged() {
    final old = _status;
    _status = _sync.status;
    if ((old == SyncStatus.offline || old == SyncStatus.reconnecting) &&
        _status == SyncStatus.idle &&
        ModalRoute.isCurrentOf(context) == true) {
      unawaited(_location.reload());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.isCurrentOf(context) == true) {
      unawaited(_location.reload());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync.removeListener(_syncChanged);
    _location.dispose();
    super.dispose();
  }

  Future<bool> _save(StartingLocationOverride override, String? consent) async {
    final saved =
        override.source == OverrideLocationSource.defaultLocation &&
            override.transportation == null &&
            consent == null
        ? await _location.reset()
        : await _location.save(override, consent);
    if (mounted && saved && _location.active) await widget.onChanged?.call();
    return saved;
  }

  Future<void> _reset() async {
    if (await _location.reset() && mounted && _location.active) {
      await widget.onChanged?.call();
    }
  }

  Future<void> _edit(EffectiveStartingLocation value) =>
      AppBottomSheet.show<void>(
        context: context,
        builder: (context) {
          final account = context.select(
            (AuthProvider auth) => auth.isAuthenticated ? auth.user?.id : null,
          );
          final generation = context.select(
            (SavedLocationsProvider p) => p.session,
          );
          if (!mounted ||
              account != widget.account ||
              generation != widget.generation) {
            return Text(context.l10n.errorSessionExpired);
          }
          return ListenableBuilder(
            listenable: _location,
            builder: (context, _) => _EditStartingLocation(
              initial: value,
              location: _location,
              onSave: _save,
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _location,
    builder: (context, _) {
      final l = context.l10n;
      final value = _location.value;
      final failure = _location.failure;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value != null &&
              widget.actionOnly &&
              value.status != EffectiveLocationStatus.excluded)
            TextButton.icon(
              onPressed: _location.loading ? null : () => _edit(value),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(l.routePreviewChangeStart),
            ),
          if (value != null && !widget.actionOnly)
            EffectiveStartingLocationCard(
              value: value,
              onEdit: _location.loading ? null : () => _edit(value),
              onReset: _location.loading ? null : _reset,
            ),
          if (_location.loading)
            LinearProgressIndicator(semanticsLabel: l.meetupStartingPoint),
          if (failure != null)
            ListTile(
              title: Text(FailureMessageMapper.localize(failure, l)),
              trailing: TextButton(
                onPressed: _location.reload,
                child: Text(l.retry),
              ),
            ),
        ],
      );
    },
  );
}

class _EditStartingLocation extends StatefulWidget {
  const _EditStartingLocation({
    required this.initial,
    required this.location,
    required this.onSave,
  });

  final EffectiveStartingLocation initial;
  final StartingLocationProvider location;
  final Future<bool> Function(StartingLocationOverride, String?) onSave;

  @override
  State<_EditStartingLocation> createState() => _EditStartingLocationState();
}

class _EditStartingLocationState extends State<_EditStartingLocation> {
  late OverrideLocationSource _source;
  String? _reference;
  String? _label;
  LatLng? _point;
  TransportationMode? _mode;
  LocationSelectionMethod? _picker;
  MapLocationIssue? _issue;
  bool _selecting = false;
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final previous = widget.initial.override;
    _source = previous?.source ?? OverrideLocationSource.defaultLocation;
    _reference = previous?.referenceId;
    _label = widget.initial.temporaryLocation ? widget.initial.name : null;
    _point = previous?.point;
    _mode = previous?.transportation;
  }

  void _setSource(
    OverrideLocationSource source, {
    String? id,
    String? label,
    LatLng? point,
  }) {
    setState(() {
      _source = source;
      _reference = id;
      _label = label;
      _point = point;
      _consent = false;
      _error = null;
      _issue = null;
      _selecting = false;
      _picker = null;
    });
  }

  Future<void> _pick(LocationSelectionMethod method) async {
    if (_busy || !widget.location.active) return;
    if (method == LocationSelectionMethod.personal ||
        method == LocationSelectionMethod.bookmark) {
      setState(() => _picker = method);
      if (method == LocationSelectionMethod.personal) {
        await context.read<SavedLocationsProvider>().refresh();
      } else {
        await context.read<DiscoverProvider>().loadSavedPlaces(force: true);
      }
      return;
    }
    setState(() {
      _busy = true;
      _picker = null;
      _issue = null;
    });
    final result = method == LocationSelectionMethod.gps
        ? await GPSLocationPicker.pick()
        : (
            point: await MapLocationPicker.pick(
              context,
              initial: _point ?? widget.initial.point,
            ),
            issue: null,
          );
    if (!mounted || !widget.location.active) return;
    setState(() {
      _busy = false;
      _issue = result.issue;
    });
    if (result.point case final point?) {
      _setSource(OverrideLocationSource.point, point: point);
    }
  }

  Future<void> _savePoint() async {
    if (!widget.location.active) return;
    final point = _point;
    if (point == null) return;
    final session = context.read<SavedLocationsProvider>().session;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddEditLocationPage(initialPoint: point, expectedSession: session),
      ),
    );
  }

  Future<void> _save() async {
    if (!widget.location.active || widget.location.value == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.onSave(
      StartingLocationOverride(
        source: _source,
        referenceId: _reference,
        point: _point,
        transportation: _mode,
      ),
      _consent ? widget.location.value?.consentPolicyVersion : null,
    );
    if (!mounted || !widget.location.active) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    final failure = widget.location.failure;
    final message = failure == null
        ? context.l10n.dataSendFailed
        : FailureMessageMapper.localize(failure, context.l10n);
    if (const {403, 404, 409}.contains(failure?.statusCode)) {
      await widget.location.reload();
    }
    if (!mounted || !widget.location.active) return;
    setState(() {
      _busy = false;
      _consent = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final needsConsent = _source != OverrideLocationSource.defaultLocation;
    final status = widget.location.value?.status;
    final contextAvailable =
        status != null && status != EffectiveLocationStatus.excluded;
    final selectedSource = switch (_source) {
      OverrideLocationSource.defaultLocation => l.defaultStartingLocation,
      OverrideLocationSource.personal => _label ?? l.myLocations,
      OverrideLocationSource.savedPlace => _label ?? l.startingSavedPlace,
      OverrideLocationSource.point => l.startingPointSelected,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Text(l.startingEdit, style: context.texts.titleLarge),
        if (_selecting) ...[
          StartingLocationSourceSelector(
            enabled: !_busy,
            onDefault: () => _setSource(OverrideLocationSource.defaultLocation),
            onSelect: _pick,
          ),
          if (_picker == LocationSelectionMethod.personal)
            SavedLocationPicker(
              onSelect: (id, label) => _setSource(
                OverrideLocationSource.personal,
                id: id,
                label: label,
              ),
            ),
          if (_picker == LocationSelectionMethod.bookmark)
            SavedPlacePicker(
              onSelect: (id, label) => _setSource(
                OverrideLocationSource.savedPlace,
                id: id,
                label: label,
              ),
            ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(selectedSource),
            subtitle: Text(l.startingChangeSource),
            onTap: _busy ? null : () => setState(() => _selecting = true),
          ),
          if (_point != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _busy ? null : _savePoint,
                child: Text(l.startingSaveInMyLocations),
              ),
            ),
          Text(l.transportationLocation, style: context.texts.titleSmall),
          Text(l.startingTransportationFallback),
          TransportationModeSelector(
            value: _mode,
            onChanged: _busy ? null : (mode) => setState(() => _mode = mode),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            title: Text(
              needsConsent
                  ? l.startingContextConsent
                  : l.startingDefaultContextConsent,
            ),
            onChanged: _busy
                ? null
                : (value) => setState(() => _consent = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CustomButton(
            label: l.saveChanges,
            isLoading: _busy,
            onPressed: _busy || !contextAvailable || (needsConsent && !_consent)
                ? null
                : _save,
          ),
        ],
        if (_issue case final issue?)
          Semantics(
            liveRegion: true,
            child: Text(switch (issue) {
              MapLocationIssue.disabled => l.locationDisabled,
              MapLocationIssue.denied ||
              MapLocationIssue.deniedForever => l.locationPermissionDenied,
              MapLocationIssue.unavailable => l.couldNotGetLocation,
            }),
          ),
        if (_error case final error?)
          Semantics(liveRegion: true, child: Text(error)),
      ],
    );
  }
}

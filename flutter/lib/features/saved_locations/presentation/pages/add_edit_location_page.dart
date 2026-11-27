import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_selector.dart';

import '../../domain/entities/default_starting_location.dart';
import '../../domain/entities/saved_location.dart';
import '../providers/saved_locations_provider.dart';
import '../widgets/location_source_selector.dart';
import '../widgets/saved_location_card.dart';
import 'saved_location_map_page.dart';

class AddEditLocationPage extends StatefulWidget {
  const AddEditLocationPage({
    super.key,
    this.existing,
    this.makeDefault = false,
    this.initialMethod,
    this.initialPoint,
    this.expectedSession,
  });

  final SavedLocation? existing;
  final bool makeDefault;
  final LocationSelectionMethod? initialMethod;
  final LatLng? initialPoint;
  final int? expectedSession;

  @override
  State<AddEditLocationPage> createState() => _AddEditLocationPageState();
}

class _AddEditLocationPageState extends State<AddEditLocationPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _address;
  late final int _session;
  late SavedLocationType _type;
  TransportationMode? _transportation;
  bool _transportationChanged = false;
  LatLng? _point;
  String? _placeId;
  String? _savedId;
  MapLocationIssue? _locationIssue;
  bool _choosing = false;
  bool _submitting = false;
  bool _pointRequired = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _session =
        widget.expectedSession ??
        context.read<SavedLocationsProvider>().session;
    _name = TextEditingController(text: existing?.name);
    _area = TextEditingController(text: existing?.approximateArea);
    _address = TextEditingController(text: existing?.address);
    _type = existing?.type ?? SavedLocationType.custom;
    _transportation = existing?.preferredTransportationMode;
    _savedId = existing?.id;
    _placeId = existing?.placeId;
    _point = widget.initialPoint;
    if (existing != null) {
      _point = LatLng(existing.latitude, existing.longitude);
    }
    if (widget.initialMethod case final method?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _choose(method);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _choose(LocationSelectionMethod method) async {
    final provider = context.read<SavedLocationsProvider>();
    if (_choosing || _submitting || !provider.matchesSession(_session)) return;
    setState(() {
      _choosing = true;
      _locationIssue = null;
    });
    LatLng? point;
    MapLocationIssue? issue;
    if (method == LocationSelectionMethod.gps) {
      final result = await const MapLocation().locate(requestPermission: true);
      point = result.point;
      issue = result.issue;
    } else {
      point = await Get.to<LatLng>(
        () => SavedLocationMapPage(initial: _point, session: _session),
      );
    }
    if (!mounted || !provider.matchesSession(_session)) return;
    setState(() {
      _choosing = false;
      _locationIssue = issue;
      if (point != null) {
        if (_point != point) _placeId = null;
        _point = point;
        _pointRequired = false;
      }
    });
  }

  static String? _optional(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Future<void> _submit() async {
    final provider = context.read<SavedLocationsProvider>();
    if (_submitting || _choosing || !provider.matchesSession(_session)) return;
    final point = _point;
    final valid = _form.currentState?.validate() ?? false;
    if (point == null) setState(() => _pointRequired = true);
    if (point == null || !valid) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final saved = await provider.save(
        SavedLocationDraft(
          name: _name.text,
          type: _type,
          preferredTransportationMode: _transportationChanged
              ? _transportation
              : null,
          clearTransportationPreference:
              _transportationChanged && _transportation == null,
          latitude: point.latitude,
          longitude: point.longitude,
          approximateArea: _optional(_area.text),
          address: _optional(_address.text),
          placeId: _placeId,
        ),
        id: _savedId,
      );
      if (!mounted || saved == null || !provider.matchesSession(_session)) {
        return;
      }
      _savedId = saved.id;
      if (widget.makeDefault) {
        final selected = await provider.setDefault(
          StartingLocationSource.savedLocation,
          saved.id,
        );
        if (!selected || !mounted || !provider.matchesSession(_session)) return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = context.watch<SavedLocationsProvider>();
    final issue = _locationIssue;
    final busy = _submitting || _choosing || provider.isSaving;
    final offline =
        provider.readFailure is NetworkFailure ||
        provider.writeFailure is NetworkFailure;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? l.savedLocationAdd : l.savedLocationEdit,
        ),
      ),
      body: SafeArea(
        child: provider.matchesSession(_session)
            ? ListView(
                padding: Responsive.pagePadding(),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: Responsive.contentMaxWidth,
                      ),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (offline)
                              const AppOfflineIndicator(isOffline: true),
                            TextFormField(
                              controller: _name,
                              enabled: !busy,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 100,
                              decoration: InputDecoration(
                                labelText: l.savedLocationName,
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? l.requiredField
                                  : null,
                            ),
                            DropdownButtonFormField<SavedLocationType>(
                              initialValue: _type,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: l.savedLocationType,
                              ),
                              items: [
                                for (final type in SavedLocationType.values)
                                  DropdownMenuItem(
                                    value: type,
                                    child: Text(type.label(l)),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (type) {
                                      if (type != null) {
                                        setState(() => _type = type);
                                      }
                                    },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _area,
                              enabled: !busy,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 100,
                              decoration: InputDecoration(
                                labelText: l.savedLocationArea,
                              ),
                            ),
                            TextFormField(
                              controller: _address,
                              enabled: !busy,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: 1000,
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: l.savedLocationAddress,
                              ),
                            ),
                            if (_point != null)
                              ListTile(
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(l.startingPointSelected),
                              ),
                            LocationSourceSelector(
                              enabled: !busy,
                              sources: const [
                                LocationSelectionMethod.gps,
                                LocationSelectionMethod.map,
                              ],
                              onSelect: _choose,
                            ),
                            if (_choosing)
                              const Center(child: CircularProgressIndicator()),
                            if (issue != null || _pointRequired)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  switch (issue) {
                                    MapLocationIssue.disabled =>
                                      l.locationDisabled,
                                    MapLocationIssue.denied ||
                                    MapLocationIssue.deniedForever =>
                                      l.locationPermissionDenied,
                                    MapLocationIssue.unavailable =>
                                      l.couldNotGetLocation,
                                    null => l.startingPointRequired,
                                  },
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              l.transportationLocation,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(l.transportationLocationHint),
                            TransportationModeSelector(
                              value: _transportation,
                              onChanged: busy
                                  ? null
                                  : (mode) => setState(() {
                                      _transportation = mode;
                                      _transportationChanged = true;
                                    }),
                            ),
                            if (provider.writeFailure case final failure?)
                              if (failure is! NetworkFailure)
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    FailureMessageMapper.localize(failure, l),
                                  ),
                                ),
                            if (widget.makeDefault &&
                                _savedId != null &&
                                provider.writeFailure != null)
                              Text(l.startingSavedButDefaultFailed),
                            const SizedBox(height: 16),
                            CustomButton(
                              label: widget.makeDefault
                                  ? l.startingSaveAsDefault
                                  : l.savedLocationSave,
                              isLoading: _submitting,
                              onPressed: busy ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : AppEmptyState(message: l.dataLoadFailed),
      ),
    );
  }
}

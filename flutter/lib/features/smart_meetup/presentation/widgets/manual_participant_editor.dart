import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_selector.dart';

import '../../domain/entities/standalone_participant.dart';
import '../providers/smart_meetup_provider.dart';
import 'participant_location_picker.dart';

abstract final class AddParticipantBottomSheet {
  static Future<void> show(
    BuildContext context,
    SmartMeetupProvider meetup, {
    StandaloneParticipant? participant,
  }) => AppBottomSheet.show<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: meetup,
      builder: (context, _) {
        final session = meetup.session;
        final failure = meetup.failure;
        if (session == null ||
            !session.canManage ||
            !session.expiresAt.isAfter(DateTime.now())) {
          return Text(
            failure == null
                ? context.l10n.meetupExpired
                : FailureMessageMapper.localize(failure, context.l10n),
          );
        }
        return ManualParticipantEditor(
          meetup: meetup,
          participant: participant,
        );
      },
    ),
  );
}

class ManualParticipantEditor extends StatefulWidget {
  const ManualParticipantEditor({
    super.key,
    required this.meetup,
    this.participant,
  });

  final SmartMeetupProvider meetup;
  final StandaloneParticipant? participant;

  @override
  State<ManualParticipantEditor> createState() =>
      _ManualParticipantEditorState();
}

class _ManualParticipantEditorState extends State<ManualParticipantEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  Place? _point;
  String? _area;
  TransportationMode? _mode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final participant = widget.participant;
    _name = TextEditingController(text: participant?.displayName);
    _mode = participant?.transportation;
    _area = participant?.approximateArea;
    if (participant != null) {
      _point = Place(
        name: _area ?? '',
        area: '',
        latitude: participant.latitude,
        longitude: participant.longitude,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    FocusScope.of(context).unfocus();
    final selected = await ParticipantLocationPicker.show(
      context,
      meetup: widget.meetup,
      initial: _point?.copyWith(
        name: _area ?? context.l10n.meetupApproximatePoint,
      ),
    );
    if (!mounted || selected == null || !selected.hasCoordinates) return;
    // Catalog names identify public places. Geocoder addresses stay in the picker.
    final initial = _point;
    final language = context.l10n.locale.languageCode;
    final label = selected.id.isNotEmpty
        ? _landmarkLabel(selected.displayName(language))
        : initial?.latitude == selected.latitude &&
              initial?.longitude == selected.longitude
        ? _area
        : null;
    setState(() {
      _point = Place(
        name: label ?? '',
        area: '',
        latitude: selected.latitude,
        longitude: selected.longitude,
      );
      _area = label;
      _error = null;
    });
  }

  String? _landmarkLabel(String raw) {
    final cleaned = raw
        .replaceAll(
          RegExp(r'[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]'),
          '',
        )
        .trim();
    return cleaned.isEmpty
        ? null
        : String.fromCharCodes(cleaned.runes.take(96)).trim();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final point = _point;
    if (point == null || !point.hasCoordinates) return;
    final name = _name.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.meetup.saveParticipant(
      ManualParticipantDraft(
        displayName: name.isEmpty ? null : name,
        approximateArea: _area,
        latitude: point.latitude!,
        longitude: point.longitude!,
        transportation: _mode,
      ),
      participantId: widget.participant?.id,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    final failure = widget.meetup.failure;
    setState(() {
      _saving = false;
      _error = failure == null
          ? context.l10n.dataSendFailed
          : FailureMessageMapper.localize(failure, context.l10n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !_saving && !widget.meetup.loading;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text(
            widget.participant == null
                ? l10n.meetupAddGuest
                : l10n.meetupEditGuest,
            style: context.texts.titleLarge,
          ),
          TextFormField(
            controller: _name,
            enabled: enabled,
            decoration: InputDecoration(labelText: l10n.meetupGuestName),
            validator: (value) => (value?.trim().runes.length ?? 0) > 60
                ? l10n.meetupGuestNameTooLong
                : null,
            textCapitalization: TextCapitalization.words,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.meetupStartingPoint),
            subtitle: Text(
              _point == null
                  ? l10n.meetupPickPoint
                  : _area ?? l10n.meetupApproximatePoint,
            ),
            trailing: const Icon(Icons.map_outlined),
            onTap: enabled ? _pick : null,
          ),
          Text(l10n.transportationLocation, style: context.texts.titleSmall),
          TransportationModeSelector(
            value: _mode,
            onChanged: enabled ? (mode) => setState(() => _mode = mode) : null,
          ),
          if (_error case final error?)
            Semantics(liveRegion: true, child: Text(error)),
          CustomButton(
            label: l10n.saveChanges,
            isLoading: _saving,
            onPressed: enabled && _point?.hasCoordinates == true ? _save : null,
          ),
        ],
      ),
    );
  }
}

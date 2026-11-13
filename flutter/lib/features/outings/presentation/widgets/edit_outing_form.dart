import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/pick_location_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';

class EditOutingForm extends StatefulWidget {
  const EditOutingForm({super.key, required this.outing, required this.onSave});
  final Outing outing;
  final Future<bool> Function(Map<String, dynamic>) onSave;
  @override
  State<EditOutingForm> createState() => _EditOutingFormState();
}

class _EditOutingFormState extends State<EditOutingForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.outing.title);
  late DateTime? _scheduled = widget.outing.scheduledAt?.toLocal();
  bool _saving = false;
  late String _image = widget.outing.image;
  late PlaceLocation? _location = widget.outing.location;
  bool _locationChanged = false;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _key,
      child: ListView(
        padding: Responsive.pagePadding(),
        children: [
          PlanningCoverPicker(
            url: _image,
            art: widget.outing.occasion.coverArt,
            optionalLabel: l10n.outingPhotoOptional,
            onTap: () async {
              if (_saving) return;
              final path = await ImageSourceSheet.pick(title: l10n.uploadPhoto);
              if (path != null && mounted) setState(() => _image = path);
            },
          ),
          Responsive.spaceMd.gapH,
          CustomTextField(
            controller: _title,
            label: l10n.outingName,
            validator: (value) =>
                (value?.trim().length ?? 0) < 3 ||
                    (value?.trim().length ?? 0) > 20
                ? l10n.outingName
                : null,
          ),
          Responsive.spaceMd.gapH,
          ListTile(
            title: Text(
              _scheduled == null
                  ? l10n.outingSchedule
                  : MaterialLocalizations.of(context)
                        .formatFullDate(_scheduled!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _saving
                ? null
                : () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          _scheduled != null && _scheduled!.isAfter(now)
                          ? _scheduled!
                          : now,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _scheduled == null
                          ? TimeOfDay.now()
                          : TimeOfDay.fromDateTime(_scheduled!),
                    );
                    if (time != null && mounted) {
                      setState(
                        () => _scheduled = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
          ),
          if (_scheduled != null)
            Text(
              MaterialLocalizations.of(context)
                  .formatTimeOfDay(TimeOfDay.fromDateTime(_scheduled!)),
            ),
          if (widget.outing.status == OutingStatus.draft)
            ListTile(
              title: Text(_location?.label ?? l10n.continueToLocation),
              trailing: const Icon(Icons.place_outlined),
              onTap: _saving
                  ? null
                  : () async {
                      final selected = await Get.to<List<Place>>(
                        () => PickLocationPage(
                          catalog: context.read<OutingsProvider>().places,
                        ),
                      );
                      if (mounted && selected != null && selected.isNotEmpty) {
                        setState(() {
                          _location = selected.first.toLocation();
                          _locationChanged = true;
                        });
                      }
                    },
            ),
          Responsive.spaceLg.gapH,
          CustomButton(
            label: l10n.saveChanges,
            isLoading: _saving,
            onPressed: _saving
                ? null
                : () async {
                    if (!_key.currentState!.validate()) return;
                    setState(() => _saving = true);
                    await widget.onSave({
                      'title': _title.text.trim(),
                      if (_image != widget.outing.image) 'image_url': _image,
                      if (_locationChanged && _location != null) ...{
                        'location_name': _location!.name,
                        'location_place_id': _location!.placeId,
                        'location_area': _location!.area,
                        'location_latitude': _location!.latitude,
                        'location_longitude': _location!.longitude,
                      },
                      if (_scheduled != widget.outing.scheduledAt?.toLocal())
                        'scheduled_at': _scheduled?.toUtc().toIso8601String(),
                    });
                    if (mounted) setState(() => _saving = false);
                  },
          ),
        ],
      ),
    );
  }
}

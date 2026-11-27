import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_chip.dart';

import '../../domain/entities/effective_starting_location.dart';

class EffectiveStartingLocationCard extends StatelessWidget {
  const EffectiveStartingLocationCard({
    super.key,
    required this.value,
    required this.onEdit,
    required this.onReset,
  });

  final EffectiveStartingLocation value;
  final VoidCallback? onEdit;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = l.locale.languageCode == 'ar'
        ? value.arabicName ?? value.name
        : value.name;
    final point = value.point;
    final mode = TransportationModeChip.label(l, value.transportation);
    final transport = value.temporaryTransportation
        ? '$mode · ${l.startingTemporary}'
        : mode;
    final location = switch (value.status) {
      EffectiveLocationStatus.ready => [
        name ?? l.startingPointSelected,
        value.temporaryLocation
            ? l.startingTemporary
            : l.startingDefaultIndicator,
      ].join(' · '),
      EffectiveLocationStatus.consentRequired =>
        l.startingContextConsentRequired,
      EffectiveLocationStatus.excluded => l.startingContextExcluded,
      EffectiveLocationStatus.missing => l.startingLocationSetupRequired,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(l.meetupStartingPoint, style: context.texts.titleMedium),
            Text(location),
            if (name == null && point != null)
              Text(
                l.digits(
                  '${point.latitude.toStringAsFixed(5)}°, '
                  '${point.longitude.toStringAsFixed(5)}°',
                ),
                textDirection: TextDirection.ltr,
              ),
            Text('${l.transportationTitle} · $transport'),
            if (onEdit != null || value.override != null)
              Wrap(
                spacing: 8,
                children: [
                  if (value.status != EffectiveLocationStatus.excluded)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l.startingEdit),
                    ),
                  if (value.override != null)
                    ResetToDefaultAction(onPressed: onReset),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ResetToDefaultAction extends StatelessWidget {
  const ResetToDefaultAction({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onPressed, child: Text(context.l10n.startingReset));
}

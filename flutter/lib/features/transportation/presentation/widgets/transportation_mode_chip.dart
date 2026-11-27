import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/transportation_preference.dart';

class TransportationModeChip extends StatelessWidget {
  const TransportationModeChip({
    super.key,
    required this.mode,
    this.selected = false,
    this.onSelected,
  });

  final TransportationMode? mode;
  final bool selected;
  final VoidCallback? onSelected;

  static IconData _icon(TransportationMode? mode) => switch (mode) {
    TransportationMode.car => Icons.directions_car_outlined,
    TransportationMode.motorcycle => Icons.two_wheeler_outlined,
    TransportationMode.metro => Icons.subway_outlined,
    TransportationMode.walking => Icons.directions_walk_outlined,
    null => Icons.remove_circle_outline,
  };

  static String label(L10n l10n, TransportationMode? mode) => switch (mode) {
    TransportationMode.car => l10n.transportationCar,
    TransportationMode.motorcycle => l10n.transportationMotorcycle,
    TransportationMode.metro => l10n.transportationMetro,
    TransportationMode.walking => l10n.transportationWalking,
    null => l10n.transportationNoPreference,
  };

  @override
  Widget build(BuildContext context) => ChoiceChip(
    avatar: Icon(_icon(mode), size: 18),
    label: Text(label(context.l10n, mode)),
    selected: selected,
    onSelected: onSelected == null ? null : (_) => onSelected!(),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

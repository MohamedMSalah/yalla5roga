import 'package:flutter/material.dart';

import '../../domain/entities/transportation_preference.dart';
import 'transportation_mode_chip.dart';

class TransportationModeSelector extends StatelessWidget {
  const TransportationModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.modes = TransportationMode.values,
    this.allowNoPreference = true,
  });

  final TransportationMode? value;
  final ValueChanged<TransportationMode?>? onChanged;
  final Iterable<TransportationMode> modes;
  final bool allowNoPreference;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final mode in [...modes, if (allowNoPreference) null])
        TransportationModeChip(
          mode: mode,
          selected: value == mode,
          onSelected: onChanged == null ? null : () => onChanged!(mode),
        ),
    ],
  );
}

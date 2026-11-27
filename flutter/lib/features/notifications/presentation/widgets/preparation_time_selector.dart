import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class PreparationTimeSelector extends StatelessWidget {
  const PreparationTimeSelector({
    super.key,
    required this.minutes,
    required this.onChanged,
  });

  final int minutes;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.departurePreparationTime,
        style: context.texts.titleMedium,
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final value in const [0, 5, 10, 15, 30])
            ChoiceChip(
              label: Text(context.l10n.departureMinutes(value)),
              selected: minutes == value,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: onChanged == null
                  ? null
                  : (selected) {
                      if (selected) onChanged!(value);
                    },
            ),
        ],
      ),
    ],
  );
}

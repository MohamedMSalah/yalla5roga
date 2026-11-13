import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) Responsive.spaceSm.gapW,
          ChoiceChip(
            label: Text(labels[i]),
            selected: i == index,
            showCheckmark: false,
            labelStyle: context.texts.labelLarge?.copyWith(
              color: i == index
                  ? context.palette.brandStrong
                  : context.palette.textSecondary,
            ),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onChanged(i),
          ),
        ],
      ],
    ),
  );
}

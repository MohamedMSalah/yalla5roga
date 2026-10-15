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
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) Responsive.spaceSm.gapW,
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: Responsive.padding(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: i == index ? palette.chipActive : palette.surface,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: i == index ? palette.chipActive : palette.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: i == index ? palette.chipActiveText : palette.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

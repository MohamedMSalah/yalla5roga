import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class VibeOption {
  const VibeOption(this.icon, this.label);

  final IconData icon;
  final String label;
}

class VibePicker extends StatelessWidget {
  const VibePicker({
    super.key,
    required this.options,
    required this.index,
    required this.onChanged,
  });

  final List<VibeOption> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = Responsive.spaceSm;
        final compact =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;
        final columns = compact && options.length > 2 ? 2 : options.length;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < options.length; i++)
              SizedBox(
                width: width,
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          options[i].icon,
                          size: 22,
                          color: palette.brandStrong,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          options[i].label,
                          textAlign: TextAlign.center,
                          style: context.texts.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  labelPadding: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: i == index ? palette.brandStrong : palette.border,
                    width: i == index ? 2 : 1,
                  ),
                  backgroundColor: palette.surface,
                  selectedColor: palette.brandSoft,
                  selected: i == index,
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) onChanged(i);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

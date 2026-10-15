import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class VibeOption {
  const VibeOption(this.emoji, this.label);

  final String emoji;
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
    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: i == index
                        ? context.palette.brandSoft
                        : context.palette.surface,
                    borderRadius: BorderRadius.circular(Responsive.radiusMd),
                    border: Border.all(
                      color: i == index
                          ? AppColors.brand500
                          : context.palette.border,
                      width: i == index ? 2.w : 1.w,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(options[i].emoji, style: TextStyle(fontSize: 18.sp)),
                      Responsive.spaceXs.gapH,
                      Text(
                        options[i].label,
                        style: TextStyle(
                          fontSize: Responsive.fontXs,
                          fontWeight: FontWeight.w800,
                          color: i == index
                              ? context.palette.brandStrong
                              : context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

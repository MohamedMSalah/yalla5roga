import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// HTML `.setting-toggle` — 44×24 track, 20×20 white thumb, brand-600 when on.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isRtl = context.isRtl;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44.w,
        height: 24.w,
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: value ? AppColors.brand600 : palette.border,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value
              ? (isRtl ? Alignment.centerLeft : Alignment.centerRight)
              : (isRtl ? Alignment.centerRight : Alignment.centerLeft),
          child: Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.slate900.withValues(alpha: 0.16),
                  blurRadius: 4.w,
                  offset: Offset(0, 1.h),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

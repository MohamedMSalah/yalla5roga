import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Established compact track with an accessible 48dp effective touch target.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    enabled: onChanged != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 48.w < 48 ? 48 : 48.w,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.reduce(context)
                ? Duration.zero
                : AppMotion.standard,
            width: 44.w,
            height: 24.w,
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: value ? AppColors.brand600 : context.palette.border,
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: AnimatedAlign(
              duration: AppMotion.reduce(context)
                  ? Duration.zero
                  : AppMotion.standard,
              curve: AppMotion.enter,
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: .16),
                      blurRadius: 4.w,
                      offset: Offset(0, 1.h),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

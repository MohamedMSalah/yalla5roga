import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/loading_indicator.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background,
    this.foreground,
    this.badge,
    this.size = 40,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final String? badge;
  final double size;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final side = size.w;
    final iconColor = foreground ?? palette.textSecondary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ?? palette.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: palette.border),
            ),
            child: isLoading
                ? LoadingIndicator(size: Responsive.iconMd * 0.7, strokeWidth: 2.2, color: iconColor)
                : Icon(icon, size: Responsive.iconMd, color: iconColor),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -4.w,
            top: -4.h,
            child: Container(
              padding: Responsive.padding(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.rose500,
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(color: palette.background, width: 2.w),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.fontXs,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

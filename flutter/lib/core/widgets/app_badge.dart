import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.amber100,
    this.textColor = AppColors.amber700,
    this.icon,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Responsive.padding(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.w, color: textColor),
            Responsive.spaceXs.gapW,
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: Responsive.fontCaption,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

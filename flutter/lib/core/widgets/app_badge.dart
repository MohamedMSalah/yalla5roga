import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
  });

  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Responsive.padding(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? context.palette.warningSoft,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.w, color: textColor ?? context.palette.warning),
            Responsive.spaceXs.gapW,
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: textColor ?? context.palette.warning,
                fontSize: Responsive.fontCaption,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

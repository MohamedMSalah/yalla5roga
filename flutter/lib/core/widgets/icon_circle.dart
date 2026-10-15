import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 20,
    this.background,
    this.foreground,
    this.radius = 14,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? context.palette.brandSoft,
        borderRadius: BorderRadius.circular(radius.r),
      ),
      child: Icon(icon, size: iconSize.w, color: foreground),
    );
  }
}

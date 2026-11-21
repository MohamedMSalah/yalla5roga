import 'package:flutter/material.dart';

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradient,
    required this.highlight,
    this.glow,
    this.iconColor = Colors.white,
    this.iconSize = 25,
    this.loading = false,
    required this.borderColor,
    required this.textStyle,
    this.radius = 19,
    this.height = 50,
    this.iconGap = 12,
    this.iconTrailing = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Gradient gradient, highlight;
  final BoxShadow? glow;
  final Color iconColor;
  final double iconSize;
  final bool loading, iconTrailing;
  final Color borderColor;
  final TextStyle? textStyle;
  final double radius, height, iconGap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final leading = loading
        ? SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
          )
        : Icon(icon, size: iconSize, color: iconColor);
    final text = Flexible(child: Text(label, style: textStyle));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: gradient,
        boxShadow: [?glow],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          gradient: highlight,
          border: Border.all(color: borderColor),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: shape,
            onTap: loading ? null : onTap,
            child: Semantics(
              button: true,
              child: Container(
                constraints: BoxConstraints(minHeight: height),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconTrailing ? text : leading,
                    SizedBox(width: iconGap),
                    iconTrailing ? leading : text,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

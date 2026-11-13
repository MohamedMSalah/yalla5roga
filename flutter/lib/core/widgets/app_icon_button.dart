import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
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
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final String? badge;
  final double size;
  final bool isLoading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final side = size.w.clamp(48.0, double.infinity);
    final iconColor = foreground ?? palette.textSecondary;
    final reduce = AppMotion.reduce(context);

    // Icon swaps (bookmark <-> bookmark_border, icon <-> spinner) pop in
    // with a tiny overshoot so a toggle reads as a confirmed action.
    final glyph = AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.standard),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        if (reduce) return child;
        // Overshoot lives on the scale only; opacity stays within 0..1.
        final pop = CurvedAnimation(parent: animation, curve: AppMotion.enter);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(pop),
            child: child,
          ),
        );
      },
      child: isLoading
          ? LoadingIndicator(
              key: const ValueKey('loading'),
              size: Responsive.iconMd * 0.7,
              strokeWidth: 2.2,
              color: iconColor,
            )
          : Icon(
              icon,
              key: ValueKey(icon),
              size: Responsive.iconMd,
              color: iconColor,
            ),
    );

    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.standard),
            curve: AppMotion.settle,
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ?? palette.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: palette.border),
            ),
            child: glyph,
          ),
        ),
        if (badge != null)
          PositionedDirectional(
            end: -4.w,
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
    return tooltip == null
        ? button
        : Tooltip(
            message: tooltip!,
            child: Semantics(label: tooltip, button: true, child: button),
          );
  }
}

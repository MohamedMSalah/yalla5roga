import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/loading_indicator.dart';

enum AppButtonVariant { filled, light, outlined, danger }

enum AppButtonSize { large, medium, small }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foregroundColor,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.large,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? foregroundColor;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;
  final bool isLoading;

  double get _height => switch (size) {
    AppButtonSize.large => Responsive.buttonHeight,
    AppButtonSize.medium => 44.h,
    AppButtonSize.small => 40.h,
  };

  double get _fontSize => switch (size) {
    AppButtonSize.large => 14.sp,
    AppButtonSize.medium => 13.sp,
    AppButtonSize.small => 12.sp,
  };

  double get _iconSize => switch (size) {
    AppButtonSize.large => 18.w,
    AppButtonSize.medium => 16.w,
    AppButtonSize.small => 14.w,
  };

  double get _radius => switch (size) {
    AppButtonSize.large => AppRadii.control.r,
    AppButtonSize.medium => AppRadii.control.r,
    AppButtonSize.small => AppRadii.small.r,
  };

  EdgeInsets get _padding => EdgeInsets.symmetric(
    horizontal: switch (size) {
      AppButtonSize.large => 20.w,
      AppButtonSize.medium => 16.w,
      AppButtonSize.small => 12.w,
    },
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final background =
        color ??
        switch (variant) {
          AppButtonVariant.filled => scheme.primary,
          AppButtonVariant.light => palette.brandSoft,
          AppButtonVariant.outlined => Colors.transparent,
          AppButtonVariant.danger => scheme.error,
        };
    final foreground =
        foregroundColor ??
        switch (variant) {
          AppButtonVariant.filled => scheme.onPrimary,
          AppButtonVariant.light => palette.brandStrong,
          AppButtonVariant.outlined => color ?? palette.brandStrong,
          AppButtonVariant.danger => scheme.onError,
        };
    // Label <-> spinner crossfade so an async press does not pop. Material
    // already tweens the enabled/disabled colours (ButtonStyle.animationDuration).
    final child = AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.press),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: isLoading
          ? LoadingIndicator(
              key: const ValueKey('loading'),
              size: _iconSize,
              strokeWidth: 2.2,
              color: foreground,
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: _iconSize), 8.gapW],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );

    final style = ButtonStyle(
      animationDuration: AppMotion.of(context, AppMotion.standard),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(
          expand ? double.infinity : AppSizes.touchTarget,
          _height.clamp(AppSizes.touchTarget, double.infinity),
        ),
      ),
      padding: WidgetStatePropertyAll(_padding),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      textStyle: WidgetStatePropertyAll(
        context.texts.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: _fontSize,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isLoading
            ? palette.surfaceMuted
            : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isLoading
            ? palette.textMuted
            : foreground,
      ),
      side: variant == AppButtonVariant.outlined
          ? WidgetStatePropertyAll(
              BorderSide(color: color ?? context.palette.border),
            )
          : null,
    );

    final button = variant == AppButtonVariant.outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: child,
          );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

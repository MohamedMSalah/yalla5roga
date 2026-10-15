import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
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
        AppButtonSize.large => 14.r,
        AppButtonSize.medium => 13.r,
        AppButtonSize.small => 12.r,
      };

  EdgeInsets get _padding => EdgeInsets.symmetric(
        horizontal: switch (size) {
          AppButtonSize.large => 20.w,
          AppButtonSize.medium => 16.w,
          AppButtonSize.small => 12.w,
        },
      );

  Color get _background {
    if (color != null && variant != AppButtonVariant.outlined) return color!;
    return switch (variant) {
      AppButtonVariant.filled => AppColors.brand600,
      AppButtonVariant.light => Colors.white,
      AppButtonVariant.outlined => Colors.transparent,
      AppButtonVariant.danger => AppColors.rose500,
    };
  }

  Color get _foreground {
    if (foregroundColor != null) return foregroundColor!;
    if (variant == AppButtonVariant.outlined) return color ?? AppColors.brand600;
    return switch (variant) {
      AppButtonVariant.filled => Colors.white,
      AppButtonVariant.light => AppColors.brand700,
      AppButtonVariant.outlined => AppColors.brand600,
      AppButtonVariant.danger => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? LoadingIndicator(size: _iconSize, strokeWidth: 2.2, color: _foreground)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _iconSize),
                8.gapW,
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final style = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : 0, _height)),
      padding: WidgetStatePropertyAll(_padding),
      tapTargetSize: expand ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
      visualDensity: expand ? VisualDensity.standard : VisualDensity.compact,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: _fontSize),
      ),
      backgroundColor: WidgetStatePropertyAll(_background),
      foregroundColor: WidgetStatePropertyAll(_foreground),
      side: variant == AppButtonVariant.outlined
          ? WidgetStatePropertyAll(BorderSide(color: color ?? context.palette.border))
          : null,
    );

    final button = variant == AppButtonVariant.outlined
        ? OutlinedButton(onPressed: isLoading ? null : onPressed, style: style, child: child)
        : ElevatedButton(onPressed: isLoading ? null : onPressed, style: style, child: child);

    if (!expand) return button;
    return SizedBox(width: double.infinity, height: _height, child: button);
  }
}

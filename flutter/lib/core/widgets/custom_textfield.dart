import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.onToggleObscure,
    this.inputFormatters,
    this.textInputAction,
    this.textDirection,
    this.maxLines = 1,
    this.minLines,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final VoidCallback? onToggleObscure;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final int? maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSm,
            fontWeight: FontWeight.w800,
            color: palette.textSecondary,
          ),
        ),
        Responsive.spaceSm.gapH,
        _maybeDirectional(
          textDirection,
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            textDirection: textDirection,
            maxLines: obscureText ? 1 : maxLines,
            minLines: obscureText ? 1 : minLines,
            style: TextStyle(
              fontSize: Responsive.fontBody,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: palette.hint,
                fontWeight: FontWeight.w500,
                fontSize: Responsive.fontBody,
              ),
              filled: true,
              fillColor: palette.inputFill,
              alignLabelWithHint: (maxLines ?? 1) > 1,
              prefixIcon:
                  prefix ??
                  (prefixIcon == null
                      ? null
                      : Icon(prefixIcon, size: 18.w, color: palette.textMuted)),
              suffixIcon: onToggleObscure == null
                  ? suffix
                  : IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18.w,
                        color: palette.textMuted,
                      ),
                    ),
              contentPadding: Responsive.padding(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Responsive.radiusMd),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Responsive.radiusMd),
                borderSide: BorderSide(color: AppColors.brand500, width: 1.4.w),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Responsive.radiusMd),
                borderSide: const BorderSide(color: AppColors.rose500),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Responsive.radiusMd),
                borderSide: const BorderSide(color: AppColors.rose500),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _maybeDirectional(TextDirection? direction, Widget child) {
    if (direction == null) return child;
    return Directionality(textDirection: direction, child: child);
  }
}

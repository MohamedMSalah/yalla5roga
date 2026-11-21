import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class OutingsStyle {
  OutingsStyle(BuildContext context)
    : dark = context.palette.isDark,
      highContrast = MediaQuery.highContrastOf(context),
      scheme = Theme.of(context).colorScheme;

  final bool dark;
  final bool highContrast;
  final ColorScheme scheme;

  static const gutter = 14.0;
  static const cardRadius = 18.0;

  Color get text => highContrast
      ? scheme.onSurface
      : dark
      ? const Color(0xFFFAF7FF)
      : const Color(0xFF291C36);
  Color get muted => highContrast
      ? scheme.onSurface
      : dark
      ? const Color(0xFFCBB9E4)
      : const Color(0xFF634D76);
  Color get accent => highContrast
      ? scheme.onSurface
      : dark
      ? const Color(0xFFDFADF8)
      : const Color(0xFF743E9D);
  Color get border => highContrast
      ? scheme.outline
      : dark
      ? const Color(0xFF3D344D)
      : const Color(0xFFE0CFEF);
  Color get pill => highContrast
      ? scheme.surface
      : dark
      ? const Color(0xFF443259)
      : const Color(0xFFEADCF8);
  Color get deadlineFill => highContrast
      ? scheme.surface
      : dark
      ? const Color(0xFF502460)
      : const Color(0xFFF4DEF6);
  Color get deadlineText => highContrast
      ? scheme.onSurface
      : dark
      ? const Color(0xFFF0ABFA)
      : const Color(0xFF7F338B);

  static const primaryGradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [Color(0xFF8C4AE2), Color(0xFF763CC5), Color(0xFF58319C)],
  );

  static const progressGradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [Color(0xFFAF72FA), Color(0xFF8449E5)],
  );

  BoxDecoration panel({
    double radius = cardRadius,
    bool raised = false,
    bool date = false,
  }) => BoxDecoration(
    color: highContrast ? scheme.surface : null,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    gradient: highContrast
        ? null
        : LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: date
                ? (dark
                      ? const [Color(0xFF45335B), Color(0xFF30253F)]
                      : const [Color(0xFFF2E5FE), Color(0xFFE7D9F3)])
                : raised
                ? (dark
                      ? const [Color(0xFF30273E), Color(0xFF241F30)]
                      : const [Color(0xFFF9F1FF), Color(0xFFEFE5F8)])
                : (dark
                      ? const [Color(0xFF282234), Color(0xFF1D1A28)]
                      : const [Color(0xFFFFFCFF), Color(0xFFF4EDF9)]),
          ),
  );

  TextStyle label(
    BuildContext context,
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => (context.texts.bodyMedium ?? const TextStyle()).copyWith(
    color: color ?? text,
    fontSize: size,
    fontWeight: weight,
    height: 1.2,
  );
}

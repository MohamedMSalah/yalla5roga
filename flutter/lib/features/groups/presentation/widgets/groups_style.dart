import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class GroupsPageBackground extends StatelessWidget {
  const GroupsPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.palette.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF110F18) : context.palette.background,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const AlignmentDirectional(.47, -.81),
            radius: .77,
            colors: dark
                ? const [Color(0xFF2C1A49), Color(0x001B112A)]
                : const [Color(0xFFE7D8FA), Color(0x00EEE3FB)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const AlignmentDirectional(-.55, -.52),
              radius: .68,
              colors: dark
                  ? const [Color(0x167F40CA), Color(0x007F40CA)]
                  : const [Color(0x139D67E0), Color(0x009D67E0)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

abstract final class GroupsStyle {
  static const cardHeight = 88.0;
  static const cardVerticalPadding = 9.0;
  static const imageSize = 70.0;
  static const cardRadius = 18.0;
  static const actionRadius = 19.0;
  static const gap = 10.0;

  static BoxDecoration panel(AppPalette palette, double radius) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: palette.isDark
              ? const Color(0xFF3A3249).withValues(alpha: .8)
              : palette.brandSoftBorder,
        ),
        gradient: palette.isDark
            ? const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF292432), Color(0xFF211D2B)],
              )
            : LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [palette.surface, const Color(0xFFF4EDF9)],
              ),
      );

  static const action = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFFAA79E6), Color(0xFF8246CB), Color(0xFF573097)],
    stops: [0, .28, 1],
  );
  static const selected = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF9254DF), Color(0xFF6430A9), Color(0xFF452570)],
  );
  static const banner = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF71318E), Color(0xFF50266F), Color(0xFF342050)],
  );

  static const shine = RadialGradient(
    center: AlignmentDirectional(-.96, -1.45),
    radius: 1.55,
    colors: [Color(0x48F6DFFF), Color(0x00F6DFFF)],
  );

  static const actionGlow = BoxShadow(
    color: Color(0x497E37D0),
    blurRadius: 12,
    spreadRadius: -4,
    offset: Offset(0, 2),
  );

  static TextStyle text(
    BuildContext context,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double height = 1.22,
  }) => (context.texts.bodyMedium ?? const TextStyle()).copyWith(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: 0,
  );
}

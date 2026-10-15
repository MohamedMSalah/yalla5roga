import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light(Locale locale) {
    return _build(
      locale: locale,
      palette: AppPalette.light,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brand600,
        onPrimary: Colors.white,
        secondary: AppColors.brand500,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.slate950,
        outline: AppColors.slate200,
        error: AppColors.rose600,
        onError: Colors.white,
      ),
    );
  }

  static ThemeData dark(Locale locale) {
    return _build(
      locale: locale,
      palette: AppPalette.dark,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brand500,
        onPrimary: Colors.white,
        secondary: AppColors.brand200,
        onSecondary: AppColors.slate950,
        surface: AppColors.slate900,
        onSurface: Color(0xFFF1F5F9),
        outline: AppColors.slate700,
        error: AppColors.rose500,
        onError: Colors.white,
      ),
    );
  }

  static ThemeData _build({
    required Locale locale,
    required AppPalette palette,
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final textTheme = locale.languageCode == 'ar'
        ? GoogleFonts.cairoTextTheme()
        : GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border,
      textTheme: textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 2,
        shadowColor: palette.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.transparent,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        actionTextColor: palette.brand,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brand600
              : AppColors.slate200;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brand600
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        hintStyle: TextStyle(color: palette.hint, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.4),
        ),
      ),
    );
  }
}

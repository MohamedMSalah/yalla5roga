import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light(Locale locale) =>
      _build(locale, AppPalette.light, Brightness.light);
  static ThemeData dark(Locale locale) =>
      _build(locale, AppPalette.dark, Brightness.dark);

  static ThemeData _build(
    Locale locale,
    AppPalette palette,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.brand,
          brightness: brightness,
        ).copyWith(
          primary: palette.brand,
          onPrimary: dark ? const Color(0xFF271144) : Colors.white,
          primaryContainer: palette.brandSoft,
          onPrimaryContainer: palette.brandStrong,
          secondary: palette.brandStrong,
          onSecondary: dark ? const Color(0xFF271144) : Colors.white,
          secondaryContainer: palette.brandSoft,
          onSecondaryContainer: palette.brandStrong,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.textMuted,
          outlineVariant: palette.border,
          error: palette.danger,
          onError: dark ? const Color(0xFF451D2C) : Colors.white,
          errorContainer: palette.dangerSoft,
          onErrorContainer: palette.danger,
          surfaceContainerLowest: palette.background,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.surfaceMuted,
          surfaceContainerHigh: palette.surfaceSoft,
          surfaceContainerHighest: palette.surfaceSoft,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final fonts = locale.languageCode == 'ar'
        ? GoogleFonts.cairoTextTheme(base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme);
    final text = fonts
        .copyWith(
          headlineLarge: fonts.headlineLarge?.copyWith(
            fontSize: AppTypography.display,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: fonts.headlineSmall?.copyWith(
            fontSize: AppTypography.heading,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: fonts.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: fonts.titleMedium?.copyWith(
            fontSize: AppTypography.title,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: fonts.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium: fonts.bodyMedium?.copyWith(
            fontSize: AppTypography.body,
            height: 1.5,
          ),
          bodySmall: fonts.bodySmall?.copyWith(
            fontSize: AppTypography.caption,
            height: 1.4,
          ),
          labelLarge: fonts.labelLarge?.copyWith(
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: fonts.labelSmall?.copyWith(
            fontSize: AppTypography.caption,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        );
    final control = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: color, width: width),
        );
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppSizes.touchTarget, AppSizes.touchTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
      shape: WidgetStatePropertyAll(control),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border,
      textTheme: text,
      iconTheme: IconThemeData(
        color: palette.textSecondary,
        size: AppSizes.icon,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.touchTarget),
          foregroundColor: palette.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: palette.background),
        actionTextColor: dark ? scheme.onPrimary : palette.brandStrong,
        behavior: SnackBarBehavior.floating,
        shape: control,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.brandSoft,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: palette.brandStrong,
        ),
        side: BorderSide(color: palette.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        hintStyle: text.bodyMedium?.copyWith(color: palette.hint),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: inputBorder(palette.border),
        enabledBorder: inputBorder(palette.border),
        focusedBorder: inputBorder(palette.brand, 2),
        errorBorder: inputBorder(palette.danger),
        focusedErrorBorder: inputBorder(palette.danger, 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.brand,
        selectionColor: palette.brand.withValues(alpha: 0.22),
        selectionHandleColor: palette.brand,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.brand),
    );
  }
}

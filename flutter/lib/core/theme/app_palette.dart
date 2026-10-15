import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';

/// Semantic colors for light (exact HTML design) and dark (HTML preview-dark).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSoft,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.hint,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.brandSoftBorder,
    required this.navBackground,
    required this.chipActive,
    required this.chipActiveText,
    required this.shadow,
    required this.inputFill,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSoft;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color hint;
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color brandSoftBorder;
  final Color navBackground;
  final Color chipActive;
  final Color chipActiveText;
  final Color shadow;
  final Color inputFill;

  /// Light palette copied from `index.html` Tailwind tokens.
  static const light = AppPalette(
    background: AppColors.slate50,
    surface: Colors.white,
    surfaceMuted: AppColors.slate100,
    surfaceSoft: Color(0xB3E2E8F0),
    border: AppColors.slate200,
    textPrimary: AppColors.slate950,
    textSecondary: AppColors.slate600,
    textMuted: AppColors.slate400,
    hint: Color(0xFFCBD5E1),
    brand: AppColors.brand600,
    brandStrong: AppColors.brand700,
    brandSoft: AppColors.brand50,
    brandSoftBorder: AppColors.brand100,
    navBackground: Color(0xF5FFFFFF),
    chipActive: AppColors.slate900,
    chipActiveText: Colors.white,
    shadow: Color(0x0F0F172A),
    inputFill: Colors.white,
  );

  /// Dark palette copied from the HTML `preview-dark` rules.
  static const dark = AppPalette(
    background: AppColors.slate950,
    surface: AppColors.slate900,
    surfaceMuted: Color(0xFF111827),
    surfaceSoft: AppColors.slate800,
    border: Color(0xFF334155),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFF1F5F9),
    textMuted: AppColors.slate400,
    hint: AppColors.slate400,
    brand: AppColors.brand500,
    brandStrong: AppColors.brand200,
    brandSoft: Color(0xFF1E1B4B),
    brandSoftBorder: Color(0xFF312E81),
    navBackground: AppColors.slate900,
    chipActive: Color(0xFFF8FAFC),
    chipActiveText: AppColors.slate950,
    shadow: Color(0x33000000),
    inputFill: AppColors.slate900,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSoft,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? hint,
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? brandSoftBorder,
    Color? navBackground,
    Color? chipActive,
    Color? chipActiveText,
    Color? shadow,
    Color? inputFill,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      hint: hint ?? this.hint,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      brandSoftBorder: brandSoftBorder ?? this.brandSoftBorder,
      navBackground: navBackground ?? this.navBackground,
      chipActive: chipActive ?? this.chipActive,
      chipActiveText: chipActiveText ?? this.chipActiveText,
      shadow: shadow ?? this.shadow,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandSoftBorder: Color.lerp(brandSoftBorder, other.brandSoftBorder, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      chipActive: Color.lerp(chipActive, other.chipActive, t)!,
      chipActiveText: Color.lerp(chipActiveText, other.chipActiveText, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

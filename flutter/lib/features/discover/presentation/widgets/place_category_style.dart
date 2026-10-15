import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

/// Consistent icon + soft colors for place categories (vibes).
extension PlaceCategoryStyle on OutingVibe {
  IconData get icon => switch (this) {
    OutingVibe.food => Icons.restaurant_outlined,
    OutingVibe.activity => Icons.sports_esports_outlined,
    OutingVibe.outdoor => Icons.park_outlined,
    OutingVibe.movie => Icons.movie_outlined,
  };

  Color get softBackground => switch (this) {
    OutingVibe.food => const Color(0xFFFFEDD5),
    OutingVibe.activity => const Color(0xFFE0E7FF),
    OutingVibe.outdoor => const Color(0xFFDCFCE7),
    OutingVibe.movie => const Color(0xFFEDE9FE),
  };

  Color get accent => switch (this) {
    OutingVibe.food => const Color(0xFFC2410C),
    OutingVibe.activity => const Color(0xFF4338CA),
    OutingVibe.outdoor => const Color(0xFF15803D),
    OutingVibe.movie => const Color(0xFF6D28D9),
  };
}

/// Shared fallback when category is unknown.
abstract final class PlaceCategoryDefaults {
  static const IconData icon = Icons.place_outlined;
  static const Color softBackground = AppColors.brand100;
  static const Color accent = AppColors.brand600;
}

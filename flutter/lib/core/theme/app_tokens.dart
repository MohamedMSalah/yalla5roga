import 'package:flutter/material.dart';

/// Logical sizes. Responsive scales these values; touch targets never shrink.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const compact = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadii {
  static const small = 10.0;
  static const control = 14.0;
  static const card = 16.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  static const touchTarget = 48.0;
  static const button = 52.0;
  static const icon = 20.0;
  static const navItem = 56.0;
}

abstract final class AppTypography {
  static const caption = 12.0;
  static const body = 14.0;
  static const title = 16.0;
  static const heading = 22.0;
  static const display = 32.0;
}

abstract final class AppShadows {
  static List<BoxShadow> card(Color color) => [
    BoxShadow(color: color, blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> floating(Color color) => [
    BoxShadow(color: color, blurRadius: 24, offset: const Offset(0, 8)),
  ];
}

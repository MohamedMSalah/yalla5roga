import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';

export 'package:yalla_5roga/core/responsive/responsive.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => theme.colorScheme;

  TextTheme get texts => theme.textTheme;

  AppPalette get palette => AppColors.of(this);

  bool get isDark => theme.brightness == Brightness.dark;

  L10n get l10n => L10n.of(this);

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  IconData get chevronForward => isRtl ? Icons.chevron_left : Icons.chevron_right;

  IconData get chevronBack => isRtl ? Icons.chevron_right : Icons.chevron_left;

  void showSnack(String message) => AppSnackBar.show(message);
}

extension StringX on String {
  String get trimmed => trim();

  bool get isBlank => trim().isEmpty;
}

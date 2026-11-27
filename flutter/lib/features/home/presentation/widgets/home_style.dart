import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Colors for the illustrated Home surfaces, derived from the active app theme.
class HomeStyle {
  HomeStyle(BuildContext context) : dark = context.palette.isDark;

  final bool dark;

  static const gutter = 16.0;
  static const sectionGap = 25.0;
  static const headerGap = 12.0;
  static const sectionTitle = 20.0;
  static const sectionIcon = 20.0;
  static const sectionAction = 13.0;
  static const userName = 22.0;
  static const greeting = 13.0;
  static const heroTitle = 20.0;
  static const heroBody = 13.0;
  static const quickActionLabel = 13.0;
  static const quickActionIcon = 26.0;

  Color get text => dark ? const Color(0xFFF8F6FC) : const Color(0xFF251933);
  Color get muted => dark ? const Color(0xFFD8CAEB) : const Color(0xFF59476C);
  Color get accent => dark ? const Color(0xFFD1AEF8) : const Color(0xFF7035A2);
  Color get border => dark ? const Color(0xFF40344F) : const Color(0xFFDCCCE9);
  Color get heroBorder =>
      dark ? const Color(0xFF75509D) : const Color(0xFFC39DE3);
  Color get heroGlow =>
      dark ? const Color(0x996D36A0) : const Color(0xAAC999ED);
  Color get heroCurve =>
      dark ? const Color(0x885F32A0) : const Color(0x66BA87E4);
  Color get statusFill =>
      dark ? const Color(0xFF432D69) : const Color(0xFFEBD9F9);
  Color get avatarRing =>
      dark ? const Color(0xFF64428A) : const Color(0xFFC499E7);

  LinearGradient get avatar => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: dark
        ? const [Color(0xFF422B64), Color(0xFF2B2146)]
        : const [Color(0xFFF1DEFD), Color(0xFFDFC9F5)],
  );

  LinearGradient get hero => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: dark
        ? const [Color(0xFF372953), Color(0xFF241D35), Color(0xFF302047)]
        : const [Color(0xFFEFE0FD), Color(0xFFF9F1FF), Color(0xFFE6D1F7)],
  );

  LinearGradient get panel => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: dark
        ? const [Color(0xFF292436), Color(0xFF211C2D)]
        : const [Color(0xFFFFFFFF), Color(0xFFF3EAF9)],
  );
}

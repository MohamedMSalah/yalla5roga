import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';

class AppColors {
  const AppColors._();

  // Brand tokens from index.html
  static const brand50 = Color(0xFFEEF2FF);
  static const brand100 = Color(0xFFE0E7FF);
  static const brand200 = Color(0xFFC7D2FE);
  static const brand500 = Color(0xFF6366F1);
  static const brand600 = Color(0xFF4F46E5);
  static const brand700 = Color(0xFF4338CA);

  // Slate tokens from index.html
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber700 = Color(0xFFB45309);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const rose50 = Color(0xFFFFF1F2);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const violet500 = Color(0xFF8B5CF6);

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? AppPalette.light;
  }
}

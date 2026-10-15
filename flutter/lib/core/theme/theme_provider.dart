import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs) {
    final stored = _prefs.getString(AppConstants.themeKey);
    _themeMode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> setDark(bool dark) {
    return setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setString(AppConstants.themeKey, mode.name);
    Get.changeThemeMode(mode);
    notifyListeners();
  }

  Future<void> toggle() => setDark(!isDark);
}

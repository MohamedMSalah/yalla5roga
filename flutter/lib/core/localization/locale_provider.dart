import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs) {
    final stored = _prefs.getString(AppConstants.localeKey);
    _locale = stored == null ? const Locale('en') : Locale(stored);
  }

  final SharedPreferences _prefs;
  late Locale _locale;

  Locale get locale => _locale;

  bool get isRtl => _locale.languageCode == 'ar';

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _prefs.setString(AppConstants.localeKey, locale.languageCode);
    Get.updateLocale(locale);
    notifyListeners();
  }

  Future<void> setArabic(bool arabic) {
    return setLocale(arabic ? const Locale('ar') : const Locale('en'));
  }

  Future<void> toggle() {
    return setLocale(
      _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en'),
    );
  }
}

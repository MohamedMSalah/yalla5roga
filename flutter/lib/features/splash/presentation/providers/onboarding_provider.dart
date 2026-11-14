import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider(this.preferences);
  static const completionKey = 'onboarding_completed';
  final SharedPreferences preferences;
  int step = 0;
  bool busy = false;
  void next() {
    if (step < 2) {
      step++;
      notifyListeners();
    }
  }

  Future<bool> complete() async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      return await preferences.setBool(completionKey, true);
    } catch (_) {
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

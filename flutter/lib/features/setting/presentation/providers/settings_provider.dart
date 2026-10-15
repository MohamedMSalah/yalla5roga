import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {
  bool _pushEnabled = true;

  bool get pushEnabled => _pushEnabled;

  void setPushEnabled(bool value) {
    if (_pushEnabled == value) return;
    _pushEnabled = value;
    notifyListeners();
  }
}

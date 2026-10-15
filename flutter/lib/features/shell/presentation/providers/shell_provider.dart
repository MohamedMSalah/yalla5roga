import 'package:flutter/foundation.dart';

class ShellProvider extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void setIndex(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }

  void openOutings() => setIndex(2);
}

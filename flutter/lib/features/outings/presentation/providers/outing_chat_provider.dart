import 'package:flutter/foundation.dart';

/// Holds chat unread badges only. Message threads are fixed UI text for now.
class OutingChatProvider extends ChangeNotifier {
  var _unread = <String, int>{};
  int _unreadChatCount = 0;

  int get unreadChatCount => _unreadChatCount;

  /// Chat no longer blocks shell bootstrap.
  bool get isInitialLoading => false;

  int unreadFor(String outingId) => _unread[outingId] ?? 0;



  void clear() {
    _unread = {};
    _unreadChatCount = 0;
    notifyListeners();
  }
}

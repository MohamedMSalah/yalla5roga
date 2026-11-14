import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notification_preferences_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({required this.repository, this.onSynchronized});

  final NotificationsRepository repository;
  final Future<void> Function(List<NotificationItem>, int, Map<String, bool>)?
  onSynchronized;
  Map<String, bool> _preferences = {};
  Map<String, bool> get preferences => Map.unmodifiable(_preferences);
  bool get pushEnabled => _preferences['pushEnabled'] ?? true;
  bool _savingPreferences = false;
  bool get isSavingPreferences => _savingPreferences;
  int _preferencesRevision = 0;

  Future<void> setPushEnabled(bool value) =>
      updatePreferences({'pushEnabled': value});

  Future<void> updatePreferences(Map<String, bool> patch) async {
    final source = repository;
    if (source is! NotificationPreferencesRepository || _savingPreferences)
      return;
    final account = _accountEpoch;
    final previous = Map<String, bool>.of(_preferences);
    _preferencesRevision++;
    _savingPreferences = true;
    _preferences = {..._preferences, ...patch};
    notifyListeners();
    final result = await (source as NotificationPreferencesRepository)
        .updatePreferences(patch);
    if (account != _accountEpoch) return;
    result.fold((failure) {
      _preferences = previous;
      AppErrorFeedback.report(failure, kind: AppErrorKind.send);
    }, (prefs) => _preferences = prefs);
    _savingPreferences = false;
    _preferencesRevision++;
    notifyListeners();
    await _synchronizeSystemDisplay();
  }

  var _items = <NotificationItem>[];
  int _unreadCount = 0;
  int _filter = 0;
  var _isLoading = false;
  var _isUpdating = false;
  var _hasLoaded = false;
  String? _errorMessage;
  var _epoch = 0;
  var _accountEpoch = 0;

  List<NotificationItem> get items => List.unmodifiable(_items);

  List<NotificationItem> get todayItems => todayFrom(visible);

  List<NotificationItem> get earlierItems => earlierFrom(visible);

  static List<NotificationItem> todayFrom(List<NotificationItem> items) => [
    for (final item in items)
      if (!item.isEarlier) item,
  ];

  static List<NotificationItem> earlierFrom(List<NotificationItem> items) => [
    for (final item in items)
      if (item.isEarlier) item,
  ];

  int get filter => _filter;

  int get unreadCount => _unreadCount;

  int get unreadNotificationCount => _unreadCount;

  bool get isLoading => _isLoading;

  bool get isUpdating => _isUpdating;

  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoading => !_hasLoaded;

  String? get errorMessage => _errorMessage;

  List<NotificationItem> get visible =>
      _filter == 0 ? items : _items.where((item) => item.unread).toList();

  void setFilter(int value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    final token = ++_epoch;
    final preferencesRevision = _preferencesRevision;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final feedResult = await repository.getNotifications(
      forceRefresh: forceRefresh,
    );
    if (token != _epoch) {
      _finishInitialLoad();
      return;
    }
    feedResult.fold<void>(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'notificationsFeed',
        );
      },
      (feed) {
        _items = feed.items;
        _unreadCount = feed.unreadCount;
        if (!_savingPreferences &&
            preferencesRevision == _preferencesRevision) {
          _preferences = feed.preferences;
        }
        _errorMessage = null;
      },
    );

    if (token == _epoch && _errorMessage == null)
      await _synchronizeSystemDisplay();
    _finishInitialLoad();
  }

  void _finishInitialLoad() {
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> markAllRead() {
    final account = _accountEpoch;
    _epoch++;
    return _runUpdate(() async {
      final result = await repository.markAllRead();
      if (account != _accountEpoch) return false;
      return result.fold(
        (failure) {
          _errorMessage = AppErrorFeedback.messageOf(failure);
          AppErrorFeedback.report(
            failure,
            kind: AppErrorKind.send,
            context: 'markAllRead',
          );
          return false;
        },
        (count) {
          _unreadCount = count;
          _items = [for (final item in _items) item.copyWith(unread: false)];
          return true;
        },
      );
    });
  }

  Future<bool> markRead(String id) {
    final account = _accountEpoch;
    _epoch++;
    return _runUpdate(() async {
      final result = await repository.markRead(id);
      if (account != _accountEpoch) return false;
      return result.fold(
        (failure) {
          _errorMessage = AppErrorFeedback.messageOf(failure);
          AppErrorFeedback.report(
            failure,
            kind: AppErrorKind.send,
            context: 'markRead',
          );
          return false;
        },
        (count) {
          _unreadCount = count;
          _items = [
            for (final item in _items)
              if (item.id == id) item.copyWith(unread: false) else item,
          ];
          return true;
        },
      );
    });
  }

  void clear() {
    _accountEpoch++;
    _epoch++;
    repository.clearCache();
    _items = [];
    _preferences = {};
    _savingPreferences = false;
    _preferencesRevision++;
    _unreadCount = 0;
    _filter = 0;
    _isLoading = false;
    _isUpdating = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runUpdate(Future<bool> Function() action) async {
    final account = _accountEpoch;
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();
    final success = await action();
    if (account != _accountEpoch) return false;
    _isUpdating = false;
    notifyListeners();
    if (success) await _synchronizeSystemDisplay();
    return success;
  }

  Future<void> _synchronizeSystemDisplay() async {
    try {
      await onSynchronized?.call(_items, _unreadCount, _preferences);
    } catch (error) {
      debugPrint(
        '[Notifications] System display reconciliation deferred: $error',
      );
    }
  }
}

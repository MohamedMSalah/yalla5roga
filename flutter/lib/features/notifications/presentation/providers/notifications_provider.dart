import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({required this.repository});

  final NotificationsRepository repository;

  var _items = <NotificationItem>[];
  int _unreadCount = 0;
  int _filter = 0;
  var _isLoading = false;
  var _isUpdating = false;
  var _hasLoaded = false;
  String? _errorMessage;
  var _epoch = 0;

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
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'notificationsFeed',
        );
      },
      (feed) {
        _items = feed.items;
        _unreadCount = feed.unreadCount;
        _errorMessage = null;
      },
    );

    _finishInitialLoad();
  }

  void _finishInitialLoad() {
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> markAllRead() {
    _epoch++;
    return _runUpdate(() async {
      final result = await repository.markAllRead();
      return result.fold(
        (failure) {
          _errorMessage = failure.message;
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
    _epoch++;
    return _runUpdate(() async {
      final result = await repository.markRead(id);
      return result.fold(
        (failure) {
          _errorMessage = failure.message;
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
    _epoch++;
    _items = [];
    _unreadCount = 0;
    _filter = 0;
    _isLoading = false;
    _isUpdating = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runUpdate(Future<bool> Function() action) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();
    final success = await action();
    _isUpdating = false;
    notifyListeners();
    return success;
  }
}

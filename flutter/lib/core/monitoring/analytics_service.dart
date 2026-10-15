import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// App Analytics events. Names stay within Firebase Analytics conventions.
abstract final class AnalyticsEvents {
  static const loginStarted = 'login_started';
  static const loginSuccess = 'login_success';
  static const loginFailed = 'login_failed';
  static const createGroup = 'create_group';
  static const joinGroup = 'join_group';
  static const createOuting = 'create_outing';
  static const submitVote = 'submit_vote';
}

/// Thin Analytics adapter. Do not send phones, OTPs, tokens, or passwords.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  var _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    await _analytics.setAnalyticsCollectionEnabled(true);
    _ready = true;
  }

  Future<void> setUserId(String? userId) async {
    if (!_ready) return;
    final id = userId?.trim();
    await _analytics.setUserId(id: (id == null || id.isEmpty) ? null : id);
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (kDebugMode) {
      debugPrint('[Analytics] $name ${parameters ?? {}}');
    }
    if (!_ready) return;
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> loginStarted({required bool isLogin, String method = 'email'}) =>
      logEvent(
        AnalyticsEvents.loginStarted,
        parameters: {'method': method, 'mode': isLogin ? 'login' : 'register'},
      );

  Future<void> loginSuccess({String method = 'email'}) =>
      logEvent(AnalyticsEvents.loginSuccess, parameters: {'method': method});

  Future<void> loginFailed({String? code, String method = 'email'}) => logEvent(
    AnalyticsEvents.loginFailed,
    parameters: {
      'method': method,
      if (code != null && code.isNotEmpty) 'error_code': code,
    },
  );

  Future<void> createGroup() => logEvent(AnalyticsEvents.createGroup);

  Future<void> joinGroup() => logEvent(AnalyticsEvents.joinGroup);

  Future<void> createOuting({String? source}) => logEvent(
    AnalyticsEvents.createOuting,
    parameters: {if (source != null && source.isNotEmpty) 'source': source},
  );

  Future<void> submitVote() => logEvent(AnalyticsEvents.submitVote);
}

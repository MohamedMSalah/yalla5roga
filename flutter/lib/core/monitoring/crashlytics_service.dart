import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin Crashlytics adapter. Presentation must not import Firebase packages.
class CrashlyticsService {
  CrashlyticsService._();

  static final CrashlyticsService instance = CrashlyticsService._();

  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  var _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    // Collection on in release; keep enabled in debug so QA can verify wiring.
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
    _ready = true;
  }

  Future<void> setUserId(String? userId) async {
    if (!_ready) return;
    final id = userId?.trim();
    if (id == null || id.isEmpty) {
      await _crashlytics.setUserIdentifier('');
      return;
    }
    await _crashlytics.setUserIdentifier(id);
  }

  Future<void> setCustomKey(String key, Object value) async {
    if (!_ready) return;
    await _crashlytics.setCustomKey(key, value);
  }

  Future<void> log(String message) async {
    if (!_ready) return;
    await _crashlytics.log(message);
  }

  /// Records an error once. Safe to call from repositories / global handlers.
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[Crashlytics] ${fatal ? 'FATAL' : 'non-fatal'}: '
        '${reason ?? error.runtimeType} → $error',
      );
    }
    if (!_ready) return;
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    if (!_ready) return;
    await _crashlytics.recordFlutterFatalError(details);
  }
}

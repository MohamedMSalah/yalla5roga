import 'package:flutter/foundation.dart';

/// Cold-start marks for debug and profile runs.
class StartupTrace {
  StartupTrace._();

  static final _clock = Stopwatch();
  static var _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    _clock.start();
  }

  static void mark(String name) {
    start();
    if (!kDebugMode && !kProfileMode) return;
    debugPrint('[Startup] $name ${_clock.elapsedMilliseconds}ms');
  }
}

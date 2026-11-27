import 'dart:async';

class MeetupRefreshDebouncer {
  Timer? _timer;

  void schedule(void Function() refresh) {
    _timer ??= Timer(const Duration(milliseconds: 250), () {
      _timer = null;
      refresh();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

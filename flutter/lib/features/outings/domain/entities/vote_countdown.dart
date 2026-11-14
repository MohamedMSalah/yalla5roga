/// Remaining wall-clock time, rounded up so a live last second is never zero.
class VoteCountdown {
  VoteCountdown({
    required DateTime endsAt,
    required DateTime now,
    bool isClosed = false,
  }) : totalSeconds = isClosed || !endsAt.isAfter(now)
           ? 0
           : (endsAt.difference(now).inMicroseconds +
                     Duration.microsecondsPerSecond -
                     1) ~/
                 Duration.microsecondsPerSecond;
  final int totalSeconds;
  bool get ended => totalSeconds == 0;
  int get days => totalSeconds ~/ Duration.secondsPerDay;
  int get hours => (totalSeconds ~/ Duration.secondsPerHour) % 24;
  int get minutes => (totalSeconds ~/ Duration.secondsPerMinute) % 60;
  int get seconds => totalSeconds % 60;
}

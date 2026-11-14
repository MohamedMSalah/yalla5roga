enum VotingDeadlineUnit { hours, days }

enum VotingDeadlineProblem { unsupportedDuration, notFuture, afterOutingStart }

/// Duration and instant policy shared by the form and the final API submission.
class VotingDeadlinePolicy {
  const VotingDeadlinePolicy._();

  static const hourPresets = [1, 2, 3, 6, 12, 24];
  static const dayPresets = [1, 2, 3, 5, 7];
  static const maxHours = 7 * 24;

  static DateTime endsAt(DateTime now, int hours) =>
      now.toUtc().add(Duration(hours: hours));

  static VotingDeadlineProblem? validate({
    required DateTime now,
    required int hours,
    DateTime? scheduledAt,
  }) {
    if (hours < 1 || hours > maxHours) {
      return VotingDeadlineProblem.unsupportedDuration;
    }
    return validateInstant(
      now: now,
      deadline: endsAt(now, hours),
      scheduledAt: scheduledAt,
    );
  }

  static VotingDeadlineProblem? validateInstant({
    required DateTime now,
    required DateTime deadline,
    DateTime? scheduledAt,
  }) {
    if (!deadline.isAfter(now)) return VotingDeadlineProblem.notFuture;
    if (scheduledAt != null && !deadline.isBefore(scheduledAt)) {
      return VotingDeadlineProblem.afterOutingStart;
    }
    return null;
  }
}

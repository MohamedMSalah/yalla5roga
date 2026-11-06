enum OutingOccasion { none, birthday, wedding }

/// Server-stored outing kind (`outings.type`).
enum OutingType { group, specialEvent }

/// Product lifecycle + post-event terminal.
enum OutingStatus { draft, voting, confirmed, cancelled, past }

/// Place / outing category used for filters and fallback cover icons.
enum OutingVibe { food, activity, outdoor, movie }

/// Attendance is independent of place voting.
/// [unset] is client-only (no attendance row yet) and is never sent to the API.
enum AttendanceStatus { going, notGoing, maybe, unset }

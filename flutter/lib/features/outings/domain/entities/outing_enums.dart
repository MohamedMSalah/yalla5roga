enum OutingOccasion { none, birthday, wedding, celebration, other }

/// Server-stored outing kind (`outings.type`).
enum OutingType { group, specialEvent }

/// Product lifecycle + post-event terminal.
enum OutingStatus { draft, voting, confirmed, cancelled, past }

/// Place / outing category used for filters and fallback cover icons.
enum OutingVibe { food, activity, outdoor, movie }

/// Attendance is independent of place voting.
/// [unset] represents the read-only no_response default (no RSVP row yet).
/// It is never submitted as an attendance write.
enum AttendanceStatus { going, notGoing, maybe, unset }

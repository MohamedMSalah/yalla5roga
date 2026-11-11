class OutingArrival {
  const OutingArrival({
    required this.userId,
    required this.name,
    required this.arrivedAt,
    required this.method,
  });

  final String userId;
  final String name;
  final DateTime arrivedAt;
  final String method;
}

class OutingArrivalRoster {
  const OutingArrivalRoster({
    required this.arrivals,
    required this.unconfirmed,
    required this.open,
    required this.closesAt,
    required this.radiusMeters,
    required this.opensAt,
    required this.maxAccuracyMeters,
    required this.venue,
  });

  final List<OutingArrival> arrivals;
  final List<({String id, String name})> unconfirmed;
  final bool open;
  final DateTime? closesAt;
  final double radiusMeters;
  final DateTime? opensAt;
  final double maxAccuracyMeters;
  final ({double latitude, double longitude})? venue;
}

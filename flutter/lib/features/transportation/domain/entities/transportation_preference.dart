enum TransportationMode {
  car('CAR'),
  motorcycle('MOTORCYCLE'),
  metro('METRO'),
  walking('WALKING');

  const TransportationMode(this.code);
  final String code;
}

class TransportationPreference {
  const TransportationPreference({required this.defaultMode});

  final TransportationMode? defaultMode;
}

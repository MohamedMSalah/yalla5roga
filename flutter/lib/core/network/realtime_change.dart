/// Additive domain event envelope on the existing session socket.
class RealtimeChange {
  const RealtimeChange({
    required this.kind,
    this.id,
    this.payload,
    this.session,
  });
  final String kind;
  final String? id;
  final Map<String, dynamic>? payload;
  final int? session;
}

/// The replay checkpoint advances only after a successful reconciliation.
///
/// A live event can arrive before the replay acknowledgement and must not
/// acknowledge older events that this connection has never received.
class RealtimeCursor {
  Map<String, dynamic>? checkpoint;
  final _seen = <String>{};

  bool accept(Map<String, dynamic>? cursor) {
    final epoch = cursor?['epoch'];
    final sequence = cursor?['sequence'];
    if (epoch is! String || sequence is! int || sequence < 0) return true;
    final key = '$epoch:$sequence';
    if (!_seen.add(key)) return false;
    while (_seen.length > 1024) {
      _seen.remove(_seen.first);
    }
    return true;
  }

  void acknowledge(Map<String, dynamic>? cursor) {
    if (cursor?['epoch'] is! String || cursor?['sequence'] is! int) return;
    final previous = checkpoint;
    if (previous == null ||
        previous['epoch'] != cursor!['epoch'] ||
        (previous['sequence'] as int) <= (cursor['sequence'] as int)) {
      checkpoint = cursor;
    }
  }

  void clear() {
    checkpoint = null;
    _seen.clear();
  }
}

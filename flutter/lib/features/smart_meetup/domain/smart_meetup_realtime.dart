import 'entities/smart_meetup_realtime_event.dart';

abstract interface class SmartMeetupRealtime {
  SmartMeetupRealtimeSubscription subscribe(
    String account,
    String sessionId, {
    required void Function(SmartMeetupRealtimeEvent) onChange,
    required void Function(int? version, bool reconnect) onJoined,
  });
}

abstract interface class SmartMeetupRealtimeSubscription {
  void dispose();
}

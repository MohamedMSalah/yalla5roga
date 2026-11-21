import 'dart:async';

/// Tags a logical request at its source and follows async repository calls.
class RequestScope {
  const RequestScope({this.feature, this.origin, this.operation, this.trigger});

  final String? feature;
  final String? origin;
  final String? operation;
  final String? trigger;

  static final _key = Object();
  static RequestScope? get current => Zone.current[_key] as RequestScope?;

  static Future<T> run<T>(
    Future<T> Function() action, {
    String? feature,
    String? origin,
    String? operation,
    String? trigger,
  }) {
    final parent = current;
    return runZoned(
      action,
      zoneValues: {
        _key: RequestScope(
          feature: parent?.feature ?? feature,
          origin: parent?.origin ?? origin,
          operation: operation ?? parent?.operation,
          trigger: trigger ?? parent?.trigger,
        ),
      },
    );
  }
}

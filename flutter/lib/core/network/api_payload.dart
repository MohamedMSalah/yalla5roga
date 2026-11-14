Map<String, dynamic> apiPayload(Map<String, dynamic>? body) {
  final data = body ?? {};
  final nested = data['data'];
  if (nested is Map<String, dynamic>) return nested;
  return data;
}

int apiInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool apiBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == '1';
}

String? apiString(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty || text == 'null' ? null : text;
}

List<Map<String, dynamic>> apiObjectList(
  dynamic data, {
  List<String> aliases = const [],
}) {
  final root = data is Map ? Map<String, dynamic>.from(data) : null;
  dynamic list;
  if (root != null) {
    list = root['data'];
    if (list is Map) {
      for (final key in ['items', 'results', ...aliases]) {
        if (list[key] is List) {
          list = list[key];
          break;
        }
      }
    }
    if (list is! List) {
      for (final key in ['items', 'results', ...aliases]) {
        if (root[key] is List) {
          list = root[key];
          break;
        }
      }
    }
  } else {
    list = data;
  }
  if (list is! List) return const [];
  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// Maps Dart attendance enum names to backend snake_case wire values.
String attendanceStatusToApi(String dartName) {
  switch (dartName) {
    case 'notGoing':
      return 'not_going';
    case 'unset':
      throw ArgumentError('unset attendance is client-only');
    default:
      return dartName;
  }
}

/// Maps backend attendance wire values to Dart enum names.
String attendanceStatusFromApi(String? wire) {
  switch (wire) {
    case 'not_going':
      return 'notGoing';
    case 'going':
      return 'going';
    case 'maybe':
      return 'maybe';
    case 'no_response':
      return 'unset';
    default:
      return 'unset';
  }
}

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

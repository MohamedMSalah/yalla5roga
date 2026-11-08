/// Backend `image_url` fields only accept absolute http(s) URLs (or empty).
/// Local gallery/camera paths must never be sent on create/update payloads.
String? remoteImageUrlOrNull(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  return null;
}

String remoteImageUrlOrEmpty(String? value) => remoteImageUrlOrNull(value) ?? '';

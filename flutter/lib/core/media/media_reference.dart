/// Stable client references to backend media assets.
///
/// Entity image fields (`users.image_url`, `groups.image_url`,
/// `outings.image_url`, `places.cover_image_url`, place images) may hold:
/// - an absolute `http(s)` URL (legacy rows and public CDN URLs), or
/// - `media://<uuid>` for assets stored through the media pipeline.
///
/// The reference is stable for the lifetime of the asset. Delivery URLs —
/// especially short-lived signed GET URLs for private assets — must never be
/// persisted as the entity value or used as the image-cache identity.
library;

const String mediaReferenceScheme = 'media://';

final RegExp _mediaReferencePattern = RegExp(
  r'^media://([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
);

/// Whether [value] is a well-formed `media://<uuid>` reference.
bool isMediaReference(String? value) {
  final text = value?.trim() ?? '';
  return _mediaReferencePattern.hasMatch(text);
}

/// Extracts the media asset UUID from a reference, or `null` when [value] is
/// not a media reference.
String? parseMediaId(String? value) {
  final match = _mediaReferencePattern.firstMatch(value?.trim() ?? '');
  return match?.group(1);
}

/// Builds the canonical reference stored in entity image fields.
String buildMediaReference(String assetId) =>
    '$mediaReferenceScheme${assetId.trim()}';

/// Whether [value] is an absolute http(s) URL.
bool isRemoteHttpUrl(String? value) {
  final text = value?.trim() ?? '';
  return text.startsWith('http://') || text.startsWith('https://');
}

/// Whether [value] is a local file path that still needs uploading.
bool isLocalFilePath(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return false;
  return !isRemoteHttpUrl(text) && !isMediaReference(text);
}

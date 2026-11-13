import 'package:yalla_5roga/core/media/media_reference.dart';

/// Backend `image_url` fields accept absolute http(s) URLs, stable
/// `media://<asset-id>` references, or empty. Local gallery/camera paths must
/// never be sent on create/update payloads.
String? remoteImageUrlOrNull(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (isRemoteHttpUrl(text)) return text;
  if (isMediaReference(text)) return text;
  return null;
}

String remoteImageUrlOrEmpty(String? value) => remoteImageUrlOrNull(value) ?? '';

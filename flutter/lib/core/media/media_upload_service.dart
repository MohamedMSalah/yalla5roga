import 'dart:io';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';

/// Backend media purposes. The wire value is the enum name.
enum MediaPurpose { profile, group, outing, place, chat }

/// Raised when a local image cannot be uploaded (unsupported type, too large,
/// network failure, or a failed confirm).
class MediaUploadException implements Exception {
  const MediaUploadException(this.message);

  final String message;

  @override
  String toString() => 'MediaUploadException: $message';
}

/// Result of a successful direct upload.
class UploadedMedia {
  const UploadedMedia({
    required this.mediaId,
    required this.reference,
    required this.visibility,
  });

  final String mediaId;
  final String reference;
  final MediaVisibility visibility;
}

/// Uploads local image files directly to Cloudflare R2 (or the backend mock
/// storage in local development), bypassing the API/Neon for bytes.
///
/// Flow per file:
/// 1. `POST /api/media/upload-url` → pending asset + presigned PUT URL.
/// 2. `PUT` the bytes straight to object storage (no Firebase header).
/// 3. `POST /api/media/:id/confirm` → backend HEADs the object before `ready`.
/// 4. Return the stable `media://<id>` reference to persist on the entity.
class MediaUploadService {
  MediaUploadService({
    required this.apiClient,
    Dio? storageDio,
    this.apiBaseUrl,
    this.maxUploadBytes = 10 * 1024 * 1024,
  }) : _storageDio = storageDio ?? Dio();

  static const Set<String> supportedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  final ApiClient apiClient;
  final Dio _storageDio;
  final String? apiBaseUrl;
  final int maxUploadBytes;

  /// Uploads [path] and returns the media reference to send on create/update.
  ///
  /// Pass [mediaId] to re-issue a fresh URL for a still-pending intent (e.g.
  /// after a presigned-URL expiry). Pass [entityId] when the group/outing row
  /// already exists; covers uploaded before creation omit it.
  Future<UploadedMedia> uploadLocalImage({
    required String path,
    required MediaPurpose purpose,
    String? entityId,
    String? mediaId,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const MediaUploadException('Selected image no longer exists');
    }
    final size = await file.length();
    if (size <= 0) {
      throw const MediaUploadException('Selected image is empty');
    }
    if (size > maxUploadBytes) {
      throw const MediaUploadException('Selected image is too large');
    }
    final mimeType = mediaMimeTypeForPath(path);
    if (mimeType == null || !supportedMimeTypes.contains(mimeType)) {
      throw const MediaUploadException('Unsupported image format');
    }

    String? assetId = mediaId;
    var confirmed = false;
    try {
      final intent = await _requestUpload(
        purpose: purpose,
        mimeType: mimeType,
        fileSize: size,
        entityId: entityId,
        mediaId: mediaId,
      );
      assetId = intent.mediaId;
      final uploadUrl = _reachableStorageUrl(intent.uploadUrl);

      final bytes = await file.readAsBytes();
      final uploadResponse = await _storageDio.put<void>(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: {
            Headers.contentTypeHeader: mimeType,
            Headers.contentLengthHeader: bytes.length,
          },
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      if (uploadResponse.statusCode == null ||
          uploadResponse.statusCode! < 200 ||
          uploadResponse.statusCode! >= 300) {
        throw const MediaUploadException('Storage rejected the upload');
      }

      final confirmedAsset = await _confirmUpload(assetId);
      confirmed = true;
      final visibility =
          MediaVisibility.parse(confirmedAsset['visibility']) ??
          MediaVisibility.private;
      return UploadedMedia(
        mediaId: assetId,
        reference: buildMediaReference(assetId),
        visibility: visibility,
      );
    } on MediaUploadException {
      rethrow;
    } on DioException catch (error) {
      throw MediaUploadException(_dioMessage(error));
    } catch (error) {
      throw MediaUploadException('$error');
    } finally {
      // Orphan cleanup: a failed upload must not leave a pending row behind.
      if (!confirmed && assetId != null) {
        await _bestEffortDelete(assetId);
      }
    }
  }

  /// Deletes an owned asset. Safe to call when replacing an image; failures
  /// are ignored because the backend cleanup job also reaps orphans.
  Future<void> deleteMediaReference(String? reference) async {
    final assetId = parseMediaId(reference);
    if (assetId == null) return;
    await _bestEffortDelete(assetId);
  }

  Future<_UploadIntent> _requestUpload({
    required MediaPurpose purpose,
    required String mimeType,
    required int fileSize,
    String? entityId,
    String? mediaId,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      ApiConstants.mediaUploadUrl,
      data: {
        'purpose': purpose.name,
        'mime_type': mimeType,
        'file_size': fileSize,
        'entity_id': ?entityId,
        'media_id': ?mediaId,
      },
    );
    final data = apiPayload(response.data);
    final id = '${data['media_id'] ?? ''}';
    final url = '${data['upload_url'] ?? ''}';
    if (id.isEmpty || url.isEmpty) {
      throw const MediaUploadException('Upload intent was incomplete');
    }
    return _UploadIntent(mediaId: id, uploadUrl: url);
  }

  Future<Map<String, dynamic>> _confirmUpload(String mediaId) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      ApiConstants.mediaConfirm(mediaId),
    );
    return apiPayload(response.data);
  }

  Future<void> _bestEffortDelete(String mediaId) async {
    try {
      await apiClient.delete<Map<String, dynamic>>(
        ApiConstants.mediaDelete(mediaId),
      );
    } catch (_) {
      // Best effort only.
    }
  }

  /// The mock adapter advertises `http://localhost:3000/...`. On emulators a
  /// loopback host points at the device, so rewrite it to the API host (the
  /// real R2 endpoint is always reachable and never matches this case).
  String _reachableStorageUrl(String url) {
    final outbound = Uri.tryParse(url);
    final base = Uri.tryParse(apiBaseUrl ?? '');
    if (outbound == null || base == null || base.host.isEmpty) return url;
    const loopback = {'localhost', '127.0.0.1', '::1'};
    if (!loopback.contains(outbound.host) || loopback.contains(base.host)) {
      return url;
    }
    return outbound
        .replace(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
        )
        .toString();
  }

  static String? mediaMimeTypeForPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    switch (path.substring(dot + 1).toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  static String _dioMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'You do not have permission to upload this image';
    }
    if (status == 413) return 'Selected image is too large';
    if (status != null) return 'Upload failed ($status)';
    return 'Upload failed. Check your connection and try again.';
  }
}

class _UploadIntent {
  const _UploadIntent({required this.mediaId, required this.uploadUrl});

  final String mediaId;
  final String uploadUrl;
}

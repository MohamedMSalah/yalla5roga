import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

typedef OptimizedImage = ({Uint8List bytes, String mimeType});

class MediaUploadException implements Exception {
  const MediaUploadException(this.message);

  final String message;

  @override
  String toString() => 'MediaUploadException: $message';
}

class ImageOptimizer {
  const ImageOptimizer();

  static const _maxInputBytes = 32 * 1024 * 1024;
  static const _maxInputPixels = 24 * 1000 * 1000;
  static const _edge = int.fromEnvironment(
    'IMAGE_UPLOAD_MAX_EDGE',
    defaultValue: 1600,
  );
  static const _target = int.fromEnvironment(
    'IMAGE_UPLOAD_TARGET_BYTES',
    defaultValue: 350 * 1024,
  );
  static const _quality = int.fromEnvironment(
    'IMAGE_UPLOAD_QUALITY',
    defaultValue: 80,
  );

  Future<OptimizedImage> optimize(String path, {required int maxBytes}) {
    return Isolate.run(() => _process(path, maxBytes));
  }

  static OptimizedImage _process(String path, int maxBytes) {
    try {
      final file = File(path);
      final length = file.lengthSync();
      if (length < 1 || length > _maxInputBytes) {
        throw const MediaUploadException('Unsupported source image size');
      }
      // Read at most the checked size, even if the picker file changes.
      final handle = file.openSync();
      final Uint8List input;
      try {
        input = handle.readSync(length);
      } finally {
        handle.closeSync();
      }
      if (input.length < 8) {
        throw const MediaUploadException('Unsupported image format');
      }
      final decoder = img.findDecoderForData(input);
      if (decoder is! img.JpegDecoder &&
          decoder is! img.PngDecoder &&
          decoder is! img.WebPDecoder &&
          decoder is! img.GifDecoder) {
        throw const MediaUploadException('Unsupported image format');
      }
      final info = decoder!.startDecode(input);
      final frames = (info?.numFrames ?? 1).clamp(1, 60);
      if (info == null ||
          info.width < 1 ||
          info.height < 1 ||
          info.width * info.height * frames > _maxInputPixels ||
          info.numFrames > 60 ||
          (frames > 1 &&
              decoder is! img.GifDecoder &&
              decoder is! img.WebPDecoder)) {
        throw const MediaUploadException(
          'Unsupported image dimensions or animation',
        );
      }
      final decoded = frames == 1
          ? decoder.decodeFrame(0)
          : decoder.decode(input);
      if (decoded == null || decoded.numFrames != frames) {
        throw const MediaUploadException('Image could not be decoded');
      }
      final edge = _edge.clamp(256, 2400);
      final quality = _quality.clamp(65, 90);
      final target = _target
          .clamp(32 * 1024, 2 * 1024 * 1024)
          .clamp(1, maxBytes);
      if (decoder is img.WebPDecoder &&
          frames == 1 &&
          decoded.width <= edge &&
          decoded.height <= edge &&
          input.length <= target &&
          _cleanWebP(input)) {
        return (bytes: input, mimeType: 'image/webp');
      }
      final original = img.bakeOrientation(decoded);
      for (final frame in original.frames) {
        frame
          ..exif = img.ExifData()
          ..iccProfile = null
          ..textData = null;
      }
      OptimizedImage? result;
      for (final (limit, compression) in [
        (edge, quality),
        (edge, (quality - 9).clamp(65, 90)),
        ((edge * .75).round(), 70),
        ((edge * .55).round(), 65),
      ]) {
        final resized = _fit(original, limit);
        result = _encode(resized, compression);
        if (result.bytes.length <= target) return result;
      }
      if (result != null && result.bytes.length <= maxBytes) return result;
      throw const MediaUploadException(
        'Optimized image exceeds the upload limit',
      );
    } on MediaUploadException {
      rethrow;
    } catch (_) {
      throw const MediaUploadException('Image could not be decoded');
    }
  }

  static bool _cleanWebP(Uint8List bytes) {
    if (bytes.length < 20) return false;
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(4, Endian.little) != bytes.length - 8) return false;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunk = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (!const {'VP8 ', 'VP8L', 'VP8X', 'ALPH'}.contains(chunk)) return false;
      final length = data.getUint32(offset + 4, Endian.little);
      offset += 8 + length + length % 2;
    }
    return offset == bytes.length;
  }

  static img.Image _fit(img.Image image, int edge) {
    if (image.width <= edge && image.height <= edge) return image;
    final landscape = image.width >= image.height;
    return img.copyResize(
      image,
      width: landscape ? edge : null,
      height: landscape ? null : edge,
      interpolation: img.Interpolation.average,
    );
  }

  static OptimizedImage _encode(img.Image image, int quality) {
    try {
      return (
        bytes: img.encodeWebP(
          image,
          lossless: false,
          quality: quality,
          method: 1,
        ),
        mimeType: 'image/webp',
      );
    } on img.ImageException {
      if (image.numFrames > 1) {
        throw const MediaUploadException('Animated image could not be encoded');
      }
      if (image.hasAlpha) {
        return (bytes: img.encodePng(image), mimeType: 'image/png');
      }
      return (
        bytes: img.encodeJpg(image, quality: quality),
        mimeType: 'image/jpeg',
      );
    }
  }
}

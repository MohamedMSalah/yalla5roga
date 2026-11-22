import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yalla_5roga/core/media/image_optimizer.dart';

void main() {
  late Directory temporary;
  const optimizer = ImageOptimizer();

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('yalla-image-test-');
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'respects EXIF orientation and preserves transparent small images',
    () async {
      final transparent = img.Image(width: 80, height: 40, numChannels: 4);
      transparent.setPixelRgba(0, 0, 255, 0, 0, 0);
      final png = await File('${temporary.path}/sample.dat')
          .writeAsBytes(img.encodePng(transparent));
      final alpha = await optimizer.optimize(png.path, maxBytes: 1024 * 1024);
      final decoded = img.decodeImage(alpha.bytes)!;
      expect(alpha.mimeType, 'image/webp');
      expect((decoded.width, decoded.height), (80, 40));
      expect(decoded.getPixel(0, 0).a, 0);

      final camera = img.Image(width: 64, height: 32)
        ..exif.imageIfd.orientation = 6
        ..exif.imageIfd.make = 'Test camera';
      final jpeg = await File('${temporary.path}/camera.jpg')
          .writeAsBytes(img.encodeJpg(camera));
      final rotated = await optimizer.optimize(
        jpeg.path,
        maxBytes: 1024 * 1024,
      );
      final corrected = img.decodeImage(rotated.bytes)!;
      expect((corrected.width, corrected.height), (32, 64));
      expect(corrected.exif.imageIfd.make, isNull);
    },
  );

  test('reduces a detailed photograph while keeping aspect ratio', () async {
    final image = img.Image(width: 1700, height: 850);
    final random = Random(7);
    for (final pixel in image) {
      final grain = random.nextInt(100);
      pixel
        ..r = grain + pixel.x ~/ 12
        ..g = grain + pixel.y ~/ 6
        ..b = grain + 35;
    }
    final source = img.encodeJpg(image, quality: 98);
    final jpeg = await File('${temporary.path}/details.jpg')
        .writeAsBytes(source);
    final optimized = await optimizer.optimize(
      jpeg.path,
      maxBytes: 1024 * 1024,
    );
    final output = img.decodeImage(optimized.bytes)!;
    expect(output.width, lessThanOrEqualTo(1600));
    expect(output.width / output.height, closeTo(2, .01));
    expect(optimized.bytes.length, lessThan(source.length));
  });

  test('rejects malformed uploads before requesting storage', () async {
    final file = await File('${temporary.path}/invalid.jpg')
        .writeAsString('<html>not an image</html>');
    await expectLater(
      optimizer.optimize(file.path, maxBytes: 1024 * 1024),
      throwsA(isA<MediaUploadException>()),
    );
  });

  test('preserves clean WebP and retains bounded animation frames', () async {
    final base = img.Image(width: 40, height: 20, frameDuration: 100);
    final still = img.encodeWebP(base);
    final file = File('${temporary.path}/sample.webp');
    await file.writeAsBytes(still);
    final clean = await optimizer.optimize(file.path, maxBytes: 1024 * 1024);
    expect(clean.bytes, still);

    base.addFrame(img.Image(width: 40, height: 20, frameDuration: 150));
    await file.writeAsBytes(img.encodeWebP(base));
    final animated = await optimizer.optimize(file.path, maxBytes: 1024 * 1024);
    final decoded = img.decodeWebP(animated.bytes)!;
    expect(decoded.numFrames, 2);
    expect(decoded.frames.map((frame) => frame.frameDuration), [100, 150]);
  });
}

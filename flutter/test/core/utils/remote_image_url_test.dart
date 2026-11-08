import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/utils/remote_image_url.dart';

void main() {
  group('remoteImageUrlOrNull', () {
    test('keeps http(s) urls', () {
      expect(
        remoteImageUrlOrNull('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
      expect(
        remoteImageUrlOrNull('http://cdn.example.com/a.jpg'),
        'http://cdn.example.com/a.jpg',
      );
    });

    test('drops local paths and empty values', () {
      expect(remoteImageUrlOrNull(null), isNull);
      expect(remoteImageUrlOrNull(''), isNull);
      expect(remoteImageUrlOrNull('   '), isNull);
      expect(
        remoteImageUrlOrNull('/data/user/0/com.example/cache/img.jpg'),
        isNull,
      );
      expect(remoteImageUrlOrNull('C:\\Users\\me\\Pictures\\a.jpg'), isNull);
    });
  });
}

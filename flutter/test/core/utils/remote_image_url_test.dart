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

    test('keeps stable media references', () {
      const reference = 'media://0f8fad5b-d9cb-469f-a165-70867728950e';
      expect(remoteImageUrlOrNull(reference), reference);
      expect(remoteImageUrlOrNull('  $reference  '), reference);
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
      expect(remoteImageUrlOrNull('media://not-a-uuid'), isNull);
    });
  });
}

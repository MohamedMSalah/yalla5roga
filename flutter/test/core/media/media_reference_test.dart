import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';

void main() {
  const id = '0f8fad5b-d9cb-469f-a165-70867728950e';

  group('media reference', () {
    test('builds and parses stable media:// references', () {
      final reference = buildMediaReference(id);
      expect(reference, 'media://$id');
      expect(isMediaReference(reference), isTrue);
      expect(parseMediaId(reference), id);
      expect(parseMediaId('  $reference  '), id);
    });

    test('rejects malformed references', () {
      expect(isMediaReference(null), isFalse);
      expect(isMediaReference(''), isFalse);
      expect(isMediaReference('media://not-a-uuid'), isFalse);
      expect(isMediaReference('https://cdn.example.com/$id'), isFalse);
      expect(parseMediaId('media://$id/extra'), isNull);
    });

    test('classifies remote, media, and local image values', () {
      expect(isRemoteHttpUrl('https://cdn.example.com/a.jpg'), isTrue);
      expect(isRemoteHttpUrl('http://cdn.example.com/a.jpg'), isTrue);
      expect(isRemoteHttpUrl('media://$id'), isFalse);
      expect(isLocalFilePath('/data/user/0/img.jpg'), isTrue);
      expect(isLocalFilePath('C:\\Users\\me\\a.jpg'), isTrue);
      expect(isLocalFilePath('https://cdn.example.com/a.jpg'), isFalse);
      expect(isLocalFilePath('media://$id'), isFalse);
      expect(isLocalFilePath(''), isFalse);
    });
  });
}

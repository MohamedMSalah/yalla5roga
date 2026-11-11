import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/network/realtime_change.dart';

void main() {
  test('live delivery during reconnect cannot acknowledge a missed event', () {
    final cursor = RealtimeCursor();
    cursor.acknowledge({'epoch': 'server', 'sequence': 1});
    expect(cursor.accept({'epoch': 'server', 'sequence': 3}), isTrue);
    expect(cursor.checkpoint?['sequence'], 1);
    expect(cursor.accept({'epoch': 'server', 'sequence': 2}), isTrue);
    expect(cursor.accept({'epoch': 'server', 'sequence': 3}), isFalse);
    cursor.acknowledge({'epoch': 'server', 'sequence': 3});
    cursor.acknowledge({'epoch': 'server', 'sequence': 2});
    expect(cursor.checkpoint?['sequence'], 3);
  });

  test('logout clears cursor and deduplication for account switching', () {
    final cursor = RealtimeCursor();
    cursor.accept({'epoch': 'server', 'sequence': 1});
    cursor.acknowledge({'epoch': 'server', 'sequence': 1});
    cursor.clear();
    expect(cursor.checkpoint, isNull);
    expect(cursor.accept({'epoch': 'server', 'sequence': 1}), isTrue);
    cursor.acknowledge({'epoch': 'restart', 'sequence': 0});
    expect(cursor.checkpoint?['epoch'], 'restart');
  });
}

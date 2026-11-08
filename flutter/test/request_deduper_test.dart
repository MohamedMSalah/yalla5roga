import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';

void main() {
  test('reuses in-flight future for the same key', () async {
    final deduper = RequestDeduper();
    var runs = 0;

    Future<int> start() {
      return deduper.run('k', () async {
        runs++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return 7;
      });
    }

    final results = await Future.wait([start(), start(), start()]);
    expect(results, [7, 7, 7]);
    expect(runs, 1);
  });

  test('allows retry after failure', () async {
    final deduper = RequestDeduper();
    var runs = 0;

    try {
      await deduper.run('fail', () async {
        runs++;
        throw StateError('boom');
      });
    } catch (_) {}

    final value = await deduper.run('fail', () async {
      runs++;
      return 1;
    });
    expect(value, 1);
    expect(runs, 2);
  });

  test('keyFor includes sorted query', () {
    expect(
      RequestDeduper.keyFor(
        method: 'get',
        path: '/api/x',
        query: {'b': 2, 'a': 1},
      ),
      'GET /api/x?a=1&b=2',
    );
  });
}

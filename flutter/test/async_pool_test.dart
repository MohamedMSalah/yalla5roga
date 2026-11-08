import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/utils/async_pool.dart';

void main() {
  test('mapPool preserves order with limited concurrency', () async {
    var peak = 0;
    var inFlight = 0;

    final results = await mapPool([1, 2, 3, 4, 5, 6], (item) async {
      inFlight++;
      if (inFlight > peak) peak = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inFlight--;
      return item * 10;
    }, concurrency: 2);

    expect(results, [10, 20, 30, 40, 50, 60]);
    expect(peak, lessThanOrEqualTo(2));
  });
}

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  test('cachedRemote serves TTL hit without refetch', () async {
    final cache = TtlCache<String>(ttl: const Duration(minutes: 1));
    cache.set('k', 'cached');
    var fetches = 0;

    final result = await cachedRemote<String>(
      networkInfo: _Online(),
      cache: cache,
      key: 'k',
      deduper: RequestDeduper(),
      fetch: () async {
        fetches++;
        return 'network';
      },
    );

    expect(result, const Right('cached'));
    expect(fetches, 0);
  });

  test('cachedRemote dedupes concurrent misses', () async {
    final cache = TtlCache<String>(ttl: const Duration(minutes: 1));
    final deduper = RequestDeduper();
    var fetches = 0;

    Future<Either<Failure, String>> start() {
      return cachedRemote<String>(
        networkInfo: _Online(),
        cache: cache,
        key: 'miss',
        deduper: deduper,
        fetch: () async {
          fetches++;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return 'ok';
        },
      );
    }

    final results = await Future.wait([start(), start()]);
    expect(results[0], const Right('ok'));
    expect(results[1], const Right('ok'));
    expect(fetches, 1);
  });
}

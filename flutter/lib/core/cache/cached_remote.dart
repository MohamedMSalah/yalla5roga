import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';

/// Cache-aside helper for repository GET calls.
///
/// 1. Return fresh cache when available (unless [forceRefresh]).
/// 2. Fetch remote on miss/expiry.
/// 3. On remote failure, optionally serve stale cache.
Future<Either<Failure, T>> cachedRemote<T>({
  required NetworkInfo networkInfo,
  required TtlCache<T> cache,
  required String key,
  required Future<T> Function() fetch,
  bool forceRefresh = false,
  bool allowStaleOnError = true,
  String? reason,
}) async {
  if (!forceRefresh) {
    final fresh = cache.get(key);
    if (fresh != null) return Right(fresh);
  }

  final result = await guardRemote(networkInfo, fetch, reason: reason);
  return result.fold(
    (failure) {
      if (allowStaleOnError) {
        final stale = cache.getStale(key);
        if (stale != null) return Right(stale);
      }
      return Left(failure);
    },
    (value) {
      cache.set(key, value);
      return Right(value);
    },
  );
}

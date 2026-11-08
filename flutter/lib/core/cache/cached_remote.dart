import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';

/// Shared in-flight deduper for repository GET helpers.
final RequestDeduper cachedRemoteDeduper = RequestDeduper();

/// Cache-aside helper for repository GET calls.
///
/// 1. Return fresh cache when available (unless [forceRefresh]).
/// 2. Deduplicate concurrent fetches for the same [key].
/// 3. Fetch remote on miss/expiry.
/// 4. On remote failure, optionally serve stale cache.
Future<Either<Failure, T>> cachedRemote<T>({
  required NetworkInfo networkInfo,
  required TtlCache<T> cache,
  required String key,
  required Future<T> Function() fetch,
  bool forceRefresh = false,
  bool allowStaleOnError = true,
  String? reason,
  String? feature,
  String? source,
  RequestDeduper? deduper,
}) async {
  final diagnostics = RequestDiagnostics.instance;
  final endpoint = reason ?? key;

  if (!forceRefresh) {
    final fresh = cache.get(key);
    if (fresh != null) {
      if (kDebugMode) {
        diagnostics.recordLocal(
          method: 'GET',
          endpoint: endpoint,
          outcome: RequestOutcome.cache,
          feature: feature,
          source: source ?? 'cachedRemote',
          operation: reason,
        );
      }
      return Right(fresh);
    }
  }

  final activeDeduper = deduper ?? cachedRemoteDeduper;
  final dedupeKey = RequestDeduper.keyFor(
    method: 'GET',
    path: 'cache:$key',
  );

  return activeDeduper.run<Either<Failure, T>>(
    dedupeKey,
    () async {
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
    },
    feature: feature,
    source: source ?? 'cachedRemote',
    operation: reason,
    method: 'GET',
    endpoint: endpoint,
  );
}

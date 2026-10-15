import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/monitoring/crashlytics_service.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

/// Maps remote exceptions → [Failure] once. Crashlytics is recorded here only
/// for unexpected/server errors so providers can show snackbars without
/// duplicating Crashlytics reports.
Future<Either<Failure, T>> guardRemote<T>(
  NetworkInfo networkInfo,
  Future<T> Function() action, {
  String? reason,
}) async {
  try {
    if (!await networkInfo.isConnected) {
      if (kDebugMode) debugPrint('[guardRemote] offline ${reason ?? ''}');
      return const Left(NetworkFailure());
    }
    return Right(await action());
  } on AuthException catch (error) {
    debugPrint('[guardRemote] AuthException: ${error.message}');
    return Left(AuthFailure(error.message, error.code));
  } on NetworkException catch (error) {
    debugPrint('[guardRemote] NetworkException: ${error.message}');
    return Left(NetworkFailure(error.message));
  } on AppException catch (error, stack) {
    debugPrint('[guardRemote] AppException: ${error.message}');
    await CrashlyticsService.instance.recordError(
      error,
      stack,
      reason: reason ?? 'remote_app_exception',
    );
    return Left(ServerFailure(error.message));
  } catch (error, stack) {
    debugPrint('[guardRemote] Unexpected: $error');
    await CrashlyticsService.instance.recordError(
      error,
      stack,
      reason: reason ?? 'remote_unexpected',
    );
    return Left(ServerFailure(error.toString()));
  }
}

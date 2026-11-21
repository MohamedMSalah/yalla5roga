import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/error/error_blueprint_logger.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/monitoring/crashlytics_service.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';

/// Maps remote exceptions → [Failure] once. Crashlytics + blueprint logging
/// happen here so providers can show snackbars without duplicating reports.
Future<Either<Failure, T>> guardRemote<T>(
  NetworkInfo networkInfo,
  Future<T> Function() action, {
  String? reason,
  ErrorContext? context,
  bool offlineRead = false,
}) async {
  final ctx = context ?? ErrorContext.fromReason(reason);
  try {
    if (!offlineRead && !await networkInfo.isConnected) {
      const failure = NetworkFailure(
        'No internet connection',
        ErrorCodes.network,
      );
      ErrorBlueprintLogger.log(
        error: const NetworkException(),
        context: ctx,
        possibleCause: 'Device offline before request',
      );
      return Left(failure);
    }
    return Right(
      await RequestScope.run(
        action,
        feature: ctx.feature,
        origin: ctx.layer,
        operation: ctx.operation,
        trigger: switch (reason) {
          'discoverViewport' => 'viewport_changed',
          _ => null,
        },
      ),
    );
  } on AppException catch (error, stack) {
    if (OfflineSnapshots.cacheOnly) {
      return Left(ExceptionMapper.toFailure(error));
    }
    if (error.statusCode == null && error is! NetworkException) {
      ErrorBlueprintLogger.log(error: error, context: ctx);
    }
    if (error is! NetworkException && error is! AuthException) {
      await CrashlyticsService.instance.recordError(
        StateError(error.runtimeType.toString()),
        stack,
        reason: reason ?? 'remote_app_exception',
      );
    }
    return Left(ExceptionMapper.toFailure(error));
  } catch (error, stack) {
    ErrorBlueprintLogger.log(error: error, stackTrace: stack, context: ctx);
    await CrashlyticsService.instance.recordError(
      StateError(error.runtimeType.toString()),
      stack,
      reason: reason ?? 'remote_unexpected',
    );
    return Left(ExceptionMapper.toFailure(error));
  }
}

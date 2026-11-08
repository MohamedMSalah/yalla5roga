import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/error_blueprint_logger.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/monitoring/crashlytics_service.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

/// Maps remote exceptions → [Failure] once. Crashlytics + blueprint logging
/// happen here so providers can show snackbars without duplicating reports.
Future<Either<Failure, T>> guardRemote<T>(
  NetworkInfo networkInfo,
  Future<T> Function() action, {
  String? reason,
  ErrorContext? context,
}) async {
  final ctx = context ?? ErrorContext.fromReason(reason);
  try {
    if (!await networkInfo.isConnected) {
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
    return Right(await action());
  } on AppException catch (error, stack) {
    ErrorBlueprintLogger.log(
      error: error,
      stackTrace: stack,
      context: ctx.copyWith(
        httpMethod: error.httpMethod,
        endpoint: error.endpoint,
        statusCode: error.statusCode,
      ),
    );
    if (error is! NetworkException && error is! AuthException) {
      await CrashlyticsService.instance.recordError(
        error,
        stack,
        reason: reason ?? 'remote_app_exception',
      );
    }
    return Left(ExceptionMapper.toFailure(error));
  } catch (error, stack) {
    ErrorBlueprintLogger.log(error: error, stackTrace: stack, context: ctx);
    await CrashlyticsService.instance.recordError(
      error,
      stack,
      reason: reason ?? 'remote_unexpected',
    );
    return Left(ExceptionMapper.toFailure(error));
  }
}

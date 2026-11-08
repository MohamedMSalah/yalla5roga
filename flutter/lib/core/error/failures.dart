import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure([
    this.message = 'Unexpected error',
    this.code,
    this.statusCode,
  ]);

  /// Technical / backend message for developers (never show raw in UI).
  final String message;

  /// Stable code for [FailureMessageMapper] / auth localization.
  final String? code;
  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Server error',
    super.code,
    super.statusCode,
  ]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error', super.code = 'cache']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection',
    super.code = 'network',
    super.statusCode,
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Authentication failed',
    super.code,
    super.statusCode,
  ]);
}

class ValidationFailure extends Failure {
  const ValidationFailure([
    super.message = 'Validation failed',
    super.code = 'validation',
    super.statusCode,
  ]);
}

class ParseFailure extends Failure {
  const ParseFailure([
    super.message = 'Invalid response',
    super.code = 'parse',
    super.statusCode,
  ]);
}

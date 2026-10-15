import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure([this.message = 'Unexpected error']);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed', this.code]);

  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed']);
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/error_sanitizer.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';

void main() {
  const en = L10n(Locale('en'));
  const ar = L10n(Locale('ar'));

  group('ErrorSanitizer', () {
    test('redacts tokens passwords and auth headers', () {
      final cleaned = ErrorSanitizer.sanitize({
        'password': 'secret123',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.abc.def',
        'idToken': 'eyJhbGciOiJIUzI1NiJ9.abc.def',
        'nested': {'refresh_token': 'abc', 'ok': true},
        'message': 'Voting deadline has passed',
      }) as Map;

      expect(cleaned['password'], '***');
      expect(cleaned['Authorization'], '***');
      expect(cleaned['idToken'], '***');
      expect((cleaned['nested'] as Map)['refresh_token'], '***');
      expect((cleaned['nested'] as Map)['ok'], true);
      expect(cleaned['message'], 'Voting deadline has passed');
    });

    test('redacts bearer tokens inside strings', () {
      final text = ErrorSanitizer.stringify(
        'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc.def',
      );
      expect(text.contains('eyJ'), isFalse);
      expect(text.contains('***'), isTrue);
    });
  });

  group('ExceptionMapper', () {
    RequestOptions opts() => RequestOptions(path: '/api/outings/1');

    DioException dio({
      required DioExceptionType type,
      int? status,
      Object? data,
    }) {
      return DioException(
        requestOptions: opts()..method = 'GET',
        type: type,
        response: status == null
            ? null
            : Response(
                requestOptions: opts(),
                statusCode: status,
                data: data ?? {'message': 'backend says hi'},
              ),
        message: 'dio-msg',
      );
    }

    test('maps timeout to NetworkException timeout code', () {
      final app = ExceptionMapper.appExceptionFromDio(
        dio(type: DioExceptionType.receiveTimeout),
      );
      expect(app, isA<NetworkException>());
      expect(app.code, ErrorCodes.timeout);
    });

    test('maps connection error to network', () {
      final app = ExceptionMapper.appExceptionFromDio(
        dio(type: DioExceptionType.connectionError),
      );
      expect(app, isA<NetworkException>());
      expect(app.code, ErrorCodes.network);
    });

    test('maps HTTP statuses to stable codes', () {
      expect(
        ExceptionMapper.appExceptionFromDio(
          dio(type: DioExceptionType.badResponse, status: 401),
        ).code,
        ErrorCodes.unauthorized,
      );
      expect(
        ExceptionMapper.appExceptionFromDio(
          dio(type: DioExceptionType.badResponse, status: 403),
        ).code,
        ErrorCodes.forbidden,
      );
      expect(
        ExceptionMapper.appExceptionFromDio(
          dio(type: DioExceptionType.badResponse, status: 404),
        ).code,
        ErrorCodes.notFound,
      );
      expect(
        ExceptionMapper.appExceptionFromDio(
          dio(type: DioExceptionType.badResponse, status: 409),
        ).code,
        ErrorCodes.conflict,
      );
      expect(
        ExceptionMapper.appExceptionFromDio(
          dio(type: DioExceptionType.badResponse, status: 422),
        ),
        isA<ValidationException>(),
      );
      expect(
        ExceptionMapper.appExceptionFromDio(
          dio(type: DioExceptionType.badResponse, status: 500),
        ).code,
        ErrorCodes.server,
      );
    });

    test('toFailure preserves status and code', () {
      final failure = ExceptionMapper.toFailure(
        const ServerException('boom', ErrorCodes.conflict, 409),
      );
      expect(failure, isA<ServerFailure>());
      expect(failure.code, ErrorCodes.conflict);
      expect(failure.statusCode, 409);
    });

    test('FormatException becomes ParseFailure', () {
      final failure = ExceptionMapper.toFailure(
        const FormatException('bad json'),
      );
      expect(failure, isA<ParseFailure>());
      expect(failure.code, ErrorCodes.parse);
    });
  });

  group('FailureMessageMapper', () {
    test('returns friendly English copy per status/code', () {
      expect(
        FailureMessageMapper.localize(
          const NetworkFailure('offline', ErrorCodes.network),
          en,
        ),
        en.errorNoInternet,
      );
      expect(
        FailureMessageMapper.localize(
          const NetworkFailure('timeout', ErrorCodes.timeout),
          en,
        ),
        en.errorTimeout,
      );
      expect(
        FailureMessageMapper.localize(
          const AuthFailure('x', ErrorCodes.unauthorized, 401),
          en,
        ),
        en.errorSessionExpired,
      );
      expect(
        FailureMessageMapper.localize(
          const ServerFailure('x', ErrorCodes.forbidden, 403),
          en,
        ),
        en.errorForbidden,
      );
      expect(
        FailureMessageMapper.localize(
          const ServerFailure('x', ErrorCodes.notFound, 404),
          en,
        ),
        en.errorNotFound,
      );
      expect(
        FailureMessageMapper.localize(
          const ServerFailure('x', ErrorCodes.conflict, 409),
          en,
        ),
        en.errorConflict,
      );
      expect(
        FailureMessageMapper.localize(
          const ValidationFailure('x', ErrorCodes.validation, 422),
          en,
        ),
        en.errorValidation,
      );
      expect(
        FailureMessageMapper.localize(
          const ServerFailure('x', ErrorCodes.server, 500),
          en,
        ),
        en.errorServer,
      );
      expect(
        FailureMessageMapper.localize(
          const AuthFailure('x', 'invalid-credential'),
          en,
        ),
        en.incorrectEmailOrPassword,
      );
      expect(
        FailureMessageMapper.localize(
          const ParseFailure('FormatException: boom'),
          en,
        ),
        en.errorUnexpected,
      );
    });

    test('returns Arabic for the same codes', () {
      expect(
        FailureMessageMapper.localize(
          const NetworkFailure('offline', ErrorCodes.network),
          ar,
        ),
        ar.errorNoInternet,
      );
      expect(
        FailureMessageMapper.localize(
          const ServerFailure('x', ErrorCodes.server, 500),
          ar,
        ),
        ar.errorServer,
      );
    });

    test('does not expose technical exception text', () {
      final message = FailureMessageMapper.localize(
        const ServerFailure('DioException [bad response]: 500'),
        en,
      );
      expect(message.toLowerCase().contains('dioexception'), isFalse);
      expect(message, en.errorUnexpected);
    });

    test('preserves known business phrases', () {
      expect(
        FailureMessageMapper.localize(
          const ServerFailure('Voting deadline has passed', null, 409),
          en,
        ),
        en.voteLocked,
      );
    });
  });
}

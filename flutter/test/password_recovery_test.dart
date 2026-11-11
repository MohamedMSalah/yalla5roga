import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/password_recovery_provider.dart';

class _Firebase extends Fake implements fb.FirebaseAuth {
  late Invocation request;
  final invocation = Completer<void>();

  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #verifyPhoneNumber) {
      request = call;
      return invocation.future;
    }
    return super.noSuchMethod(call);
  }

  void sent() => (request.namedArguments[#codeSent] as fb.PhoneCodeSent)(
    'firebase-verification',
    7,
  );
}

class _Repository extends Fake implements AuthRepository {
  int starts = 0;
  bool failSms = false;
  String? verifiedRequest;
  String? verifiedSession;

  @override
  Future<Either<Failure, String>> startPasswordRecovery(String phone) async =>
      Right('request-${++starts}');

  @override
  Future<Either<Failure, PhoneVerification>> sendOtp({
    required String phone,
    int? forceResendingToken,
    bool updateCurrentUser = false,
  }) async => failSms
      ? const Left(AuthFailure('SMS unavailable', 'quota-exceeded'))
      : const Right(
          PhoneVerification(verificationId: 'original-session', resendToken: 7),
        );

  @override
  Future<Either<Failure, String>> verifyPasswordRecovery({
    required String requestToken,
    required String verificationId,
    required String smsCode,
  }) async {
    verifiedRequest = requestToken;
    verifiedSession = verificationId;
    return const Right('reset-token');
  }
}

void main() {
  testWidgets('Firebase callback can arrive after the API deadline', (
    tester,
  ) async {
    final firebase = _Firebase();
    final result = FirebaseAuthService(auth: firebase)
        .sendOtp(phone: '+201001234567');
    await tester.pump(const Duration(seconds: 20));
    firebase.sent();
    expect((await result).verificationId, 'firebase-verification');
    firebase.invocation.complete();
    await tester.pump();
  });

  testWidgets(
    'Firebase invocation errors are mapped without waiting for callbacks',
    (tester) async {
      final firebase = _Firebase();
      final result = FirebaseAuthService(auth: firebase)
          .sendOtp(phone: '+201001234567');
      final expectation = expectLater(
        result,
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            'quota-exceeded',
          ),
        ),
      );
      firebase.invocation.completeError(
        fb.FirebaseAuthException(code: 'quota-exceeded'),
      );
      await expectation;
    },
  );

  testWidgets('no callback times out once and late callbacks are ignored', (
    tester,
  ) async {
    final firebase = _Firebase();
    final result = FirebaseAuthService(auth: firebase)
        .sendOtp(phone: '+201001234567');
    final expectation = expectLater(
      result,
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          AuthErrorCodes.timedOut,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 76));
    await expectation;
    firebase.sent();
    firebase.invocation.complete();
    await tester.pump();
  });

  testWidgets('failed resend retains the original recovery proof pair', (
    tester,
  ) async {
    final repository = _Repository();
    var now = DateTime(2026, 11, 11);
    final recovery = PasswordRecoveryProvider(repository, now: () => now);
    expect(await recovery.send('+201001234567'), isTrue);
    now = now.add(const Duration(seconds: 61));
    repository.failSms = true;
    expect(await recovery.send('+201001234567'), isFalse);
    expect(recovery.codeSent, isTrue);
    expect(recovery.busy, isFalse);
    expect(await recovery.verify('123456'), isTrue);
    expect(repository.verifiedRequest, 'request-1');
    expect(repository.verifiedSession, 'original-session');
    recovery.dispose();
  });
}

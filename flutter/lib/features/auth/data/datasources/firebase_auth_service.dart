import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';

/// Firebase Auth adapter. Presentation must not import this type.
class FirebaseAuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  static const _timeout = Duration(seconds: 15);
  final fb.FirebaseAuth _auth;
  String? _pendingPhoneVerificationToken;

  String? get pendingPhoneVerificationToken => _pendingPhoneVerificationToken;

  void clearPhoneVerificationToken() => _pendingPhoneVerificationToken = null;

  fb.User? get currentUser => _auth.currentUser;

  Future<PhoneVerification> sendOtp({
    required String phone,
    int? forceResendingToken,
    bool updateCurrentUser = false,
  }) async {
    final e164 = Validators.normalizePhone(phone);
    if (!Validators.isValidEgyptianPhone(e164)) {
      throw const AuthException(
        'Enter a valid Egyptian phone number',
        AuthErrorCodes.invalidPhone,
      );
    }

    final completer = Completer<PhoneVerification>();
    var acceptingCallbacks = true;

    if (kDebugMode) {
      debugPrint(
        '[FirebaseAuth] verifyPhoneNumber → $e164'
        '${forceResendingToken != null ? ' (resend)' : ''}',
      );
    }

    try {
      final request = _auth.verifyPhoneNumber(
        phoneNumber: e164,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) {
          if (!acceptingCallbacks) return;
          if (updateCurrentUser) {
            unawaited(_applyPhoneUpdate(credential, completer));
            return;
          }
          // Wait for codeSent; do not race signup with another sign-in.
        },
        verificationFailed: (error) {
          if (!acceptingCallbacks) return;
          if (!completer.isCompleted) {
            completer.completeError(_mapFirebaseAuthException(error));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!acceptingCallbacks) return;
          if (!completer.isCompleted) {
            completer.complete(
              PhoneVerification(
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!acceptingCallbacks) return;
          if (!completer.isCompleted) {
            completer.complete(
              PhoneVerification(verificationId: verificationId),
            );
          }
        },
        timeout: const Duration(seconds: 60),
      );

      // Observe both native invocation and callbacks immediately. Android app
      // verification/reCAPTCHA can outlast the normal API request deadline.
      unawaited(
        request.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (!acceptingCallbacks || completer.isCompleted) return;
            completer.completeError(
              error is fb.FirebaseAuthException
                  ? _mapFirebaseAuthException(error)
                  : const AuthException(
                      'Phone verification failed',
                      AuthErrorCodes.verificationFailed,
                    ),
              stack,
            );
          },
        ),
      );
      return await completer.future.timeout(
        const Duration(seconds: 75),
        onTimeout: () => throw const AuthException(
          'Phone verification timed out',
          AuthErrorCodes.timedOut,
        ),
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } finally {
      // Ignore callbacks arriving after a timeout or another completed result.
      acceptingCallbacks = false;
    }
  }

  Future<void> _applyPhoneUpdate(
    fb.PhoneAuthCredential credential,
    Completer<PhoneVerification> completer,
  ) async {
    if (completer.isCompleted) return;
    final user = _auth.currentUser;
    if (user == null) {
      if (!completer.isCompleted) {
        completer.completeError(
          const AuthException(
            'Phone verification failed',
            AuthErrorCodes.verificationFailed,
          ),
        );
      }
      return;
    }
    try {
      await _updatePhoneCredential(user, credential);
      await user.reload();
      if (!completer.isCompleted) {
        completer.complete(
          const PhoneVerification(verificationId: 'auto', autoVerified: true),
        );
      }
    } on fb.FirebaseAuthException catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(_mapFirebaseAuthException(error));
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(
          AuthException(error.toString(), AuthErrorCodes.verificationFailed),
        );
      }
    }
  }

  Future<fb.UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (verificationId.isEmpty) {
      throw const AuthException(
        'Request a verification code first',
        AuthErrorCodes.missingVerification,
      );
    }
    if (smsCode.trim().length < 4) {
      throw const AuthException(
        'Enter a valid verification code',
        AuthErrorCodes.invalidVerificationCode,
      );
    }

    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await _auth.signInWithCredential(credential).timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  /// Establishes a Firebase client session after backend email login/signup.
  ///
  /// Email passwords live in Neon; the API returns a custom token so the app
  /// can refresh Firebase ID tokens for Bearer auth.
  Future<fb.UserCredential> signInWithCustomToken(String customToken) async {
    try {
      return await _auth
          .signInWithCustomToken(customToken.trim())
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  /// Returns the verified OTP ID token for backend signup, then signs out.
  ///
  /// The backend verifies this proof and keeps its UID for the Neon account.
  Future<String> verifyPhoneOtpThenSignOut({
    required String verificationId,
    required String smsCode,
  }) async {
    if (verificationId.isEmpty) {
      throw const AuthException(
        'Request a verification code first',
        AuthErrorCodes.missingVerification,
      );
    }
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final verified = await _auth
          .signInWithCredential(credential)
          .timeout(_timeout);
      final token = await verified.user?.getIdToken(true).timeout(_timeout);
      if (token == null || token.isEmpty) {
        throw const AuthException('Phone verification failed');
      }
      return token;
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } finally {
      await _auth.signOut().timeout(_timeout);
    }
  }

  Future<String> recoveryPhoneProof({
    required String verificationId,
    required String smsCode,
  }) async {
    // An isolated Auth instance prevents OTP from signing the application in,
    // provisioning a Neon profile, or replacing an existing app session.
    final app = await Firebase.initializeApp(
      name: 'password-recovery-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    ).timeout(_timeout);
    final proofAuth = fb.FirebaseAuth.instanceFor(app: app);
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final verified = await proofAuth
          .signInWithCredential(credential)
          .timeout(_timeout);
      final token = await verified.user?.getIdToken(true).timeout(_timeout);
      if (token == null || token.isEmpty) {
        throw const AuthException('Phone verification failed');
      }
      return token;
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } finally {
      // Cleanup must also run if a non-cancellable SDK sign-in completes late.
      try {
        await proofAuth.signOut().timeout(_timeout);
      } finally {
        await app.delete().timeout(_timeout);
      }
    }
  }

  Future<String?> idToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser
          ?.getIdToken(forceRefresh)
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<void> debugPrintSwaggerIdToken() async {}

  bool get hasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  Future<fb.User> _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Not signed in',
        AuthErrorCodes.missingVerification,
      );
    }
    return Future.value(user);
  }

  Future<void> reauthenticateWithPassword({required String password}) async {
    final user = await _requireUser();
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'No email on this account',
        AuthErrorCodes.invalidEmail,
      );
    }
    try {
      final credential = fb.EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<fb.User> updateDisplayName(String name) async {
    final user = await _requireUser();
    try {
      await user.updateDisplayName(name.trim());
      await user.reload();
      return _auth.currentUser ?? user;
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  /// Sends a confirmation link to [newEmail]. Email changes after the user confirms.
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    await reauthenticateWithPassword(password: currentPassword);
    final user = await _requireUser();
    try {
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<fb.User> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticateWithPassword(password: currentPassword);
    final user = await _requireUser();
    try {
      await user.updatePassword(newPassword);
      await user.reload();
      return _auth.currentUser ?? user;
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<fb.User> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    if (verificationId.isEmpty) {
      throw const AuthException(
        'Request a verification code first',
        AuthErrorCodes.missingVerification,
      );
    }
    final user = await _requireUser();
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await _updatePhoneCredential(user, credential);
      await user.reload();
      return _auth.currentUser ?? user;
    } on TimeoutException {
      throw const AuthException(
        'Connection timed out. Please try again.',
        AuthErrorCodes.timedOut,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<void> signOut() async {
    clearPhoneVerificationToken();
    await _auth.signOut().timeout(_timeout);
  }

  Future<void> _updatePhoneCredential(
    fb.User user,
    fb.PhoneAuthCredential credential,
  ) async {
    clearPhoneVerificationToken();
    try {
      await user.updatePhoneNumber(credential);
    } on fb.FirebaseAuthException catch (error) {
      if (error.code != 'credential-already-in-use') rethrow;
      // Older signup versions left the verified phone on an unused OTP UID.
      // Prove ownership without replacing the signed-in application account.
      final app = await Firebase.initializeApp(
        name: 'phone-verification-proof',
        options: Firebase.app().options,
      );
      final proofAuth = fb.FirebaseAuth.instanceFor(app: app);
      try {
        final result = await proofAuth.signInWithCredential(credential);
        final token = await result.user?.getIdToken(true);
        if (token == null || token.isEmpty) {
          throw const AuthException('Phone verification failed');
        }
        _pendingPhoneVerificationToken = token;
      } finally {
        await proofAuth.signOut();
        await app.delete();
      }
    }
  }

  static AuthException _mapFirebaseAuthException(
    fb.FirebaseAuthException error,
  ) {
    final code = error.code;
    switch (code) {
      case 'invalid-phone-number':
        return const AuthException(
          'Enter a valid Egyptian phone number',
          AuthErrorCodes.invalidPhone,
        );
      case 'too-many-requests':
        return const AuthException(
          'Too many attempts. Try again later',
          AuthErrorCodes.tooManyRequests,
        );
      case 'quota-exceeded':
        return const AuthException(
          'SMS quota exceeded. Try again later',
          AuthErrorCodes.quotaExceeded,
        );
      case 'session-expired':
        return const AuthException(
          'Session expired. Request a new code',
          AuthErrorCodes.sessionExpired,
        );
      case 'invalid-verification-code':
        return const AuthException(
          'Invalid verification code',
          AuthErrorCodes.invalidVerificationCode,
        );
      case 'invalid-verification-id':
        return const AuthException(
          'Verification expired. Request a new code',
          AuthErrorCodes.invalidVerificationId,
        );
      case 'network-request-failed':
        return const AuthException(
          'Network error. Check your connection',
          AuthErrorCodes.network,
        );
      case 'app-not-authorized':
        return const AuthException(
          'App is not authorized for phone auth',
          AuthErrorCodes.appNotAuthorized,
        );
      case 'captcha-check-failed':
        return const AuthException(
          'Captcha check failed. Try again',
          AuthErrorCodes.captchaFailed,
        );
      case 'invalid-app-credential':
        return const AuthException(
          'App credential invalid. Check Firebase config',
          AuthErrorCodes.invalidAppCredential,
        );
      case 'invalid-email':
        return const AuthException(
          'Enter a valid email address',
          AuthErrorCodes.invalidEmail,
        );
      case 'email-already-in-use':
        return const AuthException(
          'This email is already registered. Try logging in instead.',
          AuthErrorCodes.emailAlreadyInUse,
        );
      case 'weak-password':
        return const AuthException(
          'Password is too weak',
          AuthErrorCodes.weakPassword,
        );
      case 'user-not-found':
        return const AuthException(
          'No account found for this email',
          AuthErrorCodes.userNotFound,
        );
      case 'wrong-password':
        return const AuthException(
          'Incorrect email or password. Check your details and try again.',
          AuthErrorCodes.wrongPassword,
        );
      case 'invalid-credential':
        return const AuthException(
          'Incorrect email or password. Check your details and try again.',
          AuthErrorCodes.invalidCredential,
        );
      case 'user-disabled':
        return const AuthException(
          'This account has been disabled. Contact support if you need help.',
          AuthErrorCodes.userDisabled,
        );
      case 'operation-not-allowed':
        return const AuthException(
          'This sign-in method is not available right now.',
          AuthErrorCodes.operationNotAllowed,
        );
      case 'account-exists-with-different-credential':
        return const AuthException(
          'An account already exists with a different sign-in method.',
          AuthErrorCodes.accountExistsWithDifferentCredential,
        );
      case 'credential-already-in-use':
        return const AuthException(
          'This phone number is already linked to another account.',
          AuthErrorCodes.credentialAlreadyInUse,
        );
      case 'provider-already-linked':
        return const AuthException(
          'This phone number is already linked to another account.',
          AuthErrorCodes.providerAlreadyLinked,
        );
      case 'requires-recent-login':
        return const AuthException(
          'Please sign in again to continue',
          AuthErrorCodes.requiresRecentLogin,
        );
      default:
        if (kDebugMode) {
          debugPrint('[FirebaseAuth] ${error.code}: ${error.message}');
        }
        return AuthException(
          error.message ?? 'Authentication failed',
          code.isNotEmpty ? code : AuthErrorCodes.verificationFailed,
        );
    }
  }
}

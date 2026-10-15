import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';

/// Firebase Auth adapter. Presentation must not import this type.
class FirebaseAuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

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

    if (kDebugMode) {
      debugPrint(
        '[FirebaseAuth] verifyPhoneNumber → $e164'
        '${forceResendingToken != null ? ' (resend)' : ''}',
      );
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: e164,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) {
          if (updateCurrentUser) {
            unawaited(_applyPhoneUpdate(credential, completer));
            return;
          }
          if (!completer.isCompleted) {
            completer.complete(const PhoneVerification(verificationId: ''));
          }
          unawaited(_auth.signInWithCredential(credential));
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.completeError(_mapFirebaseAuthException(error));
          }
        },
        codeSent: (verificationId, resendToken) {
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
          if (!completer.isCompleted) {
            completer.complete(
              PhoneVerification(verificationId: verificationId),
            );
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }

    try {
      return await completer.future.timeout(
        const Duration(seconds: 70),
        onTimeout: () => throw const AuthException(
          'Phone verification timed out',
          AuthErrorCodes.timedOut,
        ),
      );
    } on AuthException {
      rethrow;
    } catch (error) {
      if (error is AuthException) rethrow;
      throw AuthException(error.toString(), AuthErrorCodes.verificationFailed);
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
      await user.updatePhoneNumber(credential);
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
      return await _auth.signInWithCredential(credential);
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  /// Login with email + password.
  Future<fb.UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  /// Verifies phone OTP first, then links email/password to create the account.
  Future<fb.UserCredential> registerWithEmailAfterPhone({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String verificationId,
    required String smsCode,
  }) async {
    final e164 = Validators.normalizePhone(phone);
    if (!Validators.isValidEgyptianPhone(e164)) {
      throw const AuthException(
        'Enter a valid Egyptian phone number',
        AuthErrorCodes.invalidPhone,
      );
    }
    if (verificationId.isEmpty) {
      throw const AuthException(
        'Request a verification code first',
        AuthErrorCodes.missingVerification,
      );
    }

    try {
      final phoneCredential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final phoneResult = await _auth.signInWithCredential(phoneCredential);
      final user = phoneResult.user;
      if (user == null) {
        throw const AuthException(
          'Phone verification failed',
          AuthErrorCodes.verificationFailed,
        );
      }

      final emailCredential = fb.EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      final linked = await user.linkWithCredential(emailCredential);
      final linkedUser = linked.user ?? user;
      final trimmedName = name.trim();
      if (trimmedName.isNotEmpty) {
        await linkedUser.updateDisplayName(trimmedName);
        await linkedUser.reload();
      }
      return linked;
    } on fb.FirebaseAuthException catch (error) {
      // Leave a half-linked phone session cleared so the user can retry.
      if (_auth.currentUser != null &&
          (error.code == 'email-already-in-use' ||
              error.code == 'credential-already-in-use' ||
              error.code == 'provider-already-linked')) {
        await _auth.signOut();
      }
      throw _mapFirebaseAuthException(error);
    } on AuthException {
      rethrow;
    }
  }

  Future<fb.UserCredential> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthException(
          'Sign in cancelled',
          AuthErrorCodes.cancelled,
        );
      }
      final auth = await account.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on AuthException {
      rethrow;
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } catch (error) {
      throw AuthException(error.toString(), AuthErrorCodes.verificationFailed);
    }
  }

  Future<fb.UserCredential> signInWithApple() async {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw const AuthException(
        'Apple Sign In is not available on this device',
        AuthErrorCodes.appleUnavailable,
      );
    }

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Apple Sign In failed',
          AuthErrorCodes.verificationFailed,
        );
      }

      final oauthCredential = fb.OAuthProvider('apple.com')
          .credential(idToken: idToken, rawNonce: rawNonce);
      final result = await _auth.signInWithCredential(oauthCredential);
      final user = result.user;
      if (user != null) {
        final given = appleCredential.givenName?.trim() ?? '';
        final family = appleCredential.familyName?.trim() ?? '';
        final fullName = '$given $family'.trim();
        if (fullName.isNotEmpty &&
            (user.displayName == null || user.displayName!.trim().isEmpty)) {
          await user.updateDisplayName(fullName);
          await user.reload();
        }
      }
      return result;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthException(
          'Sign in cancelled',
          AuthErrorCodes.cancelled,
        );
      }
      throw AuthException(error.message, AuthErrorCodes.verificationFailed);
    } on AuthException {
      rethrow;
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } catch (error) {
      throw AuthException(error.toString(), AuthErrorCodes.verificationFailed);
    }
  }

  Future<String?> idToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  /// Temporary Swagger helper. Prints a force-refreshed ID token in debug only.
  Future<void> debugPrintSwaggerIdToken() async {
    if (!kDebugMode) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Firebase ID token (Swagger Bearer): no signed-in user');
        return;
      }

      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        debugPrint('Firebase ID token (Swagger Bearer): token was empty');
        return;
      }

      final segments = token.split('.').length;
      debugPrint(
        'Firebase ID token (Swagger Bearer): length=${token.length} segments=$segments',
      );
      debugPrint('Firebase ID token (Swagger Bearer): $token', wrapWidth: 8192);
    } catch (_) {
      debugPrint('Firebase ID token (Swagger Bearer): refresh failed');
    }
  }

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
      await user.updatePhoneNumber(credential);
      await user.reload();
      return _auth.currentUser ?? user;
    } on fb.FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
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

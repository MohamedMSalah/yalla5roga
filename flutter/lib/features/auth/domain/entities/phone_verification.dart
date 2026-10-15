/// Result of phone OTP dispatch (SMS or test-number path).
class PhoneVerification {
  const PhoneVerification({
    required this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });

  final String verificationId;
  final int? resendToken;

  /// Instant verification already applied the number to the signed-in user.
  final bool autoVerified;
}

/// Stable error codes surfaced to [AuthProvider] / UI (match Firebase where possible).
abstract final class AuthErrorCodes {
  static const invalidPhone = 'invalid-phone-number';
  static const tooManyRequests = 'too-many-requests';
  static const quotaExceeded = 'quota-exceeded';
  static const sessionExpired = 'session-expired';
  static const invalidVerificationCode = 'invalid-verification-code';
  static const invalidVerificationId = 'invalid-verification-id';
  static const network = 'network-request-failed';
  static const verificationFailed = 'verification-failed';
  static const timedOut = 'verification-timeout';
  static const missingVerification = 'missing-verification';
  static const appNotAuthorized = 'app-not-authorized';
  static const captchaFailed = 'captcha-check-failed';
  static const missingClientId = 'missing-client-identifier';
  static const invalidAppCredential = 'invalid-app-credential';
  static const invalidEmail = 'invalid-email';
  static const emailAlreadyInUse = 'email-already-in-use';
  static const weakPassword = 'weak-password';
  static const userNotFound = 'user-not-found';
  static const wrongPassword = 'wrong-password';
  static const invalidCredential = 'invalid-credential';
  static const userDisabled = 'user-disabled';
  static const operationNotAllowed = 'operation-not-allowed';
  static const accountExistsWithDifferentCredential =
      'account-exists-with-different-credential';
  static const credentialAlreadyInUse = 'credential-already-in-use';
  static const providerAlreadyLinked = 'provider-already-linked';
  static const cancelled = 'cancelled';
  static const appleUnavailable = 'apple-unavailable';
  static const requiresRecentLogin = 'requires-recent-login';
}

/// Backward-compatible aliases used by the Firebase datasource.
typedef PhoneAuthErrorCodes = AuthErrorCodes;
typedef FirebasePhoneVerification = PhoneVerification;
typedef FirebasePhoneAuthCodes = AuthErrorCodes;

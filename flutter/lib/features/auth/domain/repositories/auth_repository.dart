import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, String>> startPasswordRecovery(String phone);
  Future<Either<Failure, String>> verifyPasswordRecovery({
    required String requestToken,
    required String verificationId,
    required String smsCode,
  });
  Future<Either<Failure, void>> resetRecoveredPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  });

  Future<Either<Failure, User>> login({
    required String phone,
    required String password,
  });

  /// Creates an account after the phone OTP has been verified.
  Future<Either<Failure, User>> register({
    required String name,
    required String password,
    required String phone,
    required String verificationId,
    required String smsCode,
  });

  Future<Either<Failure, User>> getCachedUser();

  /// Refreshes Neon profile fields (`created_at`, `has_password`, …).
  Future<Either<Failure, User>> refreshProfile();

  Future<Either<Failure, User>> saveUser(User user);

  /// Updates display name and/or local profile image path, then refreshes cache.
  Future<Either<Failure, User>> updateProfileData({
    String? name,
    String? imageUrl,
  });

  /// Confirms the signed-in user's password with Firebase (email/password accounts).
  Future<Either<Failure, void>> confirmPassword({required String password});

  /// Syncs changed profile fields to the app backend.
  Future<Either<Failure, User>> syncProfileToBackend({
    String? name,
    String? phone,
    String? imageUrl,
  });

  Future<Either<Failure, User>> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<Failure, User>> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
    required String phone,
  });

  /// Legacy Firebase email/password provider (rare; Neon is canonical).
  bool get hasPasswordProvider;

  /// True when Neon has a password hash, or Firebase still has a password provider.
  bool get hasPassword;

  Future<Either<Failure, void>> logout();

  bool get hasFirebaseSession;

  Future<Either<Failure, PhoneVerification>> sendOtp({
    required String phone,
    int? forceResendingToken,
    bool updateCurrentUser = false,
  });

  /// Verifies SMS OTP, optionally updates display name, caches [User], returns it.
  Future<Either<Failure, User>> verifyOtpAndCache({
    required String verificationId,
    required String smsCode,
    required String phone,
    String? name,
  });

  Future<Either<Failure, String?>> idToken({bool forceRefresh = false});

  /// Debug-only Swagger helper. Implementations must not log the token in release.
  Future<void> debugPrintSwaggerIdToken();

  Future<Either<Failure, void>> signOutFirebase();
}

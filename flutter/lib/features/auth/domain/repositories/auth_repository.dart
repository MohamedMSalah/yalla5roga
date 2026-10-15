import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Creates an account after the phone OTP has been verified.
  Future<Either<Failure, User>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String verificationId,
    required String smsCode,
  });

  Future<Either<Failure, User>> signInWithGoogle();

  Future<Either<Failure, User>> signInWithApple();

  Future<Either<Failure, User>> getCachedUser();

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
    String? email,
    String? phone,
    String? imageUrl,
  });

  /// Email/password accounts only. Sends a confirmation link to the new email.
  Future<Either<Failure, void>> requestEmailChange({
    required String newEmail,
    required String currentPassword,
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

  bool get hasPasswordProvider;

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

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/data/models/auth_session_model.dart';
import 'package:yalla_5roga/features/auth/data/models/user_model.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';

mixin _AuthFirebaseMixin on AuthRepository {
  FirebaseAuthService get firebaseAuth;
  AuthLocalDataSource get local;

  @override
  bool get hasFirebaseSession => firebaseAuth.currentUser != null;

  @override
  Future<Either<Failure, PhoneVerification>> sendOtp({
    required String phone,
    int? forceResendingToken,
    bool updateCurrentUser = false,
  }) async {
    try {
      final result = await firebaseAuth.sendOtp(
        phone: phone,
        forceResendingToken: forceResendingToken,
        updateCurrentUser: updateCurrentUser,
      );
      if (result.autoVerified) {
        final user = firebaseAuth.currentUser;
        if (user != null) {
          await user.reload();
          await _cacheFirebaseUser(
            firebaseAuth.currentUser ?? user,
            fallbackPhone: phone,
          );
        }
      }
      return Right(result);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } catch (_) {
      return const Left(AuthFailure('Phone verification failed'));
    }
  }

  @override
  Future<Either<Failure, User>> verifyOtpAndCache({
    required String verificationId,
    required String smsCode,
    required String phone,
    String? name,
  }) async {
    try {
      final credential = await firebaseAuth.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return const Left(AuthFailure('Verification failed'));
      }

      if (name != null && name.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(name.trim());
      }

      return Right(
        await _cacheFirebaseUser(
          firebaseUser,
          fallbackPhone: phone,
          name: name,
        ),
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } catch (_) {
      return const Left(AuthFailure('Invalid verification code'));
    }
  }

  @override
  Future<Either<Failure, String?>> idToken({bool forceRefresh = false}) async {
    try {
      return Right(await firebaseAuth.idToken(forceRefresh: forceRefresh));
    } catch (_) {
      return const Left(AuthFailure('Unable to refresh token'));
    }
  }

  @override
  Future<void> debugPrintSwaggerIdToken() {
    return firebaseAuth.debugPrintSwaggerIdToken();
  }

  @override
  Future<Either<Failure, void>> signOutFirebase() async {
    try {
      await firebaseAuth.signOut();
      return const Right(null);
    } catch (_) {
      return const Left(AuthFailure('Sign out failed'));
    }
  }

  Future<UserModel> _cacheFirebaseUser(
    fb.User firebaseUser, {
    String? fallbackPhone,
    String? name,
    String? imageUrl,
    bool forceRefreshToken = false,
    DateTime? createdAt,
    bool? hasPassword,
  }) async {
    final token =
        await firebaseAuth.idToken(forceRefresh: forceRefreshToken) ?? '';
    final phone = firebaseUser.phoneNumber ?? fallbackPhone ?? '';
    final resolvedName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (firebaseUser.displayName?.trim().isNotEmpty == true
              ? firebaseUser.displayName!.trim()
              : (firebaseUser.email?.trim().isNotEmpty == true
                    ? firebaseUser.email!.trim()
                    : (phone.isNotEmpty ? phone : 'User')));

    UserModel? cached;
    try {
      cached = await local.getCachedUser();
    } catch (_) {}

    String? resolvedImage = imageUrl ?? firebaseUser.photoURL;
    if ((resolvedImage == null || resolvedImage.isEmpty) &&
        cached?.imageUrl?.trim().isNotEmpty == true) {
      resolvedImage = cached!.imageUrl;
    }

    final phoneVerified = (firebaseUser.phoneNumber ?? '').trim().isNotEmpty;

    final user = UserModel(
      id: firebaseUser.uid,
      name: resolvedName,
      phone: phone.isNotEmpty ? phone : (cached?.phone ?? ''),
      email: firebaseUser.email ?? cached?.email,
      token: token,
      imageUrl: resolvedImage,
      createdAt: createdAt ?? cached?.createdAt,
      hasPassword: hasPassword ?? cached?.hasPassword ?? false,
      phoneVerified: phoneVerified,
    );
    await local.cacheUser(user);
    return user;
  }

  Future<UserModel> _mergeBackendProfile(
    UserModel profile, {
    String? token,
    String? fallbackPhone,
    bool? phoneVerified,
  }) async {
    UserModel? cached;
    try {
      cached = await local.getCachedUser();
    } catch (_) {}

    final firebasePhone = firebaseAuth.currentUser?.phoneNumber?.trim() ?? '';
    final verified =
        phoneVerified ??
        (firebasePhone.isNotEmpty || (cached?.phoneVerified ?? false));

    final merged = UserModel(
      id: profile.id.isNotEmpty
          ? profile.id
          : (firebaseAuth.currentUser?.uid ?? cached?.id ?? ''),
      name: profile.name.isNotEmpty ? profile.name : (cached?.name ?? 'User'),
      phone: profile.phone.isNotEmpty
          ? profile.phone
          : (fallbackPhone ?? cached?.phone ?? ''),
      email: profile.email ?? cached?.email,
      token: token ?? cached?.token,
      imageUrl: profile.imageUrl ?? cached?.imageUrl,
      createdAt: profile.createdAt ?? cached?.createdAt,
      hasPassword: profile.hasPassword || (cached?.hasPassword ?? false),
      phoneVerified: verified,
    );
    await local.cacheUser(merged);
    return merged;
  }

  Future<Either<Failure, User>> _fromFirebaseCredential(
    Future<fb.UserCredential> Function() action, {
    String? name,
    String? fallbackPhone,
    bool forceRefreshToken = true,
  }) async {
    try {
      final credential = await action();
      final firebaseUser = credential.user ?? firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Left(AuthFailure('Authentication failed'));
      }
      // Reload so linked email/phone/displayName are fresh.
      await firebaseUser.reload();
      final refreshed = firebaseAuth.currentUser ?? firebaseUser;
      return Right(
        await _cacheFirebaseUser(
          refreshed,
          fallbackPhone: fallbackPhone,
          name: name,
          forceRefreshToken: forceRefreshToken,
        ),
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } catch (_) {
      return const Left(AuthFailure('Authentication failed'));
    }
  }
}

class AuthRepositoryImpl extends AuthRepository with _AuthFirebaseMixin {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.networkInfo,
    required this.firebaseAuth,
  });

  final AuthRemoteDataSource remote;
  @override
  final AuthLocalDataSource local;
  final NetworkInfo networkInfo;
  @override
  final FirebaseAuthService firebaseAuth;

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    // Email/password → backend (Neon). Firebase only receives a custom token.
    return _emailPasswordSession(
      () => remote.login(email: email, password: password),
    );
  }

  @override
  Future<Either<Failure, User>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String verificationId,
    required String smsCode,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      // OTP stays on Firebase; password account is created on the backend.
      await firebaseAuth.verifyPhoneOtpThenSignOut(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return _emailPasswordSession(
        () => remote.signup(
          name: name,
          email: email,
          password: password,
          phone: phone,
        ),
        fallbackName: name,
        fallbackPhone: phone,
        fallbackEmail: email,
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on AppException catch (error) {
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message)
            : ServerFailure(error.message),
      );
    } catch (_) {
      return const Left(AuthFailure('Registration failed'));
    }
  }

  Future<Either<Failure, User>> _emailPasswordSession(
    Future<AuthSessionModel> Function() createSession, {
    String? fallbackName,
    String? fallbackPhone,
    String? fallbackEmail,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final session = await createSession();
      await firebaseAuth.signInWithCustomToken(session.customToken);
      await firebaseAuth.idToken(forceRefresh: true);

      final profile = session.user;
      final firebaseUser = firebaseAuth.currentUser;
      final uid = firebaseUser?.uid ?? session.uid;
      final token = await firebaseAuth.idToken() ?? session.idToken;

      final merged = await _mergeBackendProfile(
        UserModel(
          id: uid.isNotEmpty ? uid : (profile?.id ?? ''),
          name: (profile != null && profile.name.isNotEmpty)
              ? profile.name
              : (fallbackName?.trim().isNotEmpty == true
                    ? fallbackName!.trim()
                    : (firebaseUser?.displayName?.trim().isNotEmpty == true
                          ? firebaseUser!.displayName!.trim()
                          : 'User')),
          phone: (profile != null && profile.phone.isNotEmpty)
              ? profile.phone
              : (fallbackPhone ?? ''),
          email: profile?.email ?? fallbackEmail ?? firebaseUser?.email,
          token: token,
          imageUrl: profile?.imageUrl ?? firebaseUser?.photoURL,
          createdAt: profile?.createdAt,
          hasPassword: profile?.hasPassword ?? true,
          phoneVerified: (firebaseUser?.phoneNumber ?? '').trim().isNotEmpty,
        ),
        token: token,
        fallbackPhone: fallbackPhone,
      );
      return Right(merged);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } on AppException catch (error) {
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message)
            : ServerFailure(error.message),
      );
    } catch (_) {
      return const Left(AuthFailure('Authentication failed'));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    final signedIn = await _fromFirebaseCredential(
      firebaseAuth.signInWithGoogle,
    );
    // Upsert application user on first social sign-in (backend keys by token UID).
    return signedIn.fold(Left.new, _provisionBackendUser);
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    final signedIn = await _fromFirebaseCredential(
      firebaseAuth.signInWithApple,
    );
    return signedIn.fold(Left.new, _provisionBackendUser);
  }

  /// Creates / upserts the PostgreSQL `users` row. Identity is the verified
  /// Firebase UID from the Bearer token — never sent as a trusted body field.
  /// Passwords are never sent; Firebase owns credentials.
  Future<Either<Failure, User>> _provisionBackendUser(User user) async {
    if (!await networkInfo.isConnected) {
      return Right(user);
    }
    try {
      await firebaseAuth.idToken(forceRefresh: true);
      final model = await remote.syncUser(
        name: user.name,
        email: user.email,
        phone: user.phone.isEmpty ? null : user.phone,
        imageUrl: user.imageUrl,
      );
      final token = await firebaseAuth.idToken() ?? user.token;
      final uid = firebaseAuth.currentUser?.uid ?? user.id;
      final merged = await _mergeBackendProfile(
        UserModel(
          id: uid,
          name: model.name.isNotEmpty ? model.name : user.name,
          phone: model.phone.isNotEmpty ? model.phone : user.phone,
          email: model.email ?? user.email,
          token: token,
          imageUrl: model.imageUrl ?? user.imageUrl,
          createdAt: model.createdAt ?? user.createdAt,
          hasPassword: model.hasPassword || user.hasPassword,
          phoneVerified: user.phoneVerified,
        ),
        token: token,
        phoneVerified:
            (firebaseAuth.currentUser?.phoneNumber ?? '').trim().isNotEmpty ||
            user.phoneVerified,
      );
      return Right(merged);
    } on AppException {
      // Keep the Firebase session; placeholder backends may fail until Node is live.
      return Right(UserModel.fromEntity(user));
    } catch (_) {
      return Right(UserModel.fromEntity(user));
    }
  }

  @override
  Future<Either<Failure, User>> getCachedUser() async {
    try {
      return Right(await local.getCachedUser());
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    }
  }

  @override
  Future<Either<Failure, User>> refreshProfile() async {
    if (!await networkInfo.isConnected) {
      return getCachedUser();
    }
    try {
      await firebaseAuth.idToken(forceRefresh: true);
      final model = await remote.getProfile();
      final token = await firebaseAuth.idToken();
      return Right(
        await _mergeBackendProfile(
          model,
          token: token,
          phoneVerified: (firebaseAuth.currentUser?.phoneNumber ?? '')
              .trim()
              .isNotEmpty,
        ),
      );
    } on AppException catch (error) {
      final cached = await getCachedUser();
      return cached.fold(
        (_) => Left(
          error is NetworkException
              ? NetworkFailure(error.message)
              : ServerFailure(error.message),
        ),
        Right.new,
      );
    } catch (_) {
      return getCachedUser();
    }
  }

  @override
  Future<Either<Failure, User>> saveUser(User user) async {
    try {
      final model = UserModel.fromEntity(user);
      await local.cacheUser(model);
      return Right(model);
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    }
  }

  @override
  bool get hasPasswordProvider => firebaseAuth.hasPasswordProvider;

  @override
  bool get hasPassword => firebaseAuth.hasPasswordProvider;

  @override
  Future<Either<Failure, User>> updateProfileData({
    String? name,
    String? imageUrl,
  }) async {
    try {
      fb.User? firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Left(AuthFailure('Not signed in'));
      }
      if (name != null && name.trim().isNotEmpty) {
        firebaseUser = await firebaseAuth.updateDisplayName(name.trim());
      }
      return Right(
        await _cacheFirebaseUser(
          firebaseUser,
          name: name,
          imageUrl: imageUrl,
          fallbackPhone: firebaseUser.phoneNumber,
        ),
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } catch (_) {
      return const Left(AuthFailure('Could not update profile'));
    }
  }

  @override
  Future<Either<Failure, void>> confirmPassword({
    required String password,
  }) async {
    try {
      if (firebaseAuth.hasPasswordProvider) {
        await firebaseAuth.reauthenticateWithPassword(password: password);
        return const Right(null);
      }
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      await firebaseAuth.idToken(forceRefresh: true);
      await remote.verifyPassword(password: password);
      return const Right(null);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on AppException catch (error) {
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message)
            : AuthFailure(error.message, AuthErrorCodes.invalidCredential),
      );
    } catch (_) {
      return const Left(AuthFailure('Incorrect password'));
    }
  }

  @override
  Future<Either<Failure, User>> syncProfileToBackend({
    String? name,
    String? email,
    String? phone,
    String? imageUrl,
  }) async {
    if (name == null && email == null && phone == null && imageUrl == null) {
      final cached = await getCachedUser();
      return cached;
    }
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      // Fresh token after email/phone/password Firebase updates.
      final token = await firebaseAuth.idToken(forceRefresh: true);
      final model = await remote.updateProfile(
        name: name,
        email: email,
        phone: phone,
        imageUrl: imageUrl,
      );
      return Right(
        await _mergeBackendProfile(
          model,
          token: token,
          phoneVerified: (firebaseAuth.currentUser?.phoneNumber ?? '')
              .trim()
              .isNotEmpty,
        ),
      );
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } on AppException catch (error) {
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message)
            : ServerFailure(error.message),
      );
    } catch (_) {
      return const Left(ServerFailure('Could not sync profile'));
    }
  }

  @override
  Future<Either<Failure, void>> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      await firebaseAuth.requestEmailChange(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );
      return const Right(null);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } catch (_) {
      return const Left(AuthFailure('Could not update email'));
    }
  }

  @override
  Future<Either<Failure, User>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (firebaseAuth.hasPasswordProvider) {
        final firebaseUser = await firebaseAuth.updatePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        return Right(await _cacheFirebaseUser(firebaseUser));
      }
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }
      await firebaseAuth.idToken(forceRefresh: true);
      await remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final cached = await getCachedUser();
      return cached.fold(Left.new, (user) async {
        final updated = UserModel.fromEntity(user.copyWith(hasPassword: true));
        await local.cacheUser(updated);
        return Right(updated);
      });
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } on AppException catch (error) {
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message)
            : AuthFailure(error.message, AuthErrorCodes.invalidCredential),
      );
    } catch (_) {
      return const Left(AuthFailure('Could not update password'));
    }
  }

  @override
  Future<Either<Failure, User>> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
    required String phone,
  }) async {
    try {
      final firebaseUser = await firebaseAuth.updatePhoneNumber(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return Right(
        await _cacheFirebaseUser(firebaseUser, fallbackPhone: phone),
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } catch (_) {
      return const Left(AuthFailure('Could not update phone number'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await firebaseAuth.signOut();
      await local.clear();
      return const Right(null);
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } catch (_) {
      try {
        await local.clear();
        return const Right(null);
      } on CacheException catch (error) {
        return Left(CacheFailure(error.message));
      }
    }
  }
}

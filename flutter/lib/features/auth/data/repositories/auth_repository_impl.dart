import 'dart:async';
import 'dart:convert';

import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
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
  }) async {
    UserModel? cached;
    try {
      cached = await local.getCachedUser();
    } catch (_) {}

    final firebasePhone = firebaseAuth.currentUser?.phoneNumber?.trim() ?? '';
    final profilePhone = profile.phone.isNotEmpty
        ? profile.phone
        : (fallbackPhone ?? cached?.phone ?? '');
    final verified =
        firebasePhone.isNotEmpty &&
        Validators.normalizePhone(firebasePhone) ==
            Validators.normalizePhone(profilePhone);

    final merged = UserModel(
      id: profile.id.isNotEmpty
          ? profile.id
          : (firebaseAuth.currentUser?.uid ?? cached?.id ?? ''),
      name: profile.name.isNotEmpty ? profile.name : (cached?.name ?? 'User'),
      phone: profilePhone,
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

  Future<Either<Failure, T>> _recovery<T>(Future<T> Function() action) async {
    try {
      if (!await networkInfo.isConnected) return const Left(NetworkFailure());
      return Right(await action());
    } on TimeoutException {
      return const Left(
        NetworkFailure('Connection timed out', ErrorCodes.timeout),
      );
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  @override
  Future<Either<Failure, String>> startPasswordRecovery(String phone) =>
      _recovery(() async {
        final data = await remote.recovery(ApiConstants.recoveryStart, {
          'phone': phone,
        });
        return data['requestToken'] as String;
      });

  @override
  Future<Either<Failure, String>> verifyPasswordRecovery({
    required String requestToken,
    required String verificationId,
    required String smsCode,
  }) => _recovery(() async {
    final proof = await firebaseAuth.recoveryPhoneProof(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final data = await remote.recovery(ApiConstants.recoveryVerify, {
      'requestToken': requestToken,
      'phoneVerificationToken': proof,
    });
    return data['resetToken'] as String;
  });

  @override
  Future<Either<Failure, void>> resetRecoveredPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) => _recovery(() async {
    await remote.recovery(ApiConstants.recoveryReset, {
      'resetToken': resetToken,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  });

  final _accountSyncs = RequestDeduper();
  final AuthRemoteDataSource remote;
  @override
  final AuthLocalDataSource local;
  final NetworkInfo networkInfo;
  @override
  final FirebaseAuthService firebaseAuth;

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    required String password,
  }) async {
    // Phone/password → backend (Neon). Firebase only receives a custom token.
    return _emailPasswordSession(
      () => remote.login(phone: phone, password: password),
    );
  }

  @override
  Future<Either<Failure, User>> register({
    required String name,
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
      final phoneProof = await firebaseAuth.verifyPhoneOtpThenSignOut(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return _emailPasswordSession(
        () => remote.signup(
          name: name,
          password: password,
          phone: phone,
          phoneVerificationToken: phoneProof,
        ),
        fallbackName: name,
        fallbackPhone: phone,
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, error.code));
    } on AppException catch (error) {
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message, error.code, error.statusCode)
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
            ? NetworkFailure(error.message, error.code, error.statusCode)
            : ServerFailure(error.message),
      );
    } catch (_) {
      return const Left(AuthFailure('Authentication failed'));
    }
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
          token: token,
          imageUrl: model.imageUrl ?? user.imageUrl,
          createdAt: model.createdAt ?? user.createdAt,
          hasPassword: model.hasPassword || user.hasPassword,
          phoneVerified: user.phoneVerified,
        ),
        token: token,
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
      final cached = await local.getCachedUser();
      if (firebaseAuth.currentUser?.uid != cached.id) {
        return const Left(
          CacheFailure('Cached profile belongs to another session'),
        );
      }
      return Right(cached);
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
      await firebaseAuth.idToken();
      final uid = firebaseAuth.currentUser?.uid;
      if (uid == null) return const Left(AuthFailure());
      final model = await remote.getProfile();
      if (firebaseAuth.currentUser?.uid != uid || model.id != uid) {
        return const Left(AuthFailure());
      }
      final token = await firebaseAuth.idToken();
      return Right(await _mergeBackendProfile(model, token: token));
    } on AppException catch (error) {
      final cached = await getCachedUser();
      return cached.fold(
        (_) => Left(
          error is NetworkException
              ? NetworkFailure(error.message, error.code, error.statusCode)
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
            ? NetworkFailure(error.message, error.code, error.statusCode)
            : error is AuthException
            ? AuthFailure(error.message, error.code, error.statusCode)
            : ServerFailure(error.message, error.code, error.statusCode),
      );
    } catch (_) {
      return const Left(AuthFailure('Incorrect password'));
    }
  }

  @override
  Future<Either<Failure, User>> syncProfileToBackend({
    String? name,
    String? phone,
    String? imageUrl,
  }) => _accountSyncs.run(
    jsonEncode([firebaseAuth.currentUser?.uid, name, phone, imageUrl]),
    () => _syncProfileToBackend(name: name, phone: phone, imageUrl: imageUrl),
    endpoint: '/api/users/sync',
    method: 'POST',
  );

  Future<Either<Failure, User>> _syncProfileToBackend({
    String? name,
    String? phone,
    String? imageUrl,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final uid = firebaseAuth.currentUser?.uid;
      if (uid == null) return const Left(AuthFailure());
      // Fresh identity claims after phone verification.
      var token = await firebaseAuth.idToken(forceRefresh: true);
      final phoneProof = firebaseAuth.pendingPhoneVerificationToken;
      final model = name == null && phone == null && imageUrl == null
          ? await remote.syncUser()
          : phone != null
          ? await remote.syncUser(
              phone: phone,
              phoneVerificationToken: phoneProof,
            )
          : await remote.updateProfile(name: name, imageUrl: imageUrl);
      if (firebaseAuth.currentUser?.uid != uid || model.id != uid)
        return const Left(AuthFailure());
      if (phone != null) {
        firebaseAuth.clearPhoneVerificationToken();
        if (phoneProof != null) {
          await firebaseAuth.currentUser?.reload();
          token = await firebaseAuth.idToken(forceRefresh: true);
        }
      }
      return Right(await _mergeBackendProfile(model, token: token));
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } on AppException catch (error) {
      if (phone != null && firebaseAuth.pendingPhoneVerificationToken != null) {
        // The backend may have bound the phone before its response was lost.
        // A retry then uses the canonical identity's claims instead of stale proof.
        try {
          await firebaseAuth.currentUser?.reload();
          if (Validators.normalizePhone(
                firebaseAuth.currentUser?.phoneNumber ?? '',
              ) ==
              Validators.normalizePhone(phone)) {
            firebaseAuth.clearPhoneVerificationToken();
          }
        } catch (_) {}
      }
      return Left(
        error is NetworkException
            ? NetworkFailure(error.message, error.code, error.statusCode)
            : ServerFailure(error.message),
      );
    } catch (_) {
      return const Left(ServerFailure('Could not sync profile'));
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
            ? NetworkFailure(error.message, error.code, error.statusCode)
            : error is AuthException
            ? AuthFailure(error.message, error.code, error.statusCode)
            : ServerFailure(error.message, error.code, error.statusCode),
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

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/error/error_blueprint_logger.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/monitoring/analytics_service.dart';
import 'package:yalla_5roga/core/monitoring/crashlytics_service.dart';
import 'package:yalla_5roga/core/monitoring/performance_service.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.repository});

  final AuthRepository repository;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;
  bool _isLogin = true;
  bool _otpSent = false;
  bool _phoneAutoVerified = false;
  bool _agreeTerms = false;
  String? _verificationId;
  int? _resendToken;
  String? _pendingPhone;
  bool _restoredAccountNeedsSync = false;
  Future<bool>? _accountSynchronization;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  bool get isAuthenticated => _user != null;
  bool get isLogin => _isLogin;
  bool get otpSent => _otpSent;
  bool get phoneAutoVerified => _phoneAutoVerified;
  bool get agreeTerms => _agreeTerms;
  String? get pendingPhone => _pendingPhone;

  void setLogin(bool value) {
    if (_isLogin == value && !_otpSent) return;
    _isLogin = value;
    resetOtp();
  }

  void setAgreeTerms(bool value) {
    if (_agreeTerms == value) return;
    _agreeTerms = value;
    notifyListeners();
  }

  void resetOtp() {
    _otpSent = false;
    _phoneAutoVerified = false;
    _verificationId = null;
    _pendingPhone = null;
    _resendToken = null;
    notifyListeners();
  }

  void resetAuthForm({bool toLogin = true}) {
    if (toLogin) _isLogin = true;
    _otpSent = false;
    _phoneAutoVerified = false;
    _verificationId = null;
    _resendToken = null;
    _pendingPhone = null;
    _agreeTerms = false;
    _errorMessage = null;
    _errorCode = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final hasFirebase = repository.hasFirebaseSession;
    final result = await repository.getCachedUser();
    _user = result.fold<User?>((_) => null, (user) => user);
    if (!hasFirebase || _user == null) {
      _user = null;
      await repository.logout();
    }
    _restoredAccountNeedsSync = _user != null;
    notifyListeners();
  }

  /// Deferred until cached shell content is visible. A successful restore sync
  /// runs once; later resumes and profile reads cannot repeat it.
  Future<bool> synchronizeRestoredAccount() {
    if (!_restoredAccountNeedsSync || _user == null) return Future.value(false);
    return _accountSynchronization ??= _synchronizeRestoredAccount()
        .whenComplete(() => _accountSynchronization = null);
  }

  Future<bool> _synchronizeRestoredAccount() async {
    final uid = _user?.id;
    final result = await repository.syncProfileToBackend();
    if (_user?.id != uid) return false;
    return result.fold((_) => false, (user) {
      _restoredAccountNeedsSync = false;
      _user = user;
      notifyListeners();
      return true;
    });
  }

  Future<bool> sendOtp(String phone, {bool updateCurrentUser = false}) async {
    if (_isLoading) return false;

    final e164 = Validators.normalizePhone(phone);
    if (!Validators.isValidEgyptianPhone(e164)) {
      _errorCode = AuthErrorCodes.invalidPhone;
      _errorMessage = 'Enter a valid Egyptian phone number';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
    final samePhone = _pendingPhone == e164;
    final result = await repository.sendOtp(
      phone: e164,
      forceResendingToken: samePhone ? _resendToken : null,
      updateCurrentUser: updateCurrentUser,
    );

    final sent = result.fold(
      (failure) {
        _errorCode = failure.code ?? (failure is AuthFailure ? AuthErrorCodes.verificationFailed : 'unexpected');
        _errorMessage = failure.message;
        _reportFailure(failure, context: 'sendOtp');
        notifyListeners();
        return false;
      },
      (verification) {
        if (verification.autoVerified) {
          _phoneAutoVerified = true;
          _otpSent = true;
          _verificationId = null;
          _pendingPhone = e164;
            notifyListeners();
          return true;
        }
        if (verification.verificationId.isEmpty) {
            _errorCode = AuthErrorCodes.verificationFailed;
          _errorMessage = 'Phone verification failed';
          _reportFailure(
            const AuthFailure('Phone verification failed'),
            context: 'sendOtp',
          );
          notifyListeners();
          return false;
        }
        _verificationId = verification.verificationId;
        _resendToken =
            verification.resendToken ?? (samePhone ? _resendToken : null);
        _pendingPhone = e164;
        _otpSent = true;
        _phoneAutoVerified = false;
        notifyListeners();
        return true;
      },
    );
    if (sent && _phoneAutoVerified) {
      final cached = await repository.getCachedUser();
      cached.fold((_) {}, (user) {
        _user = user;
        notifyListeners();
      });
    }
    return sent;
    } catch (_) {
      _errorCode = 'unexpected';
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendOtp(String phone) => sendOtp(phone);

  Future<bool> login({required String phone, required String password}) {
    unawaited(
      AnalyticsService.instance.loginStarted(isLogin: true, method: 'email'),
    );
    return PerformanceService.instance.trace(
      'login_phone',
      () => _run(
        () => repository.login(phone: phone.trim(), password: password),
        context: 'login',
      ),
    );
  }

  Future<bool> register({
    required String name,
    required String password,
    required String phone,
    required String smsCode,
  }) async {
    final e164 = Validators.normalizePhone(phone);
    final verificationId = _verificationId;
    final pendingPhone = _pendingPhone;
    if (verificationId == null ||
        pendingPhone == null ||
        pendingPhone != e164) {
      _errorCode = AuthErrorCodes.missingVerification;
      _errorMessage = 'Request a verification code first';
      notifyListeners();
      return false;
    }

    unawaited(
      AnalyticsService.instance.loginStarted(isLogin: false, method: 'phone'),
    );
    return PerformanceService.instance.trace(
      'register_phone',
      () => _run(
        () => repository.register(
          name: name.trim(),
          password: password,
          phone: pendingPhone,
          verificationId: verificationId,
          smsCode: smsCode,
        ),
        context: 'register',
      ),
    );
  }

  /// Kept for phone-only verify flows (legacy / deep links). Prefer [register].
  Future<bool> verifyOtp({required String smsCode, String? name}) async {
    final verificationId = _verificationId;
    final phone = _pendingPhone;
    if (verificationId == null || phone == null) {
      _errorCode = AuthErrorCodes.missingVerification;
      _errorMessage = 'Request a verification code first';
      notifyListeners();
      return false;
    }

    return PerformanceService.instance.trace(
      'login_verify_otp',
      () => _run(
        () => repository.verifyOtpAndCache(
          verificationId: verificationId,
          smsCode: smsCode,
          phone: phone,
          name: name,
        ),
        context: 'verifyOtp',
      ),
    );
  }

  bool get hasPasswordProvider => repository.hasPasswordProvider;

  /// Neon password accounts or legacy Firebase password provider.
  bool get hasPassword =>
      (_user?.hasPassword ?? false) || repository.hasPasswordProvider;

  Future<void>? _profileRefresh;

  Future<void> refreshProfile() => _profileRefresh ??= _refreshProfile()
      .whenComplete(() => _profileRefresh = null);

  Future<void> _refreshProfile() async {
    final uid = _user?.id;
    if (uid == null) return;
    final result = await repository.refreshProfile();
    if (_user?.id != uid) return;
    result.fold(
      (failure) => _reportFailure(failure, context: 'refreshProfile'),
      (user) {
        if (_user == user) return;
        _user = user;
        notifyListeners();
      },
    );
  }

  Future<bool> updateProfile({
    String? phone,
    String? imageUrl,
    String? name,
  }) async {
    if (_user == null) return false;
    // Phone changes must go through OTP + updatePhoneNumber.
    if (phone != null && phone.trim().isNotEmpty) {
      final updated = _user!.copyWith(
        phone: phone,
        imageUrl: imageUrl,
        name: name,
      );
      final result = await repository.saveUser(updated);
      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          _errorCode = failure is AuthFailure ? failure.code : null;
          _reportFailure(failure, context: 'updateProfile');
          notifyListeners();
          return false;
        },
        (user) {
          _user = user;
          notifyListeners();
          return true;
        },
      );
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await repository.updateProfileData(
      name: name,
      imageUrl: imageUrl,
    );
    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        _errorCode = failure is AuthFailure ? failure.code : null;
        _reportFailure(failure, context: 'updateProfile');
        notifyListeners();
        return false;
      },
      (user) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> confirmPassword(String password) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await repository.confirmPassword(password: password);
    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        _errorCode = failure is AuthFailure ? failure.code : null;
        _reportFailure(failure, context: 'confirmPassword');
        notifyListeners();
        return false;
      },
      (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> syncProfileToBackend({
    String? name,
    String? phone,
    String? imageUrl,
  }) async {
    final result = await repository.syncProfileToBackend(
      name: name,
      phone: phone,
      imageUrl: imageUrl,
    );
    return result.fold(
      (failure) {
        // Backend may be a placeholder; keep Firebase/local success intact.
        _reportFailure(failure, context: 'syncProfileToBackend');
        return false;
      },
      (user) {
        _user = user;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await repository.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        _errorCode = failure is AuthFailure ? failure.code : null;
        _reportFailure(failure, context: 'changePassword');
        notifyListeners();
        return false;
      },
      (user) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> changePhoneNumber({
    required String phone,
    required String smsCode,
  }) async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      _errorCode = AuthErrorCodes.missingVerification;
      _errorMessage = 'Request a verification code first';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final e164 = Validators.normalizePhone(phone);
    final result = await repository.updatePhoneNumber(
      verificationId: verificationId,
      smsCode: smsCode,
      phone: e164,
    );
    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        _errorCode = failure is AuthFailure ? failure.code : null;
        _reportFailure(failure, context: 'changePhoneNumber');
        notifyListeners();
        return false;
      },
      (user) {
        _user = user;
        _otpSent = false;
        _phoneAutoVerified = false;
        _verificationId = null;
        _resendToken = null;
        _pendingPhone = null;
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> logout() async {
    _restoredAccountNeedsSync = false;
    final result = await repository.logout();
    result.fold((failure) {
      _errorMessage = failure.message;
      _reportFailure(failure, context: 'logout');
    }, (_) {});
    _user = null;
    await CrashlyticsService.instance.setUserId(null);
    await AnalyticsService.instance.setUserId(null);
    resetAuthForm();
  }

  /// Auth does not use [guardRemote], so blueprint logging happens here once.
  void _reportFailure(Failure failure, {required String context}) {
    ErrorBlueprintLogger.log(
      error: failure is AuthFailure
          ? AuthException(failure.message, failure.code, failure.statusCode)
          : ServerException(failure.message, failure.code, failure.statusCode),
      context: ErrorContext(
        feature: 'Auth',
        layer: 'Provider',
        operation: context,
        statusCode: failure.statusCode,
      ),
    );
    AppErrorFeedback.report(failure, kind: AppErrorKind.send, context: context);
  }

  Future<bool> _run(
    Future<Either<Failure, User>> Function() action, {
    required String context,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final result = await action();
      final success = result.fold(
        (failure) {
          _errorMessage = failure.message;
          _errorCode = failure.code ?? (failure is AuthFailure ? AuthErrorCodes.verificationFailed : 'unexpected');
          // Cancelled social sign-in is not an error worth reporting.
          if (_errorCode != AuthErrorCodes.cancelled) {
            _reportFailure(failure, context: context);
            unawaited(AnalyticsService.instance.loginFailed(code: _errorCode));
          }
          notifyListeners();
          return false;
        },
        (user) {
          _user = user;
          _otpSent = false;
          _verificationId = null;
          _resendToken = null;
          _pendingPhone = null;
          notifyListeners();
          return true;
        },
      );
      if (success && _user != null) {
        await CrashlyticsService.instance.setUserId(_user!.id);
        await AnalyticsService.instance.setUserId(_user!.id);
        unawaited(AnalyticsService.instance.loginSuccess());
  
      }
      return success;
    } catch (error, stack) {
      debugPrint('[AuthProvider] unexpected: $error');
      unawaited(
        CrashlyticsService.instance.recordError(
          error,
          stack,
          reason: 'auth_provider_$context',
        ),
      );
      _errorCode = 'unexpected';
      _errorMessage = 'Something went wrong. Please try again.';
      ErrorBlueprintLogger.log(
        error: error,
        stackTrace: stack,
        context: ErrorContext(
          feature: 'Auth',
          layer: 'Provider',
          operation: context,
        ),
      );
      AppErrorFeedback.report(
        const AuthFailure('Unexpected error'),
        kind: AppErrorKind.send,
        context: context,
      );
      unawaited(AnalyticsService.instance.loginFailed(code: _errorCode));
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

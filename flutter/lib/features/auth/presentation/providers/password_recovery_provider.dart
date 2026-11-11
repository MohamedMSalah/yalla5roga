import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';

class PasswordRecoveryProvider extends ChangeNotifier {
  PasswordRecoveryProvider(this.repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AuthRepository repository;
  final DateTime Function() _now;
  bool busy = false;
  bool _disposed = false;
  Failure? failure;
  String phone = '';
  String? _requestToken;
  String? _resetToken;
  String? _verificationId;
  int? _resendToken;
  DateTime? _resendAt;
  Timer? _ticker;
  bool get codeSent => _verificationId != null;
  bool get verified => _resetToken != null;
  int get resendSeconds => _resendAt == null
      ? 0
      : ((_resendAt!.difference(_now()).inMilliseconds / 1000).ceil()).clamp(
          0,
          60,
        );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<bool> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    failure = null;
    _notify();
    try {
      return await action();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> send(String normalizedPhone) => _run(() async {
    if (resendSeconds > 0) return false;
    // Start the local cooldown before network work, including ambiguous timeouts.
    _resendAt = _now().add(const Duration(seconds: 60));
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (resendSeconds == 0) {
        _ticker?.cancel();
        _ticker = null;
      }
      _notify();
    });
    final start = await repository.startPasswordRecovery(normalizedPhone);
    final token = start.fold((f) {
      failure = f;
      return null;
    }, (value) => value);
    if (token == null || _disposed) return false;
    final sent = await repository.sendOtp(
      phone: normalizedPhone,
      forceResendingToken: normalizedPhone == phone ? _resendToken : null,
    );
    return sent.fold(
      (f) {
        failure = f;
        return false;
      },
      (value) {
        if (_disposed) return false;
        phone = normalizedPhone;
        _requestToken = token;
        _resetToken = null;
        _verificationId = value.verificationId;
        _resendToken = value.resendToken;
        return true;
      },
    );
  });

  Future<bool> verify(String code) => _run(() async {
    if (_requestToken == null || _verificationId == null) return false;
    final result = await repository.verifyPasswordRecovery(
      requestToken: _requestToken!,
      verificationId: _verificationId!,
      smsCode: code,
    );
    return result.fold(
      (f) {
        failure = f;
        if (f.statusCode == 401) restart();
        return false;
      },
      (token) {
        if (_disposed) return false;
        _resetToken = token;
        _requestToken = null;
        _verificationId = null;
        return true;
      },
    );
  });

  Future<bool> reset(String password, String confirmation) => _run(() async {
    if (_resetToken == null) return false;
    final result = await repository.resetRecoveredPassword(
      resetToken: _resetToken!,
      newPassword: password,
      confirmPassword: confirmation,
    );
    return result.fold(
      (f) {
        failure = f;
        if (f.statusCode == 401 || f.statusCode == 400) restart();
        return false;
      },
      (_) {
        restart();
        return true;
      },
    );
  });

  void restart() {
    _requestToken = null;
    _resetToken = null;
    _verificationId = null;
    _resendToken = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _requestToken = null;
    _resetToken = null;
    _verificationId = null;
    super.dispose();
  }
}

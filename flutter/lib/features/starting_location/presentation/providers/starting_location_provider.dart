import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/effective_starting_location.dart';
import '../../domain/repositories/starting_location_repository.dart';

class StartingLocationProvider extends ChangeNotifier {
  StartingLocationProvider(
    this._repository,
    this.account,
    this.scope,
    this._currentAccount,
  );

  final StartingLocationRepository _repository;
  final String account;
  final StartingLocationScope scope;
  final bool Function() _currentAccount;
  bool _disposed = false;
  bool get active => !_disposed && _currentAccount();

  EffectiveStartingLocation? value;
  Failure? failure;
  bool loading = false;
  Timer? _expiry;

  Future<bool> _request(
    Future<Either<Failure, EffectiveStartingLocation>> Function() run, {
    required bool refresh,
  }) async {
    if (!active || loading) return false;
    loading = true;
    failure = null;
    notifyListeners();
    final result = await run();
    if (!active) return false;
    loading = false;
    result.fold(
      (error) {
        failure = error;
        if (refresh || const {401, 403, 404, 409}.contains(error.statusCode)) {
          _expiry?.cancel();
          value = null;
        }
      },
      (effective) {
        value = effective;
        _expiry?.cancel();
        if (effective.expiresAt case final expires?) {
          final remaining = expires.difference(DateTime.now());
          if (remaining > Duration.zero) {
            _expiry = Timer(remaining, () {
              if (!active) return;
              value = null;
              notifyListeners();
              unawaited(reload());
            });
          }
        }
      },
    );
    notifyListeners();
    return result.isRight();
  }

  Future<bool> reload() =>
      _request(() => _repository.get(account, scope), refresh: true);

  Future<bool> save(
    StartingLocationOverride override,
    String? consentPolicyVersion,
  ) => _request(
    () => _repository.set(
      account,
      scope,
      override,
      consentPolicyVersion: consentPolicyVersion,
    ),
    refresh: false,
  );

  Future<bool> reset() =>
      _request(() => _repository.clear(account, scope), refresh: false);

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    super.dispose();
  }
}

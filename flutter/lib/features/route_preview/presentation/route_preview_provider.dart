import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../domain/route_preview_entity.dart';
import '../domain/route_preview_repository.dart';

class RoutePreviewProvider extends ChangeNotifier {
  RoutePreviewProvider(
    this._repository,
    this._account,
    this._target,
    this._accountCurrent,
  );

  final RoutePreviewRepository _repository;
  final String _account;
  final RoutePreviewTarget _target;
  final bool Function() _accountCurrent;
  int _revision = 0;
  bool _disposed = false;
  Timer? _expiry;

  RoutePreviewEntity? value;
  Failure? failure;
  bool loading = true;
  int selected = 0;

  bool get _active => !_disposed && _accountCurrent();

  Future<void> load() async {
    if (!_active) return;
    final revision = ++_revision;
    _expiry?.cancel();
    value = null;
    failure = null;
    selected = 0;
    loading = true;
    notifyListeners();

    final response = await _repository.get(_account, _target);
    if (!_active || revision != _revision) return;
    loading = false;
    response.fold((error) => failure = error, (preview) {
      final remaining = preview.expiresAt.difference(DateTime.now());
      if (remaining <= Duration.zero) return;
      value = preview;
      _expiry = Timer(remaining, () {
        if (_active) unawaited(load());
      });
    });
    notifyListeners();
  }

  void select(int index) {
    if (!_active ||
        index == selected ||
        index < 0 ||
        index >= (value?.routes.length ?? 0)) {
      return;
    }
    selected = index;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    super.dispose();
  }
}

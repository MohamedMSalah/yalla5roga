import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/routing_capabilities.dart';
import '../../domain/entities/transportation_preference.dart';
import '../../domain/repositories/transportation_preferences_repository.dart';

class TransportationPreferencesProvider extends ChangeNotifier {
  TransportationPreferencesProvider(this._repository, this._account);

  final TransportationPreferencesRepository _repository;
  String? _account;
  int _session = 0;
  int get session => _session;
  bool matchesSession(int session) => _account != null && _session == session;

  TransportationPreference? preference;
  List<RoutingCapabilities> capabilities = const [];
  Failure? readFailure;
  Failure? writeFailure;
  bool isLoading = false;
  bool isSaving = false;

  void bindAccount(String? account) {
    if (_account == account) return;
    _account = account;
    _session++;
    preference = null;
    capabilities = const [];
    readFailure = null;
    writeFailure = null;
    isLoading = false;
    isSaving = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _session++;
    super.dispose();
  }

  Future<void> refresh() async {
    final session = _session;
    if (!matchesSession(session) || isLoading || isSaving) return;
    isLoading = true;
    readFailure = null;
    notifyListeners();

    final capabilityRequest = _repository.getRoutingCapabilities();
    final result = await _repository.getTransportationPreference();
    final support = await capabilityRequest;
    if (!matchesSession(session)) return;

    result.fold((failure) {
      preference = null;
      readFailure = failure;
    }, (value) => preference = value);
    capabilities = support.getOrElse(() => const []);
    isLoading = false;
    notifyListeners();
  }

  Future<void> update(TransportationMode? mode) async {
    final session = _session;
    if (!matchesSession(session) ||
        isLoading ||
        isSaving ||
        preference == null ||
        preference?.defaultMode == mode) {
      return;
    }
    isSaving = true;
    writeFailure = null;
    notifyListeners();
    final result = await _repository.updateTransportationPreference(mode);
    if (!matchesSession(session)) return;
    result.fold(
      (failure) => writeFailure = failure,
      (value) => preference = value,
    );
    isSaving = false;
    notifyListeners();
  }
}

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';

import '../../domain/entities/location_privacy_settings.dart';
import '../../domain/repositories/location_privacy_repository.dart';

class LocationPrivacyProvider extends ChangeNotifier {
  LocationPrivacyProvider(
    this._repository,
    this._groupsRepository,
    this._account,
  );

  final LocationPrivacyRepository _repository;
  final GroupsRepository _groupsRepository;
  String? _account;
  int _session = 0;
  int get session => _session;
  bool matchesSession(int session) => _account != null && _session == session;

  LocationPrivacySettings? settings;
  List<Group>? groups;
  Set<String> _excludedGroupIds = const {};
  Failure? settingsReadFailure;
  Failure? settingsWriteFailure;
  Failure? groupsReadFailure;
  Failure? groupsWriteFailure;
  bool isLoadingSettings = false;
  bool isSavingSettings = false;
  bool isLoadingGroups = false;
  String? savingGroupId;

  bool isGroupExcluded(String groupId) => _excludedGroupIds.contains(groupId);

  void bindAccount(String? account) {
    if (_account == account) return;
    _account = account;
    _session++;
    settings = null;
    groups = null;
    _excludedGroupIds = const {};
    settingsReadFailure = null;
    settingsWriteFailure = null;
    groupsReadFailure = null;
    groupsWriteFailure = null;
    isLoadingSettings = false;
    isSavingSettings = false;
    isLoadingGroups = false;
    savingGroupId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _session++;
    super.dispose();
  }

  Future<void> refreshSettings() async {
    final session = _session;
    if (!matchesSession(session) || isLoadingSettings || isSavingSettings) {
      return;
    }
    isLoadingSettings = true;
    settingsReadFailure = null;
    notifyListeners();
    final response = await _repository.getSettings();
    if (!matchesSession(session)) return;
    response.fold((failure) {
      settingsReadFailure = failure;
      settings = null;
    }, (value) => settings = value);
    isLoadingSettings = false;
    notifyListeners();
  }

  Future<void> updateVisibility(LocationVisibility visibility) =>
      _saveSettings(() => _repository.updateVisibility(visibility));

  Future<void> grantConsent(String version) async {
    final current = settings;
    if (current == null ||
        current.automaticUsageEnabled ||
        !current.canPresentConsent ||
        current.requiredPolicyVersion != version) {
      return;
    }
    await _saveSettings(() => _repository.grantConsent(version));
  }

  Future<void> withdrawConsent() => _saveSettings(_repository.withdrawConsent);

  Future<void> _saveSettings(
    Future<Either<Failure, LocationPrivacySettings>> Function() save,
  ) async {
    final session = _session;
    if (!matchesSession(session) ||
        isLoadingSettings ||
        isSavingSettings ||
        settings == null) {
      return;
    }
    isSavingSettings = true;
    settingsWriteFailure = null;
    notifyListeners();
    final response = await save();
    if (!matchesSession(session)) return;
    response.fold(
      (failure) => settingsWriteFailure = failure,
      (value) => settings = value,
    );
    isSavingSettings = false;
    notifyListeners();
    if (settingsWriteFailure != null) await refreshSettings();
  }

  Future<void> refreshGroups() async {
    final session = _session;
    if (!matchesSession(session) || isLoadingGroups || savingGroupId != null) {
      return;
    }
    isLoadingGroups = true;
    groupsReadFailure = null;
    notifyListeners();
    final groupsRequest = _groupsRepository.getGroups(forceRefresh: true);
    final exclusions = await _repository.getExcludedGroups();
    final memberships = await groupsRequest;
    if (!matchesSession(session)) return;
    memberships.fold(
      (failure) => groupsReadFailure = failure,
      (items) => groups = List.unmodifiable(items),
    );
    exclusions.fold(
      (failure) => groupsReadFailure = failure,
      (ids) => _excludedGroupIds = ids,
    );
    if (groupsReadFailure != null) {
      groups = null;
      _excludedGroupIds = const {};
    }
    isLoadingGroups = false;
    notifyListeners();
  }

  Future<void> setGroupExcluded(String groupId, bool excluded) async {
    final session = _session;
    if (!matchesSession(session) ||
        isLoadingGroups ||
        savingGroupId != null ||
        groups?.any((group) => group.id == groupId) != true ||
        isGroupExcluded(groupId) == excluded) {
      return;
    }
    savingGroupId = groupId;
    groupsWriteFailure = null;
    notifyListeners();
    final response = await _repository.setGroupExcluded(groupId, excluded);
    if (!matchesSession(session)) return;
    response.fold((failure) => groupsWriteFailure = failure, (value) {
      final updated = {..._excludedGroupIds};
      if (value) {
        updated.add(groupId);
      } else {
        updated.remove(groupId);
      }
      _excludedGroupIds = updated;
    });
    savingGroupId = null;
    notifyListeners();
    if (groupsWriteFailure != null) await refreshGroups();
  }
}

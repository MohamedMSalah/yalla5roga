import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:yalla_5roga/core/monitoring/analytics_service.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/add_member_phone_sheet.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

enum GroupsFilter { all, mostActive, recentlyCreated }

class GroupsProvider extends ChangeNotifier {
  GroupsProvider({
    required this.repository,
    required this.shell,
    this.mediaUploads,
  });

  final GroupsRepository repository;
  final ShellProvider shell;
  final MediaUploadService? mediaUploads;

  bool _isDeletingGroup = false;
  bool get isDeletingGroup => _isDeletingGroup;
  var _groups = <Group>[];
  int _unreadGroupCount = 0;
  GroupsFilter _filter = GroupsFilter.all;
  var _searching = false;
  var _query = '';
  String? _createImage;
  final _createPhones = <String>[];
  var _isLoading = false;
  var _isLeaving = false;
  var _confirmingExit = false;
  var _isCreating = false;
  var _hasLoaded = false;
  var _hasGroupsSnapshot = false;
  String? _errorMessage;
  var _epoch = 0;
  var _accountEpoch = 0;
  final _openGroups = <String, int>{};
  final _groupAccessRevisions = <String, int>{};
  Iterable<String> get openGroupIds => _openGroups.keys;

  void openGroup(String id) =>
      _openGroups.update(id, (count) => count + 1, ifAbsent: () => 1);

  void closeGroup(String id) {
    final count = _openGroups[id] ?? 0;
    if (count <= 1) {
      _openGroups.remove(id);
    } else {
      _openGroups[id] = count - 1;
    }
  }

  List<Group> _groupsView = const [];
  Map<String, Group> _groupsById = const {};

  List<Group> get groups => _groupsView;

  int get unreadGroupCount => _unreadGroupCount;

  bool get isLoading => _isLoading;

  bool get isLeaving => _isLeaving;

  bool get isCreating => _isCreating;

  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoading => !_hasLoaded;

  bool get hasGroupsSnapshot => _hasGroupsSnapshot;

  String? get errorMessage => _errorMessage;

  GroupsFilter get filter => _filter;

  bool get searching => _searching;

  String get query => _query;

  String? get createImage => _createImage;

  List<String> get createPhones => List.unmodifiable(_createPhones);

  List<GroupMember> get contacts => repository.contacts;

  String groupsForMember(String id) => repository.groupsForMember(id);

  GroupMember? memberById(String id) => repository.memberById(id);

  GroupMember? memberByPhone(String phone) => repository.memberByPhone(phone);

  (List<Group>, String)? _searchInput;
  List<Group> _searchResults = const [];

  List<Group> get matchingGroups {
    final needle = _query.trim().toLowerCase();
    final input = (groups, needle);
    if (input == _searchInput) return _searchResults;
    _searchInput = input;
    return _searchResults = needle.isEmpty
        ? groups
        : List.unmodifiable(
            groups.where(
              (group) =>
                  group.name.toLowerCase().contains(needle) ||
                  group.bio.toLowerCase().contains(needle),
            ),
          );
  }

  (List<Group>, GroupsFilter, Map<String, int>?)? _orderInput;
  List<String> _visibleIds = const [];

  List<String> visibleGroupIds(Map<String, int>? outingCounts) {
    final counts = _filter == GroupsFilter.mostActive ? outingCounts : null;
    final matches = matchingGroups;
    final input = (matches, _filter, counts);
    if (input == _orderInput) return _visibleIds;
    _orderInput = input;
    final order = matches.indexed.toList();
    if (_filter == GroupsFilter.recentlyCreated || counts != null) {
      order.sort((a, b) {
        final (indexA, groupA) = a;
        final (indexB, groupB) = b;
        final result = counts != null
            ? (counts[groupB.id] ?? 0).compareTo(counts[groupA.id] ?? 0)
            : _newestFirst(groupA.createdAt, groupB.createdAt);
        return result == 0 ? indexA.compareTo(indexB) : result;
      });
    }
    return _visibleIds = List.unmodifiable(order.map((entry) => entry.$2.id));
  }

  static int _newestFirst(DateTime? a, DateTime? b) {
    if (a == null) return b == null ? 0 : 1;
    return b == null ? -1 : b.compareTo(a);
  }

  (List<Group>, String?)? _summaryInput;
  int? _friendsCount;

  int? uniqueFriendsCount(String? userId) {
    final input = (groups, userId);
    if (input == _summaryInput) return _friendsCount;
    _summaryInput = input;
    return _friendsCount = _countFriends(userId);
  }

  int? _countFriends(String? userId) {
    if (userId == null) return null;
    final friends = <String>{};
    for (final group in groups) {
      final rosterIds = {
        for (final member in group.members)
          if (!member.isPending &&
              member.id.isNotEmpty &&
              !member.id.startsWith('preview_'))
            member.id,
      };
      final count = group.acceptedMemberCount;
      final accepted = rosterIds.length == count
          ? rosterIds
          : group.cachedAcceptedMemberIds.toSet();
      if (accepted.length != count || !accepted.remove(userId)) {
        return null;
      }
      friends.addAll(accepted);
    }
    return friends.length;
  }

  @override
  void notifyListeners() {
    if (!listEquals(_groupsView, _groups)) {
      _groupsView = List.unmodifiable(_groups);
      _groupsById = {for (final group in _groups) group.id: group};
    }
    super.notifyListeners();
  }

  Group? findById(String id) {
    // Mutations may look up a group before publishing their new view.
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  Group? listedGroup(String id) => _groupsById[id];

  Group byId(String id) =>
      findById(id) ?? (_groups.isNotEmpty ? _groups.first : _emptyGroup(id));

  static Group _emptyGroup(String id) {
    return Group(id: id, name: '', outings: 0, image: '', members: const []);
  }

  Future<Group?> ensureGroupLoaded(
    String groupId, {
    bool forceRefresh = false,
    bool allowStale = true,
  }) async {
    final epoch = _epoch;
    final revision = _groupAccessRevisions[groupId];
    bool isCurrent() =>
        epoch == _epoch && revision == _groupAccessRevisions[groupId];
    final existing = findById(groupId);
    if (allowStale &&
        !OfflineSnapshots.cacheOnly &&
        (existing == null || existing.members.isEmpty)) {
      final preview = await OfflineSnapshots.preview(
        () => repository.getGroup(groupId, forceRefresh: true),
      );
      if (!isCurrent()) return null;
      preview.fold((_) {}, (group) {
        if (findById(groupId) == null) {
          _groups = [group, ..._groups];
        } else {
          _groups[_groups.indexWhere((item) => item.id == groupId)] = group;
        }
        notifyListeners();
      });
    }
    final result = await repository.getGroup(
      groupId,
      forceRefresh: forceRefresh,
      allowStale: allowStale,
    );
    if (!isCurrent()) return null;
    return result.fold(
      (failure) {
        if (failure.statusCode == 403 || failure.statusCode == 404) {
          _discardGroup(groupId);
          notifyListeners();
          return null;
        }
        return allowStale ? findById(groupId) : null;
      },
      (group) {
        final index = _groups.indexWhere((item) => item.id == groupId);
        if (index < 0) {
          _groups = [group, ..._groups];
        } else {
          _groups[index] = group;
        }
        notifyListeners();
        return group;
      },
    );
  }

  void _discardGroup(String groupId) {
    _groupAccessRevisions.update(
      groupId,
      (revision) => revision + 1,
      ifAbsent: () => 1,
    );
    _groups.removeWhere((item) => item.id == groupId);
  }

  Future<void> loadGroups({bool forceRefresh = false}) async {
    final epoch = _epoch;
    final revisions = Map.of(_groupAccessRevisions);
    final result = await repository.getGroups(forceRefresh: forceRefresh);
    if (epoch != _epoch) return;
    if (OfflineSnapshots.cacheOnly && result.isLeft()) return;
    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'loadGroups',
        );
      },
      (groups) {
        final existing = {for (final group in _groups) group.id: group};
        _groups = [
          for (final group in groups)
            if (revisions[group.id] == _groupAccessRevisions[group.id])
              if (existing[group.id] case final previous?)
                group.copyWith(
                  members:
                      group.members.isEmpty &&
                          group.listedMemberCount ==
                              previous.acceptedMemberCount
                      ? previous.members
                      : group.members,
                  pendingMembers: previous.pendingMembers,
                  invitationHistory: previous.invitationHistory,
                )
              else
                group,
          for (final group in existing.values)
            if (revisions[group.id] != _groupAccessRevisions[group.id]) group,
        ];
        _hasGroupsSnapshot = true;
        _errorMessage = null;
      },
    );
    _hasLoaded = true;
    notifyListeners();
  }

  void setFilter(GroupsFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void openSearch() {
    if (_searching) return;
    _searching = true;
    notifyListeners();
  }

  void closeSearch() {
    if (!_searching && _query.isEmpty) return;
    _searching = false;
    _query = '';
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setCreateImage(String path) {
    _createImage = path;
    notifyListeners();
  }

  String? addCreatePhone(String raw, L10n l10n) {
    final phone = Validators.normalizeGroupPhone(raw);
    if (phone == null) return l10n.invalidPhone;
    if (_createPhones.contains(phone)) return l10n.phoneAlreadyAdded;
    _createPhones.add(phone);
    notifyListeners();
    return null;
  }

  void removeCreatePhone(String phone) {
    _createPhones.remove(phone);
    notifyListeners();
  }

  void resetCreate({bool notify = true}) {
    _createImage = null;
    _createPhones.clear();
    if (notify) notifyListeners();
  }

  String roleLabel(GroupRole role, L10n l10n) {
    return switch (role) {
      GroupRole.owner => l10n.owner,
      GroupRole.member => l10n.member,
    };
  }

  bool canParticipate(Group group, String? accountId) =>
      accountId != null &&
      group.members.any(
        (member) => member.id == accountId && !member.isPending,
      );

  bool canManage(Group group) => group.cuserRole == GroupRole.owner;

  void addCreatePhones(Iterable<String> phones) {
    var changed = false;
    for (final raw in phones) {
      final phone = Validators.normalizeGroupPhone(raw);
      if (phone == null) continue;
      if (_createPhones.contains(phone)) continue;
      _createPhones.add(phone);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Replaces the pending invite list (used when returning from contacts picker).
  void setCreatePhones(Iterable<String> phones) {
    final next = <String>[];
    for (final raw in phones) {
      final phone = Validators.normalizeGroupPhone(raw);
      if (phone == null) continue;
      if (next.contains(phone)) continue;
      next.add(phone);
    }
    _createPhones
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<Group?> createGroup(
    String name, {
    required String ownerName,
    String? ownerAvatar,
    String bio = '',
    bool whatsappOptIn = false,
  }) async {
    if (_isCreating || name.trim().isEmpty) return null;
    if (!whatsappOptIn) {
      _errorMessage = _l10n?.whatsappOptInPrompt;
      notifyListeners();
      return null;
    }

    _isCreating = true;
    notifyListeners();

    // A picked local file must be uploaded before the group row exists. The
    // server verifies ownership and links the asset when the cover is saved.
    var image = _createImage ?? '';
    if (isLocalFilePath(image)) {
      final uploads = mediaUploads;
      if (uploads == null) {
        _isCreating = false;
        _errorMessage = _l10n?.imageUploadFailed;
        notifyListeners();
        return null;
      }
      try {
        final uploaded = await uploads.uploadLocalImage(
          path: image,
          purpose: MediaPurpose.group,
        );
        image = uploaded.reference;
        _createImage = image;
      } catch (_) {
        _isCreating = false;
        _errorMessage = _l10n?.imageUploadFailed;
        notifyListeners();
        return null;
      }
    }

    final phonesToInvite = List<String>.from(_createPhones);
    final members = [
      GroupMember(
        id: 'me',
        name: ownerName,
        avatar: ownerAvatar ?? '',
        role: GroupRole.owner,
      ),
    ];
    final group = Group(
      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      outings: 0,
      bio: bio.trim(),
      // Local paths are uploaded above; the API receives media:// or http(s).
      image: image,
      members: members,
      cuserRole: GroupRole.owner,
    );
    final result = await repository.createGroup(group);
    Group? created;
    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'createGroup',
        );
      },
      (value) {
        created = value;
        _groups = [value, ..._groups.where((item) => item.id != value.id)];
        AnalyticsService.instance.createGroup();
      },
    );

    final createdGroup = created;
    var queuedInvites = 0;
    if (createdGroup != null) {
      for (final phone in phonesToInvite) {
        final invite = await repository.inviteByPhone(
          groupId: createdGroup.id,
          phoneNumber: phone,
          whatsappOptIn: whatsappOptIn,
        );
        invite.fold(
          (failure) {
            AppErrorFeedback.report(
              failure,
              kind: AppErrorKind.send,
              context: 'inviteByPhoneOnCreate',
            );
          },
          (value) {
            if (value.notificationQueued) queuedInvites += 1;
          },
        );
      }
      // Always refresh so creator is in members and count starts at Ã¢â€°Â¥1.
      final refreshed = await repository.getGroup(
        createdGroup.id,
        forceRefresh: true,
      );
      refreshed.fold((_) {}, (value) {
        created = value.copyWith(cuserRole: GroupRole.owner);
        _groups = [
          created!,
          ..._groups.where((item) => item.id != created!.id),
        ];
      });
    }

    if (created != null) resetCreate(notify: false);
    _isCreating = false;
    notifyListeners();

    if (queuedInvites > 0) {
      final l10n = _l10n;
      if (l10n != null) AppSnackBar.show(l10n.invitesQueued(queuedInvites));
    }

    return created;
  }

  L10n? get _l10n => Get.context?.l10n;

  Future<void> changeImage(String groupId) async {
    final l10n = _l10n;
    if (l10n == null) return;

    final picked = await ImageSourceSheet.pick(title: l10n.changeGroupImage);
    if (picked == null) return;

    var image = picked;
    if (isLocalFilePath(image)) {
      final uploads = mediaUploads;
      if (uploads == null) {
        AppSnackBar.show(l10n.imageUploadFailed);
        return;
      }
      try {
        final uploaded = await uploads.uploadLocalImage(
          path: image,
          purpose: MediaPurpose.group,
          entityId: groupId,
        );
        image = uploaded.reference;
      } catch (_) {
        AppSnackBar.show(l10n.imageUploadFailed);
        return;
      }
    }

    final previous = _groups
        .where((group) => group.id == groupId)
        .map((group) => group.image)
        .firstOrNull;
    final ok = await updateImage(groupId, image);
    if (ok) {
      AppSnackBar.show(l10n.changesSaved);
      if (isMediaReference(previous) && previous != image) {
        unawaited(mediaUploads?.deleteMediaReference(previous));
      }
    }
    // Failures already surface via AppErrorFeedback in updateImage.
  }

  Future<void> promptAddMember(String groupId) async {
    final l10n = _l10n;
    if (l10n == null) return;
    final epoch = _epoch;

    final added = await AddMemberPhoneSheet.show();
    if (added == null || epoch != _epoch) return;

    for (final phone in added.phones) {
      if (epoch != _epoch) break;
      final error = await inviteMember(
        groupId,
        phone,
        l10n,
        whatsappOptIn: added.whatsappOptIn,
      );
      // API failures already surface via AppErrorFeedback; validation only here.
      if (error != null) AppSnackBar.show(error);
    }
  }

  Future<void> confirmRemoveMember(String groupId, GroupMember person) async {
    final l10n = _l10n;
    if (l10n == null) return;

    final name = l10n.digits(MemberDisplayName.resolve(person));
    final confirmed = await AppAlert.confirm(
      title: l10n.removeMemberTitle,
      message: l10n.removeMemberMessage(name),
      confirmText: l10n.removeMember,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (!confirmed) return;

    final ok = await removeMember(groupId, person);
    if (ok) {
      AppSnackBar.show(l10n.memberRemoved(name));
    }
    // Failures already surface via AppErrorFeedback in removeMember.
  }

  Future<bool> deleteGroup(String id) async {
    final group = findById(id);
    if (_isDeletingGroup || group == null || !canManage(group)) return false;
    _isDeletingGroup = true;
    notifyListeners();
    final result = await repository.deleteGroup(id);
    final ok = result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        return false;
      },
      (_) {
        _groups.removeWhere((g) => g.id == id);
        return true;
      },
    );
    _isDeletingGroup = false;
    notifyListeners();
    return ok;
  }

  Future<void> confirmLeaveGroup(
    String groupId, {
    required bool delete,
    VoidCallback? onSuccess,
  }) async {
    final l10n = _l10n;
    final group = findById(groupId);
    if (l10n == null || group == null || _isLeaving || _confirmingExit) return;

    final epoch = _accountEpoch;
    _confirmingExit = true;
    try {
      final confirmed = await AppAlert.confirm(
        title: delete ? l10n.deleteGroup : l10n.leaveGroupTitle,
        message: l10n.groupExitMessage(group.name, delete: delete),
        confirmText: delete ? l10n.deleteGroup : l10n.leaveGroup,
        cancelText: l10n.cancel,
        destructive: true,
      );
      if (!confirmed || epoch != _accountEpoch || findById(groupId) == null) {
        return;
      }
      final ok = await leaveGroup(groupId, expectedDelete: delete);
      if (!ok || epoch != _accountEpoch) return;
      onSuccess?.call();
      AppSnackBar.show(delete ? l10n.groupDeleted : l10n.leftGroup);
      shell.setIndex(1);
      Get.until((route) => route.isFirst);
    } finally {
      if (epoch == _accountEpoch) _confirmingExit = false;
    }
  }

  Future<bool> updateImage(String groupId, String url) =>
      _updateGroup(groupId, image: url);

  Future<bool> updateName(String groupId, String name) =>
      _updateGroup(groupId, name: name.trim());

  Future<bool> updateBio(String groupId, String bio) =>
      _updateGroup(groupId, bio: bio.trim());

  Future<bool> _updateGroup(
    String groupId, {
    String? name,
    String? bio,
    String? image,
  }) async {
    final current = findById(groupId);
    if (current == null || !canManage(current)) return false;
    final result = await repository.updateGroup(
      groupId,
      name: name,
      bio: bio,
      image: image,
    );
    final ok = result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: bio == null ? 'updateGroupImage' : 'updateGroupBio',
        );
        return false;
      },
      (group) {
        _errorMessage = null;
        // A patch response omits the caller role and the loaded member list.
        _groups = [
          for (final item in _groups)
            if (item.id == group.id)
              item.copyWith(
                name: name == null ? null : group.name,
                bio: bio == null ? null : group.bio,
                image: image == null ? null : group.image,
              )
            else
              item,
        ];
        return true;
      },
    );
    notifyListeners();
    return ok;
  }

  /// Invite by phone. Every invite remains pending until explicit acceptance.
  /// Returns a localized validation/API error, or `null` on success.
  Future<String?> inviteMember(
    String groupId,
    String phone,
    L10n l10n, {
    bool whatsappOptIn = false,
  }) async {
    final epoch = _epoch;
    if (!whatsappOptIn) return l10n.whatsappOptInPrompt;
    if (findById(groupId)?.containsMember(id: phone, phone: phone) == true) {
      return l10n.phoneAlreadyAdded;
    }

    final result = await repository.inviteByPhone(
      groupId: groupId,
      phoneNumber: phone,
      whatsappOptIn: whatsappOptIn,
    );
    if (epoch != _epoch) return null;
    final error = await result.fold<Future<String?>>(
      (failure) async {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'inviteByPhone',
        );
        // Null: snackbar already shown by AppErrorFeedback.
        return null;
      },
      (invite) async {
        _errorMessage = null;
        final display = l10n.digits(MemberDisplayName.resolvePhone(phone));
        await ensureGroupLoaded(groupId, forceRefresh: true);
        if (epoch != _epoch) return null;
        if (invite.isMembership) {
          AnalyticsService.instance.joinGroup();
          AppSnackBar.show(l10n.memberAdded(display));
        } else {
          AppSnackBar.show(
            invite.notificationQueued
                ? l10n.invitationQueued
                : l10n.pendingGroupRegistration,
          );
        }
        return null;
      },
    );
    notifyListeners();
    return error;
  }

  /// Legacy path for adding an already-registered Neon user by phone.
  /// Prefer [inviteMember] so non-users receive WhatsApp invitations.
  Future<String?> addMember(String groupId, String phone, L10n l10n) {
    return inviteMember(groupId, phone, l10n);
  }

  Future<bool> removeMember(String groupId, GroupMember person) async {
    if (person.role == GroupRole.owner) return false;
    final result = await repository.removeMember(
      groupId,
      person.id,
      pending: person.isPending,
    );
    final ok = result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'removeMember',
        );
        return false;
      },
      (updated) {
        _errorMessage = null;
        _groups = [
          for (final item in _groups)
            if (item.id == updated.id) updated else item,
        ];
        return true;
      },
    );
    notifyListeners();
    return ok;
  }

  /// The sole owner leaves through the existing delete API; other members use
  /// ordinary leave, retaining backend last-owner and historical-outing guards.
  Future<bool> leaveGroup(String groupId, {bool? expectedDelete}) async {
    if (_isLeaving) return false;
    _isLeaving = true;
    _errorMessage = null;
    notifyListeners();

    final epoch = _accountEpoch;
    final fetched = await repository.getGroup(
      groupId,
      forceRefresh: true,
      allowStale: false,
    );
    if (epoch != _accountEpoch) return false;
    final current = fetched.fold<Group?>((failure) {
      _errorMessage = AppErrorFeedback.messageOf(failure);
      AppErrorFeedback.report(
        failure,
        kind: AppErrorKind.load,
        context: 'leaveGroup',
      );
      return null;
    }, (group) => group);
    if (current == null) {
      _isLeaving = false;
      notifyListeners();
      return false;
    }
    final soleOwner =
        canManage(current) &&
        current.members.length == 1 &&
        current.members.single.role == GroupRole.owner;
    if (expectedDelete != null && expectedDelete != soleOwner) {
      final index = _groups.indexWhere((group) => group.id == groupId);
      if (index >= 0) _groups[index] = current;
      _isLeaving = false;
      final message = _l10n?.groupExitChanged;
      if (message != null) AppSnackBar.show(message);
      notifyListeners();
      return false;
    }
    final result = soleOwner
        ? await repository.deleteGroup(groupId)
        : await repository.leaveGroup(groupId);
    if (epoch != _accountEpoch) return false;
    final ok = result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'leaveGroup',
        );
        return false;
      },
      (_) {
        _discardGroup(groupId);
        return true;
      },
    );

    _isLeaving = false;
    notifyListeners();
    return ok;
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    final token = ++_epoch;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await loadGroups(forceRefresh: forceRefresh);
    if (token != _epoch) {
      return;
    }

    _finishInitialLoad();
  }

  void _finishInitialLoad() {
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  void clear() {
    _epoch++;
    _accountEpoch++;
    repository.clearCache();
    _openGroups.clear();
    _groupAccessRevisions.clear();
    _unreadGroupCount = 0;
    _groups = [];
    _query = '';
    _filter = GroupsFilter.all;
    _searching = false;
    _isLoading = false;
    _isLeaving = false;
    _confirmingExit = false;
    _isDeletingGroup = false;
    _isCreating = false;
    _hasLoaded = false;
    _hasGroupsSnapshot = false;
    _errorMessage = null;
    notifyListeners();
  }
}

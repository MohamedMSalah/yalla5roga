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
  int _filter = 0;
  var _searching = false;
  var _query = '';
  String? _createImage;
  final _createPhones = <String>[];
  var _isLoading = false;
  var _isLeaving = false;
  var _isCreating = false;
  var _hasLoaded = false;
  String? _errorMessage;
  var _epoch = 0;
  final _openGroups = <String, int>{};
  final _loadedRosters = <String>{};
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

  List<Group> get groups => List.unmodifiable(_groups);

  int get unreadGroupCount => _unreadGroupCount;

  bool get isLoading => _isLoading;

  bool get isLeaving => _isLeaving;

  bool get isCreating => _isCreating;

  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoading => !_hasLoaded;

  String? get errorMessage => _errorMessage;

  int get filter => _filter;

  bool get searching => _searching;

  String get query => _query;

  String? get createImage => _createImage;

  List<String> get createPhones => List.unmodifiable(_createPhones);

  List<GroupMember> get contacts => repository.contacts;

  String groupsForMember(String id) => repository.groupsForMember(id);

  GroupMember? memberById(String id) => repository.memberById(id);

  GroupMember? memberByPhone(String phone) => repository.memberByPhone(phone);

  List<Group> get visible {
    final needle = _query.trim().toLowerCase();
    final items = [
      for (final group in _groups)
        if ((_filter != 2 || group.isOwner) &&
            (needle.isEmpty || group.name.toLowerCase().contains(needle)))
          group,
    ];
    if (_filter == 1) {
      items.sort((a, b) => b.outingCount.compareTo(a.outingCount));
    }
    return items;
  }

  Group? findById(String id) {
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

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
    final existing = findById(groupId);
    if (allowStale &&
        !forceRefresh &&
        _loadedRosters.contains(groupId) &&
        existing != null &&
        existing.members.isNotEmpty) {
      return existing;
    }

    if (allowStale &&
        !OfflineSnapshots.cacheOnly &&
        (existing == null || existing.members.isEmpty)) {
      final preview = await OfflineSnapshots.preview(
        () => repository.getGroup(groupId, forceRefresh: true),
      );
      if (epoch != _epoch) return null;
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
    if (epoch != _epoch) return null;
    return result.fold(
      (failure) {
        if (failure.statusCode == 403 || failure.statusCode == 404) {
          _loadedRosters.remove(groupId);
          _groups.removeWhere((item) => item.id == groupId);
          notifyListeners();
          return null;
        }
        return allowStale ? findById(groupId) : null;
      },
      (group) {
        if (!OfflineSnapshots.cacheOnly) _loadedRosters.add(groupId);
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

  Future<void> loadGroups({bool forceRefresh = false}) async {
    final epoch = _epoch;
    if (forceRefresh) _loadedRosters.clear();
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
            if (existing[group.id] case final previous?)
              group.copyWith(
                members: group.listedMemberCount == previous.memberCount
                    ? previous.members
                    : const [],
                pendingMembers: previous.pendingMembers,
                invitationHistory: previous.invitationHistory,
              )
            else
              group,
        ];
        _errorMessage = null;
      },
    );
    _hasLoaded = true;
    notifyListeners();
  }

  void setFilter(int value) {
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
  }) async {
    if (_isCreating || name.trim().isEmpty) return null;

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
        // If the phone belongs to an existing app user, use API invitation (no WhatsApp).
        // Otherwise, send a WhatsApp invitation to the non-user.
        final known = repository.memberByPhone(phone);
        final whatsappOptIn = known == null;
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

    final added = await AddMemberPhoneSheet.show();
    if (added == null) return;

    final error = await inviteMember(
      groupId,
      added.phone,
      l10n,
      whatsappOptIn: added.whatsappOptIn,
    );
    // API failures already surface via AppErrorFeedback; validation only here.
    if (error != null) {
      AppSnackBar.show(error);
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

  Future<void> confirmLeaveGroup(String groupId) async {
    final l10n = _l10n;
    if (l10n == null) return;

    final confirmed = await AppAlert.confirm(
      title: l10n.leaveGroupTitle,
      message: l10n.leaveGroupMessage,
      confirmText: l10n.leaveGroup,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (!confirmed) return;

    final ok = await leaveGroup(groupId);
    if (!ok) {
      // Failures already surface via AppErrorFeedback in leaveGroup.
      return;
    }

    AppSnackBar.show(l10n.leftGroup);
    shell.setIndex(1);
    Get.until((route) => route.isFirst);
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

  /// Leaves the group; the backend prevents the last owner from leaving.
  Future<bool> leaveGroup(String groupId) async {
    if (_isLeaving) return false;
    _isLeaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.leaveGroup(groupId);
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
        _groups = [
          for (final item in _groups)
            if (item.id != groupId) item,
        ];
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
    repository.clearCache();
    _openGroups.clear();
    _loadedRosters.clear();
    _unreadGroupCount = 0;
    _groups = [];
    _isLoading = false;
    _isLeaving = false;
    _isDeletingGroup = false;
    _isCreating = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/mock/mock_data.dart';
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
  GroupsProvider({required this.repository, required this.shell});

  final GroupsRepository repository;
  final ShellProvider shell;

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
    return [
      for (final group in _groups)
        if ((_filter != 1) &&
            (needle.isEmpty || group.name.toLowerCase().contains(needle)))
          group,
    ];
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

  Future<void> loadGroups({bool forceRefresh = false}) async {
    final result = await repository.getGroups(forceRefresh: forceRefresh);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'loadGroups',
        );
      },
      (groups) {
        _groups = List.of(groups);
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
    final error = Validators.phone(raw, l10n);
    if (error != null) return error;
    final phone = Validators.normalizePhone(raw);
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

  Future<Group?> createGroup(
    String name, {
    required String ownerName,
    String? ownerAvatar,
    String bio = '',
  }) async {
    if (_isCreating || name.trim().isEmpty) return null;
    final coverImage =
        _createImage ??
        (AppConfig.useMockData ? MockData.defaultCoverImage : null);
    if (coverImage == null) return null;

    _isCreating = true;
    notifyListeners();

    final members = [
      GroupMember(
        id: 'me',
        name: ownerName,
        avatar: ownerAvatar ?? '',
        role: GroupRole.owner,
      ),
      for (final phone in _createPhones) _memberFromPhone(phone),
    ];
    final group = Group(
      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      outings: 0,
      bio: bio.trim(),
      image: coverImage,
      members: members,
      cuserRole: GroupRole.owner,
    );
    final result = await repository.createGroup(group);
    Group? created;
    result.fold(
      (failure) {
        _errorMessage = failure.message;
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
    resetCreate(notify: false);
    _isCreating = false;
    notifyListeners();
    return created;
  }

  L10n? get _l10n {
    final context = Get.context;
    return context == null ? null : context.l10n;
  }

  Future<void> changeImage(String groupId) async {
    final l10n = _l10n;
    if (l10n == null) return;

    final url = await ImageSourceSheet.pick(title: l10n.changeGroupImage);
    if (url == null) return;

    final ok = await updateImage(groupId, url);
    if (ok) {
      AppSnackBar.show(l10n.groupImageUpdated);
    } else if (_errorMessage != null) {
      AppSnackBar.show(_errorMessage!);
    }
  }

  Future<void> promptAddMember(String groupId) async {
    final l10n = _l10n;
    if (l10n == null) return;

    final added = await AddMemberPhoneSheet.show();
    if (added == null) return;

    final error = await addMember(groupId, added, l10n);
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    final display = l10n.digits(MemberDisplayName.resolvePhone(added));
    AppSnackBar.show(l10n.memberAdded(display));
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
    } else if (_errorMessage != null) {
      AppSnackBar.show(_errorMessage!);
    }
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
      if (_errorMessage != null) AppSnackBar.show(_errorMessage!);
      return;
    }

    AppSnackBar.show(l10n.leftGroup);
    shell.setIndex(1);
    Get.until((route) => route.isFirst);
  }

  Future<bool> updateImage(String groupId, String url) async {
    final current = byId(groupId);
    final result = await repository.updateGroup(current.copyWith(image: url));
    final ok = result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'updateGroupImage',
        );
        return false;
      },
      (group) {
        _errorMessage = null;
        _groups = [
          for (final item in _groups)
            if (item.id == group.id) group else item,
        ];
        return true;
      },
    );
    notifyListeners();
    return ok;
  }

  /// Returns a localized validation/API error, or `null` on success.
  Future<String?> addMember(String groupId, String phone, L10n l10n) async {
    final group = byId(groupId);
    if (group.containsMember(id: phone, phone: phone)) {
      return l10n.phoneAlreadyAdded;
    }
    final member = _memberFromPhone(phone);
    final result = await repository.addMember(groupId, member);
    final error = result.fold<String?>(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'addMember',
        );
        return failure.message;
      },
      (updated) {
        _errorMessage = null;
        _groups = [
          for (final item in _groups)
            if (item.id == updated.id) updated else item,
        ];
        AnalyticsService.instance.joinGroup();
        return null;
      },
    );
    notifyListeners();
    return error;
  }

  Future<bool> removeMember(String groupId, GroupMember person) async {
    if (person.role == GroupRole.owner) return false;
    final result = await repository.removeMember(groupId, person.id);
    final ok = result.fold(
      (failure) {
        _errorMessage = failure.message;
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

  /// Leaves the group. Backend decides ownership transfer if the owner leaves.
  Future<bool> leaveGroup(String groupId) async {
    if (_isLeaving) return false;
    _isLeaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.leaveGroup(groupId);
    final ok = result.fold(
      (failure) {
        _errorMessage = failure.message;
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
      _finishInitialLoad();
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
    _unreadGroupCount = 0;
    _groups = [for (final group in _groups) group.copyWith(unread: 0)];
    _isLoading = false;
    _isLeaving = false;
    _isCreating = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  GroupMember _memberFromPhone(String phone) {
    final known = repository.memberByPhone(phone);
    if (known != null) {
      return GroupMember(
        id: known.id,
        name: known.name,
        avatar: known.avatar,
        phone: known.phone ?? phone,
        role: known.role,
      );
    }
    return GroupMember(id: phone, name: phone, phone: phone, avatar: '');
  }
}

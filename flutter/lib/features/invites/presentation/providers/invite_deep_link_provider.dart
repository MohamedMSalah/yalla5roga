import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invites/data/invite_link_parser.dart';
import 'package:yalla_5roga/features/invites/domain/entities/pending_group_invite.dart';
import 'package:yalla_5roga/features/invites/presentation/navigation/invite_deep_link_navigator.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

/// Listens for invite App Links / custom-scheme URIs and opens the group.
///
/// Logged-out taps are stashed in prefs until [flushPendingNavigation] runs
/// from [MainShell] after auth + sync claim.
class InviteDeepLinkProvider extends ChangeNotifier {
  InviteDeepLinkProvider({
    required SharedPreferences this._prefs,
    required bool Function() this._isAuthenticated,
    required GroupsProvider this._groups,
    required ShellProvider this._shell,
    InviteLinkParser parser = const InviteLinkParser(),
    AppLinks? appLinks,
  }) : _parser = parser,
       _appLinks = appLinks ?? AppLinks();

  static const prefsKey = 'pending_group_invite';

  final SharedPreferences _prefs;
  final bool Function() _isAuthenticated;
  final GroupsProvider _groups;
  final ShellProvider _shell;
  final InviteLinkParser _parser;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _sub;
  var _ready = false;
  var _initialHandled = false;
  var _flushing = false;
  PendingGroupInvite? _pending;

  bool get isReady => _ready;
  PendingGroupInvite? get pending => _pending;

  Future<void> initialize() async {
    if (_ready) return;

    _pending = _readStored();
    _sub = _appLinks.uriLinkStream.listen(
      _onUri,
      onError: (Object error, StackTrace stack) {
        debugPrint('[InviteDeepLink] stream error: $error\n$stack');
      },
    );

    _ready = true;
    notifyListeners();

    if (_initialHandled) return;
    _initialHandled = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _onUri(initial);
    } catch (error, stack) {
      debugPrint('[InviteDeepLink] getInitialLink failed: $error\n$stack');
    }
  }

  /// Call from [MainShell] once the user is authenticated and groups can load.
  Future<void> flushPendingNavigation() async {
    if (_flushing) return;
    if (!_isAuthenticated()) return;

    final invite = _pending ?? _readStored();
    if (invite == null) return;

    if (Get.key.currentState == null) return;

    _flushing = true;
    _pending = null;
    await _clearStored();
    notifyListeners();

    try {
      await InviteDeepLinkNavigator.open(
        invite,
        groups: _groups,
        shell: _shell,
      );
    } finally {
      _flushing = false;
    }
  }

  void _onUri(Uri uri) {
    final invite = _parser.parse(uri);
    if (invite == null) {
      debugPrint('[InviteDeepLink] ignored uri: $uri');
      return;
    }

    _pending = invite;
    unawaited(_store(invite));
    notifyListeners();

    if (_isAuthenticated() && Get.key.currentState != null) {
      unawaited(flushPendingNavigation());
    }
  }

  PendingGroupInvite? _readStored() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final invite = PendingGroupInvite.fromJson(map);
      return invite.isValid ? invite : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(PendingGroupInvite invite) async {
    await _prefs.setString(prefsKey, jsonEncode(invite.toJson()));
  }

  Future<void> _clearStored() async {
    await _prefs.remove(prefsKey);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

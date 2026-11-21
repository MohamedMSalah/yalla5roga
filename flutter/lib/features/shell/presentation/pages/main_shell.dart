import 'package:yalla_5roga/features/shell/presentation/shell_route_navigation.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/monitoring/startup_trace.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav_layout.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/groups_page.dart';
import 'package:yalla_5roga/features/home/presentation/pages/home_page.dart';
import 'package:yalla_5roga/features/invites/presentation/providers/invite_deep_link_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/outings_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/settings_page.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  /// Only build tabs the user has opened (home starts built). IndexedStack
  /// previously inflated every tab on first frame and janked cold start.
  final Set<int> _builtTabs = {0};
  final Map<int, Widget> _pageCache = {};
  FcmProvider? _fcm;
  ShellProvider? _shell;
  int _lastIndex = 0;
  bool? _routeVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.isCurrentOf(context) ?? true;
    if (visible && _routeVisible == false && _lastIndex <= 1) {
      context.read<AppSyncProvider>().openLists();
    }
    _routeVisible = visible;
  }

  void _tabChanged() {
    final index = _shell!.index;
    if (index == _lastIndex) return;
    _lastIndex = index;
    // Groups uses the mounted list and the session's normal sync triggers.
    if (index == 0) {
      context.read<AppSyncProvider>().openLists();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shell = context.read<ShellProvider>()..addListener(_tabChanged);
    _lastIndex = _shell!.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fcm = context.read<FcmProvider>()..attachShell(context);
      _bootstrapShellData();
      unawaited(_requestLaunchPermissions());
    });
  }

  @override
  void dispose() {
    _fcm?.detachShell(context);
    _shell?.removeListener(_tabChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<OutingsProvider>().refreshSchedule();
    }
  }

  void _bootstrapShellData() {
    StartupTrace.mark('home_interactive');
    unawaited(_loadShell());
  }

  Future<void> _requestLaunchPermissions() async {
    try {
      await AppPermissions.promptNotificationsOnLaunch(context.l10n);
      if (!mounted) return;
      if (await AppPermissions.isNotificationGranted) {
        if (!mounted) return;
        await context.read<FcmProvider>().afterPermissionPrompt();
      }
    } catch (error) {
      debugPrint('[Permissions] Notification request unavailable: $error');
    }
    if (!mounted) return;
    try {
      await AppPermissions.promptLocationOnLaunch(context.l10n);
    } catch (error) {
      debugPrint('[Permissions] Location request unavailable: $error');
    }
  }

  /// Start cache hydration before warming the other tabs.
  Future<void> _loadShell() async {
    final synchronization = context.read<AppSyncProvider>().start();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await synchronization;
    if (!mounted) return;
    StartupTrace.mark('home_feed_ready');
    unawaited(context.read<SavedOutingsProvider>().load());

    // After sync claim, open a stashed invite deep link into the group.
    await context.read<InviteDeepLinkProvider>().flushPendingNavigation();

    if (kDebugMode) {
      debugPrint(RequestDiagnostics.instance.formatSummary());
    }
  }

  Widget _pageFor(int index, ShellProvider shell) {
    if (!_builtTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return HomePage(
            onSeeAllOutings: shell.openOutings,
            onDiscover: shell.openDiscover,
          );
        case 1:
          return const GroupsPage();
        case 2:
          return const OutingsPage();
        case 3:
          return const DiscoverPage();
        case 4:
          return const SettingsPage();
        default:
          return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = context.watch<ShellProvider>();
    _builtTabs.add(shell.index);

    return AppBottomNavLayout(
      currentIndex: shell.index,
      onChanged: shell.setIndex,
      pages: [
        _pageFor(0, shell),
        _pageFor(1, shell),
        _pageFor(2, shell),
        _pageFor(3, shell),
        _pageFor(4, shell),
      ],
      items: shellNavigationItems(l10n),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/monitoring/startup_trace.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav_layout.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fcm = context.read<FcmProvider>()..attachShell(context);
      _bootstrapShellData();
    });
  }

  @override
  void dispose() {
    _fcm?.detachShell(context);
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

  /// Start cache hydration before warming the other tabs.
  Future<void> _loadShell() async {
    final synchronization = context.read<AppSyncProvider>().start();
    // Give the initial cached content a frame before warming Discover.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await context.read<DiscoverProvider>().load();
    if (!mounted) return;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await AppPermissions.isNotificationGranted) return;
      if (!mounted) return;
      await AppPermissions.promptNotificationsOnLaunch(context.l10n);
      if (!mounted) return;
      await context.read<FcmProvider>().afterPermissionPrompt();
    });
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
      items: [
        AppBottomNavItem(icon: Icons.home_rounded, label: l10n.navHome),
        AppBottomNavItem(icon: Icons.groups_2_rounded, label: l10n.navGroups),
        AppBottomNavItem(
          icon: Icons.calendar_month_outlined,
          label: l10n.navOutings,
        ),
        AppBottomNavItem(icon: Icons.explore_outlined, label: l10n.navDiscover),
        AppBottomNavItem(
          icon: Icons.settings_outlined,
          label: l10n.navSettings,
        ),
      ],
    );
  }
}

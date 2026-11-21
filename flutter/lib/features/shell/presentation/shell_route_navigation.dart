import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

List<AppBottomNavItem> shellNavigationItems(L10n l10n) => [
  AppBottomNavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: l10n.navHome,
  ),
  AppBottomNavItem(
    icon: Icons.groups_2_outlined,
    selectedIcon: Icons.groups_2,
    label: l10n.navGroups,
  ),
  AppBottomNavItem(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    label: l10n.navOutings,
  ),
  AppBottomNavItem(
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    label: l10n.navDiscover,
  ),
  AppBottomNavItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: l10n.navSettings,
  ),
];

/// The same tab bar on a screen pushed from a shell section.
class ShellRouteNavigation extends StatelessWidget {
  const ShellRouteNavigation({
    super.key,
    required this.section,
    required this.l10n,
  });

  final int section;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellProvider?>();
    if (shell == null || MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    return AppBottomNav(
      items: shellNavigationItems(l10n),
      currentIndex: section,
      onChanged: (index) {
        shell.setIndex(index);
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/filter_chip_row.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/groups_list.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_skeleton.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch(GroupsProvider groups) {
    groups.openSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch(GroupsProvider groups) {
    _searchController.clear();
    _searchFocus.unfocus();
    groups.closeSearch();
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.read<GroupsProvider>();
    context.select<GroupsProvider, (bool, bool, int, int, int, String?)>(
      (provider) => (
        provider.isInitialLoading,
        provider.searching,
        provider.filter,
        provider.groups.length,
        provider.groups.fold<int>(0, (sum, group) => sum + group.memberCount),
        provider.errorMessage,
      ),
    );
    // Instant swap — a page-level FadeSwitcher here ran during tab switches
    // and dropped frames over the groups list.
    if (groups.isInitialLoading) {
      return const GroupsSkeleton();
    }

    final l10n = context.l10n;
    final palette = context.palette;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: Responsive.pagePadding().add(
              EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.groupsTitle,
                            style: context.texts.headlineSmall,
                          ),
                          Text(
                            l10n.activeGroupsFriends(
                              groups.groups.length,
                              groups.groups.fold<int>(
                                0,
                                (sum, group) => sum + group.memberCount,
                              ),
                            ),
                            style: context.texts.bodyMedium?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NotificationButton(),
                  ],
                ),
                Responsive.spaceSm.gapH,
                Row(
                  children: [
                    if (groups.searching)
                      Expanded(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: groups.setQuery,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: l10n.searchGroups,
                              filled: true,
                              fillColor: palette.inputFill,
                              prefixIcon: Icon(
                                Icons.search,
                                color: palette.textMuted,
                                size: 20.w,
                              ),
                              suffixIcon: IconButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonTooltip,
                                icon: Icon(
                                  Icons.close,
                                  size: 18.w,
                                  color: palette.textMuted,
                                ),
                                onPressed: () => _closeSearch(groups),
                              ),
                              contentPadding: Responsive.padding(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      IconButton.outlined(
                        tooltip: l10n.searchGroups,
                        icon: const Icon(Icons.search),
                        onPressed: () => _openSearch(groups),
                      ),
                    Responsive.spaceSm.gapW,
                    if (groups.searching)
                      IconButton.filled(
                        tooltip: l10n.newGroup,
                        icon: const Icon(Icons.add),
                        onPressed: () => Get.to(() => const CreateGroupPage()),
                      )
                    else
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(l10n.newGroup),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () =>
                              Get.to(() => const CreateGroupPage()),
                        ),
                      ),
                  ],
                ),
                Responsive.spaceMd.gapH,
                FilterChipRow(
                  labels: [l10n.allGroups, l10n.mostActive, l10n.recentlyAdded],
                  index: groups.filter,
                  onChanged: groups.setFilter,
                ),
                Responsive.spaceMd.gapH,
                if (groups.errorMessage != null && groups.groups.isEmpty)
                  TextButton(
                    onPressed: () => groups.refresh(forceRefresh: true),
                    child: Text(l10n.tryAgain),
                  )
                else
                  const GroupsList(),
                Responsive.spaceLg.gapH,
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

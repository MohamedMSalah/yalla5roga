import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/widgets/app_page_header.dart';
import 'package:yalla_5roga/core/widgets/app_search_field.dart';
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

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: Responsive.pagePadding().add(
                  EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    AppPageHeader(
                      title: l10n.groupsTitle,
                      subtitle: l10n.activeGroupsFriends(
                        groups.groups.length,
                        groups.groups.fold<int>(
                          0,
                          (sum, group) => sum + group.memberCount,
                        ),
                      ),
                      trailing: const NotificationButton(),
                    ),
                    Responsive.spaceSm.gapH,
                    AppOfflineIndicator(
                      isOffline: context.select<AppSyncProvider, bool>(
                        (p) => p.status == SyncStatus.offline,
                      ),
                    ),
                    Row(
                      children: [
                        if (groups.searching)
                          Expanded(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: AppSearchField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                hint: l10n.searchGroups,
                                onChanged: groups.setQuery,
                                onClear: () => _closeSearch(groups),
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
                            onPressed: () =>
                                Get.to(() => const CreateGroupPage()),
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
                      labels: [
                        l10n.allGroups,
                        l10n.mostActive,
                        l10n.ownedGroups,
                      ],
                      index: groups.filter,
                      onChanged: groups.setFilter,
                    ),
                    Responsive.spaceMd.gapH,
                    if (groups.errorMessage != null && groups.groups.isEmpty)
                      AppErrorState(
                        message: groups.errorMessage!,
                        onRetry: () => groups.refresh(forceRefresh: true),
                      )
                    else
                      const GroupsList(),
                    Responsive.spaceLg.gapH,
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

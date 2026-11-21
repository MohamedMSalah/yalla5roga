import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_style.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

typedef _ListState = ({
  List<String> ids,
  bool searching,
  bool loading,
  String? error,
});

class GroupsList extends StatelessWidget {
  const GroupsList({super.key, required this.onOpenGroup});

  final ValueChanged<String> onOpenGroup;

  @override
  Widget build(BuildContext context) =>
      Selector2<GroupsProvider, OutingsProvider, _ListState>(
        selector: (_, groups, outings) => (
          ids: groups.visibleGroupIds(
            groups.filter == GroupsFilter.mostActive
                ? outings.groupOutingCounts
                : null,
          ),
          searching: groups.query.trim().isNotEmpty,
          loading: groups.isInitialLoading && groups.groups.isEmpty,
          error: groups.groups.isEmpty ? groups.errorMessage : null,
        ),
        shouldRebuild: (before, after) =>
            before.loading != after.loading ||
            before.error != after.error ||
            before.searching != after.searching ||
            !listEquals(before.ids, after.ids),
        builder: (context, state, _) {
          final provider = context.read<GroupsProvider>();
          if (state.loading) return const GroupsSkeleton();
          if (state.error case final message?) {
            return SliverToBoxAdapter(
              child: AppErrorState(
                message: message,
                onRetry: () => provider.refresh(forceRefresh: true),
              ),
            );
          }
          if (state.ids.isEmpty) {
            return SliverToBoxAdapter(
              child: _EmptyGroups(
                searching: state.searching,
                onClear: () => provider.setQuery(''),
              ),
            );
          }
          final indexById = {
            for (final (index, id) in state.ids.indexed) id: index,
          };
          return SliverList.builder(
            itemCount: state.ids.length,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? indexById[key.value] : null,
            itemBuilder: (context, index) {
              final id = state.ids[index];
              return Padding(
                key: ValueKey(id),
                padding: EdgeInsets.only(top: index == 0 ? 0 : GroupsStyle.gap),
                child: _GroupListItem(id: id, onOpenGroup: onOpenGroup),
              );
            },
          );
        },
      );
}

typedef _CardData = ({
  String name,
  String bio,
  String image,
  int? members,
  int? outings,
});

class _GroupListItem extends StatelessWidget {
  const _GroupListItem({required this.id, required this.onOpenGroup});

  final String id;
  final ValueChanged<String> onOpenGroup;

  @override
  Widget build(BuildContext context) =>
      Selector2<GroupsProvider, OutingsProvider, _CardData?>(
        selector: (_, groups, outings) {
          final group = groups.listedGroup(id);
          if (group == null) return null;
          final counts = outings.groupOutingCounts;
          return (
            name: group.name,
            bio: group.bio,
            image: group.image,
            members: group.acceptedMemberCount,
            outings: counts == null ? null : counts[id] ?? 0,
          );
        },
        builder: (_, data, _) => data == null
            ? const SizedBox.shrink()
            : GroupCard(
                groupId: id,
                name: data.name,
                bio: data.bio,
                image: data.image,
                members: data.members,
                outings: data.outings,
                onTap: () => onOpenGroup(id),
              ),
      );
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.searching, required this.onClear});

  final bool searching;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppEmptyState(
          icon: searching ? Icons.search_off_rounded : Icons.groups_outlined,
          message: searching ? l10n.noGroupsFound : l10n.noGroups,
          subtitle: searching ? null : l10n.noGroupsHint,
          compact: true,
        ),
        if (searching)
          TextButton(onPressed: onClear, child: Text(l10n.clearGroupSearch)),
      ],
    );
  }
}

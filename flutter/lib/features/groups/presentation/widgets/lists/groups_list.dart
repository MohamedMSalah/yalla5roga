import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/create_group_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_card.dart';

/// Groups list: title + group cards / empty state.
class GroupsList extends StatelessWidget {
  const GroupsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();
    final items = groups.visible;
    final showCreate = groups.query.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.groupsTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        if (items.isEmpty)
          AppEmptyState(
            icon: showCreate
                ? Icons.groups_outlined
                : Icons.search_off_outlined,
            message: showCreate ? l10n.noGroups : l10n.noGroupsFound,
            subtitle: showCreate ? l10n.noGroupsHint : l10n.noGroupsFoundHint,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length + (showCreate ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 10.h),
                  child: CreateGroupCard(
                    onTap: () => Get.to(() => const CreateGroupPage()),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: GroupCard(
                  group: items[index],
                  onTap: () =>
                      Get.to(() => GroupDetailsPage(groupId: items[index].id)),
                ),
              );
            },
          ),
      ],
    );
  }
}

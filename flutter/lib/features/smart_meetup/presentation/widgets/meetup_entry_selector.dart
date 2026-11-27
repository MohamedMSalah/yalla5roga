import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/invite_friends_banner.dart';

import '../pages/group_smart_meetup_page.dart';
import '../pages/quick_meetup_page.dart';

enum _MeetupEntry { group, quick }

class MeetupEntrySelector extends StatelessWidget {
  const MeetupEntrySelector({super.key});

  static Future<void> show(BuildContext context) async {
    final auth = context.read<AuthProvider?>();
    final account = auth?.user?.id;
    if (account == null) return;
    FocusScope.of(context).unfocus();
    final entry = await AppBottomSheet.show<_MeetupEntry>(
      context: context,
      builder: (_) => const MeetupEntrySelector(),
    );
    if (!context.mounted || auth?.user?.id != account || entry == null) return;
    if (entry == _MeetupEntry.quick) {
      await Get.to(() => const QuickMeetupPage());
      return;
    }

    final groups = context.read<GroupsProvider>();
    if (!groups.hasLoaded) unawaited(groups.loadGroups());
    final groupId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
      builder: (context) => Consumer<GroupsProvider>(
        builder: (context, provider, _) {
          if (provider.groups.isNotEmpty) {
            return InviteGroupPicker(groups: provider.groups);
          }
          return SafeArea(
            child: Padding(
              padding: Responsive.pagePadding(),
              child: provider.isLoading
                  ? const Center(
                      heightFactor: 2,
                      child: CircularProgressIndicator(),
                    )
                  : provider.errorMessage != null
                  ? AppErrorState(
                      message: context.l10n.dataLoadFailed,
                      onRetry: () => provider.loadGroups(forceRefresh: true),
                    )
                  : Text(
                      context.l10n.meetupNoGroups,
                      textAlign: TextAlign.center,
                    ),
            ),
          );
        },
      ),
    );
    if (groupId != null && context.mounted && auth?.user?.id == account) {
      await Get.to(() => GroupSmartMeetupPage(groupId: groupId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.smartMeetup, style: context.texts.titleLarge),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.groups_outlined),
          title: Text(l10n.meetupChooseExistingGroup),
          onTap: () => Navigator.of(context).pop(_MeetupEntry.group),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.route_outlined),
          title: Text(l10n.quickMeetup),
          onTap: () => Navigator.of(context).pop(_MeetupEntry.quick),
        ),
      ],
    );
  }
}

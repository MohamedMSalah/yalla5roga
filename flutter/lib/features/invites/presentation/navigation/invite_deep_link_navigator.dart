import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invites/domain/entities/pending_group_invite.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

/// Opens a group invite deep link after membership may have been claimed on sync.
class InviteDeepLinkNavigator {
  const InviteDeepLinkNavigator._();

  static Future<void> open(
    PendingGroupInvite invite, {
    required GroupsProvider groups,
    ShellProvider? shell,
  }) async {
    try {
      shell?.openGroups();
      await groups.refresh();
      await groups.ensureGroupLoaded(invite.groupId);
      Get.to(() => GroupDetailsPage(groupId: invite.groupId));
    } catch (error, stack) {
      debugPrint('[InviteDeepLink] open failed: $error\n$stack');
    }
  }
}

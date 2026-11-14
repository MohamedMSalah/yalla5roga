import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/invitations/presentation/widgets/invitations_list.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/invitations/presentation/widgets/invitations_states.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/invitations/presentation/widgets/outing_invitation_target.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key, this.invitedOuting});
  final Outing? invitedOuting;

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<InvitationsProvider>().loadInvitations(forceRefresh: true);
      }
    });
  }

  Future<void> _accept(GroupInvitation invitation) async {
    final l10n = context.l10n;
    final provider = context.read<InvitationsProvider>();
    final groups = context.read<GroupsProvider>();

    final success = await provider.acceptInvitation(invitation.invitationId);
    if (success && mounted) {
      AppSnackBar.show(l10n.invitationAccepted(invitation.groupName));
      await groups.loadGroups(forceRefresh: true);
      if (!mounted) return;
      Get.to(() => GroupDetailsPage(groupId: invitation.groupId));
    }
  }

  Future<void> _decline(GroupInvitation invitation) async {
    final l10n = context.l10n;
    final confirmed = await _confirmDecline(l10n);
    if (!confirmed || !mounted) return;

    final provider = context.read<InvitationsProvider>();
    final success = await provider.declineInvitation(invitation.invitationId);
    if (success && mounted) {
      AppSnackBar.show(l10n.invitationDeclined(invitation.groupName));
    }
  }

  Future<bool> _confirmDecline(L10n l10n) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.declineInvitationTitle),
            content: Text(l10n.declineInvitationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.decline),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InvitationsProvider>();

    return Scaffold(
      appBar: AppPageBar(title: l10n.invitations),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Column(
              children: [
                if (widget.invitedOuting case final outing?)
                  OutingInvitationTarget(outing: outing),
                Expanded(child: _buildBody(l10n, provider)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(L10n l10n, InvitationsProvider provider) {
    if (provider.isInitialLoading ||
        (provider.isLoading && provider.items.isEmpty)) {
      return const InvitationsSkeleton();
    }

    if (provider.errorMessage != null && provider.items.isEmpty) {
      return InvitationsErrorState(
        message: provider.errorMessage!,
        onRetry: () => provider.loadInvitations(forceRefresh: true),
      );
    }

    if (provider.items.isEmpty) {
      return InvitationsEmptyState(l10n: l10n);
    }

    return InvitationsList(
      provider: provider,
      onAccept: _accept,
      onDecline: _decline,
    );
  }
}

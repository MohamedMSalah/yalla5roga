import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/filter_chip_row.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/invitations/presentation/widgets/group_invitation_card.dart';
import 'package:yalla_5roga/features/invitations/presentation/widgets/invitations_states.dart';

class InvitationsList extends StatefulWidget {
  const InvitationsList({
    super.key,
    required this.provider,
    required this.onAccept,
    required this.onDecline,
  });
  final InvitationsProvider provider;
  final ValueChanged<GroupInvitation> onAccept, onDecline;
  @override
  State<InvitationsList> createState() => _InvitationsListState();
}

class _InvitationsListState extends State<InvitationsList> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = widget.provider;
    final status = switch (_filter) {
      1 => InvitationStatus.pending,
      2 => InvitationStatus.accepted,
      3 => InvitationStatus.declined,
      _ => null,
    };
    final items = provider.items
        .where((i) => status == null || i.status == status)
        .toList();
    final busy = provider.isAccepting || provider.isDeclining;
    return Column(
      children: [
        Padding(
          padding: Responsive.pagePadding().copyWith(top: 0, bottom: 0),
          child: FilterChipRow(
            labels: [
              l10n.all,
              l10n.pendingInvitationStatus,
              l10n.acceptedInvitationStatus,
              l10n.declinedInvitationStatus,
            ],
            index: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? SingleChildScrollView(child: InvitationsEmptyState(l10n: l10n))
              : ListView.separated(
                  padding: Responsive.pagePadding(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Responsive.spaceMd.gapH,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final processing =
                        provider.processingId == item.invitationId;
                    return GroupInvitationCard(
                      key: ValueKey(item.invitationId),
                      invitation: item,
                      onAccept: busy ? null : () => widget.onAccept(item),
                      onDecline: busy ? null : () => widget.onDecline(item),
                      isAccepting: processing && provider.isAccepting,
                      isDeclining: processing && provider.isDeclining,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

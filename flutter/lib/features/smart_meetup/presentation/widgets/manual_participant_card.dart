import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_chip.dart';

import '../../domain/entities/standalone_participant.dart';

class ManualParticipantCard extends StatelessWidget {
  const ManualParticipantCard({
    super.key,
    required this.participant,
    this.onFocus,
    this.onEdit,
    this.onRemove,
  });

  final StandaloneParticipant participant;
  final VoidCallback? onFocus, onEdit, onRemove;

  static const ownerIcon = Icons.person_pin_circle_outlined;
  static const guestIcon = Icons.place_outlined;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owner = participant.isOwner;
    final label = participant.displayName;
    final area = participant.approximateArea;
    final title = owner ? l10n.meetupOwner : label ?? l10n.meetupGuest;
    final location = owner
        ? (participant.latitude == null
              ? l10n.meetupNeedsSetup
              : area ?? l10n.meetupOwnerDefault)
        : area ?? l10n.meetupApproximatePoint;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(owner ? ownerIcon : guestIcon),
      title: Text(title),
      subtitle: Text(
        [
          if (!owner && label != null) l10n.meetupGuest,
          location,
          TransportationModeChip.label(l10n, participant.transportation),
        ].join(' · '),
      ),
      onTap: onFocus,
      trailing: !owner && (onEdit != null || onRemove != null)
          ? PopupMenuButton<VoidCallback>(
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                if (onEdit case final edit?)
                  PopupMenuItem(value: edit, child: Text(l10n.meetupEditGuest)),
                if (onRemove case final remove?)
                  PopupMenuItem(
                    value: remove,
                    child: Text(l10n.meetupRemoveGuest),
                  ),
              ],
            )
          : null,
    );
  }
}

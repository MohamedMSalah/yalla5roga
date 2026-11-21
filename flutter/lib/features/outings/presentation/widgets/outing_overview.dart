import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';

import 'outing_info_style.dart';

class OutingOverview extends StatelessWidget {
  const OutingOverview({
    super.key,
    required this.outing,
    required this.cover,
    required this.tied,
    required this.participantCount,
    required this.canOpenGroup,
  });

  final Outing outing;
  final Widget cover;
  final bool tied;
  final int? participantCount;
  final bool canOpenGroup;

  @override
  Widget build(BuildContext context) {
    final group = context.select(
      (GroupsProvider store) => store.findById(outing.groupId ?? ''),
    );
    final l10n = context.l10n;
    final style = OutingInfoStyle(context);
    final confirmed = outing.status == OutingStatus.confirmed && !tied;
    final facts = [
      _MetadataItem(
        Icons.calendar_today_outlined,
        outing.localizedDate(l10n),
        outing.localizedTime(l10n),
      ),
      if (group != null)
        _MetadataItem(
          Icons.group_outlined,
          l10n.outingGroupLabel,
          group.name,
          onTap: canOpenGroup
              ? () => Get.to(() => GroupDetailsPage(groupId: group.id))
              : null,
        ),
      if (participantCount != null)
        _MetadataItem(
          Icons.groups_outlined,
          l10n.outingParticipants,
          l10n.n(participantCount!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            cover,
            PositionedDirectional(
              start: 11,
              end: 11,
              top: 9,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: confirmed
                          ? const [Color(0xFF247C60), Color(0xFF278463)]
                          : tied
                          ? const [Color(0xFF70461D), Color(0xFF59326B)]
                          : const [Color(0xFF543373), Color(0xFF362344)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tied
                              ? Icons.balance
                              : confirmed
                              ? Icons.check
                              : Icons.event_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tied
                                ? l10n.outingTieBadge
                                : outing.statusLabel(l10n),
                            style: style.type(12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 8, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  outing.title,
                  style: style.type(26, weight: FontWeight.w700),
                ),
              ),
              if (outing.occasion != OutingOccasion.none) ...[
                const SizedBox(height: 5),
                Text(
                  outing.occasion.label(l10n),
                  style: style.type(13, color: style.secondary),
                ),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: style.dark
                ? const Color(0xFF17141C)
                : context.palette.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: LayoutBuilder(
            builder: (context, limits) {
              final vertical =
                  limits.maxWidth < 290 ||
                  MediaQuery.textScalerOf(context).scale(13) > 17;
              if (vertical) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: facts,
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < facts.length; i++) ...[
                    if (i > 0)
                      Container(width: 1, height: 32, color: style.border),
                    Expanded(flex: i == 0 ? 11 : 10, child: facts[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem(this.icon, this.title, this.subtitle, {this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 51),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: style.control,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: style.icon),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: style.type(11.5, weight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: style.type(11, color: style.secondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: body,
            ),
          );
  }
}

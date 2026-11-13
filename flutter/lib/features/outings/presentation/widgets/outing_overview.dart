import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';

class OutingOverview extends StatelessWidget {
  const OutingOverview({super.key, required this.outing, required this.cover});
  final Outing outing;
  final Widget cover;
  @override
  Widget build(BuildContext context) {
    final group = context.watch<GroupsProvider>().findById(
      outing.groupId ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cover,
        Responsive.spaceMd.gapH,
        Semantics(
          header: true,
          child: Text(outing.title, style: context.texts.headlineSmall),
        ),
        Responsive.spaceSm.gapH,
        Wrap(
          spacing: Responsive.spaceSm,
          runSpacing: Responsive.spaceSm,
          children: [
            AppBadge(
              label: outing.statusLabel(context.l10n),
              color: context.palette.brandSoft,
              textColor: context.palette.brandStrong,
            ),
            if (outing.occasion != OutingOccasion.none)
              Text(
                outing.occasion == OutingOccasion.birthday
                    ? context.l10n.birthday
                    : context.l10n.wedding,
              ),
          ],
        ),
        if (group != null) ...[
          Responsive.spaceSm.gapH,
          Text(group.name, style: context.texts.titleMedium),
        ],
        Responsive.spaceSm.gapH,
        Wrap(
          spacing: Responsive.spaceMd,
          runSpacing: Responsive.spaceSm,
          children: [
            Text(
              outing.localizedDate(context.l10n),
              style: context.texts.titleSmall,
            ),
            Text(
              outing.localizedTime(context.l10n),
              style: context.texts.titleSmall,
            ),
          ],
        ),
      ],
    );
  }
}

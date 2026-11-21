import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/stat_card.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outingCount = context.watch<OutingsProvider>().outings.length;
    final groupCount = context.watch<GroupsProvider>().groups.length;
    final completed = context
        .watch<OutingsProvider>()
        .outings
        .where((outing) => outing.status == OutingStatus.past)
        .length;
    final loaded = context.watch<OutingsProvider>().hasLoaded;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                value: context.watch<GroupsProvider>().hasLoaded
                    ? l10n.n(groupCount)
                    : '—',
                label: l10n.groupsStat,
                icon: Icons.groups_outlined,
              ),
            ),
            const VerticalDivider(width: 12),
            Expanded(
              child: StatCard(
                value: loaded ? l10n.n(outingCount) : '—',
                label: l10n.outingsStat,
                icon: Icons.calendar_month_outlined,
              ),
            ),
            const VerticalDivider(width: 12),
            Expanded(
              child: StatCard(
                value: loaded ? l10n.n(completed) : '—',
                label: l10n.completedOuting,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

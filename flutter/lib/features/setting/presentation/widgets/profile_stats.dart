import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outingCount = context.watch<OutingsProvider>().outings.length;
    final groupCount = context.watch<GroupsProvider>().groups.length;
    return AppCard(
      radius: 20,
      child: Row(
        children: [
          _stat(context, l10n.n(outingCount), l10n.outingsStat),
          Container(width: 1.w, height: 36.h, color: context.palette.border),
          _stat(context, l10n.n(groupCount), l10n.groupsStat),
          Container(width: 1.w, height: 36.h, color: context.palette.border),
          // TODO: compute show-up from real outing attendance when that API exists.
          _stat(context, '—', l10n.showUp),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: Responsive.fontXs,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

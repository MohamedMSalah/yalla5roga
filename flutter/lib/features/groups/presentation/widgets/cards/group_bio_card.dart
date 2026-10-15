import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

class GroupBioCard extends StatelessWidget {
  const GroupBioCard({super.key, required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final isEmpty = bio.trim().isEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.groupBio,
            style: TextStyle(
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: Responsive.fontCaption,
            ),
          ),
          6.gapH,
          Text(
            isEmpty ? l10n.noGroupBio : bio,
            style: TextStyle(
              color: isEmpty ? palette.textMuted : palette.textPrimary,
              fontSize: Responsive.fontBody,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

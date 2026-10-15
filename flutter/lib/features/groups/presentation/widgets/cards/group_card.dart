import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, this.onTap});

  final Group group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outingCount = context
        .watch<OutingsProvider>()
        .forGroup(group.id)
        .length;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AppNetworkImage(
            url: group.avatars.isNotEmpty ? group.avatars.first : group.image,
            width: 56.w,
            height: 56.w,
            radius: 16.r,
          ),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(
                      context.chevronForward,
                      color: context.palette.border,
                      size: 20.w,
                    ),
                  ],
                ),
                Text(
                  l10n.membersOutings(group.memberCount, outingCount),
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

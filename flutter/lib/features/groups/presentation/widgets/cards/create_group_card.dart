import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';

class CreateGroupCard extends StatelessWidget {
  const CreateGroupCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      onTap: onTap,
      color: context.palette.brandSoft,
      padding: EdgeInsets.all(Responsive.spaceMd),
      child: Row(
        children: [
          IconCircle(
            icon: Icons.person_add_alt_1_outlined,
            background: context.palette.surface,
            foreground: context.palette.brandStrong,
          ),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.startNewCircle,
                  style: TextStyle(
                    color: context.palette.brandStrong,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontBody,
                  ),
                ),
                Text(
                  l10n.inviteWithLink,
                  style: TextStyle(
                    color: context.palette.brandStrong,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            context.chevronForward,
            color: context.palette.brandStrong,
            size: 18.w,
          ),
        ],
      ),
    );
  }
}

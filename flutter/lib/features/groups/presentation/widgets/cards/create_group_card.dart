import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
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
      color: AppColors.brand50.withValues(alpha: 0.7),
      radius: 22,
      padding: EdgeInsets.all(Responsive.spaceMd),
      child: Row(
        children: [
          const IconCircle(
            icon: Icons.person_add_alt_1_outlined,
            background: Colors.white,
            foreground: AppColors.brand600,
          ),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.startNewCircle,
                  style: TextStyle(
                    color: AppColors.brand700,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontBody,
                  ),
                ),
                Text(
                  l10n.inviteWithLink,
                  style: TextStyle(color: AppColors.brand500, fontSize: 10.sp),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_outward, color: AppColors.brand600, size: 18.w),
        ],
      ),
    );
  }
}

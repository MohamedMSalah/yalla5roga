import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';

class OutingListTile extends StatelessWidget {
  const OutingListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String image;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final details = Row(
      children: [
        AppNetworkImage(
          url: image,
          width: 48.w,
          height: 48.w,
          radius: 12.r,
          placeholderIcon: Icons.explore_outlined,
        ),
        12.gapW,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return AppCard(
      onTap: trailing == null ? onTap : null,
      radius: 20,
      child: Row(
        children: [
          Expanded(
            child: trailing == null || onTap == null
                ? details
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: details,
                  ),
          ),
          if (trailing != null) ...[
            8.gapW,
            trailing!,
          ] else
            Icon(
              context.chevronForward,
              color: context.palette.border,
              size: 20.w,
            ),
        ],
      ),
    );
  }
}

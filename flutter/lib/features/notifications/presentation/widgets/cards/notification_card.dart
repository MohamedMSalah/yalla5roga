import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.body,
    required this.time,
    required this.unread,
    this.image,
    this.icon,
    this.iconBackground,
    this.iconForeground,
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  final String body;
  final String time;
  final bool unread;
  final String? image;
  final IconData? icon;
  final Color? iconBackground;
  final Color? iconForeground;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: unread ? context.palette.brandSoft : context.palette.surface,
      radius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            AppNetworkImage(
              url: image!,
              width: 44.w,
              height: 44.w,
              radius: 12.r,
            )
          else
            IconCircle(
              icon: icon ?? Icons.notifications_none,
              background: iconBackground,
              foreground: iconForeground,
            ),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body, style: TextStyle(fontSize: 12.sp, height: 1.35)),
                Responsive.spaceSm.gapH,
                Row(
                  children: [
                    Text(
                      context.l10n.digits(time),
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: Responsive.fontCaption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (actionLabel != null)
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.brand600,
                          foregroundColor: Colors.white,
                          minimumSize: Size(0, 28.h),
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                        ),
                        child: Text(
                          actionLabel!,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (unread)
            Padding(
              padding: EdgeInsets.only(left: 4.w, top: 4.h),
              child: CircleAvatar(
                radius: 4.r,
                backgroundColor: AppColors.brand600,
              ),
            ),
        ],
      ),
    );
  }
}

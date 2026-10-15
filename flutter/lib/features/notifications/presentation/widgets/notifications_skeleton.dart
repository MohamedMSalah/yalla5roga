import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';

class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.today.toUpperCase(),
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: Responsive.fontCaption,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        Responsive.spaceSm.gapH,
        AppShimmer(
          child: ListCard(
            children: const [
              ShimmerNotificationCard(unread: true),
              ShimmerNotificationCard(unread: true),
              ShimmerNotificationCard(),
            ],
          ),
        ),
        Responsive.spaceLg.gapH,
        Text(
          l10n.earlier.toUpperCase(),
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: Responsive.fontCaption,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        Responsive.spaceSm.gapH,
        AppShimmer(
          child: ListCard(
            children: const [
              ShimmerNotificationCard(),
              ShimmerNotificationCard(),
            ],
          ),
        ),
      ],
    );
  }
}

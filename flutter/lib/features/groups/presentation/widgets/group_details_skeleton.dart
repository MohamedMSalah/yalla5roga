import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

class GroupDetailsSkeleton extends StatelessWidget {
  const GroupDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: Responsive.pagePadding(),
      children: [
        AppShimmer(
          child: ShimmerBone(width: double.infinity, height: 180.h, radius: 22),
        ),
        Responsive.spaceMd.gapH,
        AppShimmer(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLine(width: 160.w, height: 18.h),
                    Responsive.spaceXs.gapH,
                    ShimmerLine(width: 120.w, height: 11.h),
                  ],
                ),
              ),
              ShimmerBone(width: 56.w, height: 22.h, radius: 999),
            ],
          ),
        ),
        Responsive.spaceMd.gapH,
        CustomButton(
          label: l10n.createOuting,
          icon: Icons.add,
          onPressed: () {},
        ),
        Responsive.spaceLg.gapH,
        Text(
          l10n.activeVotes,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        const AppShimmer(child: ShimmerOutingList(count: 2)),
        Responsive.spaceLg.gapH,
        Text(
          l10n.suggestPlaces,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        const AppShimmer(child: ShimmerOutingList(count: 2)),
        Responsive.spaceLg.gapH,
        Text(
          l10n.outingsTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        AppShimmer(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) 8.gapH,
                AppCard(
                  radius: 16,
                  child: Row(
                    children: [
                      ShimmerBone(width: 44.w, height: 44.w, radius: 12),
                      12.gapW,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerLine(width: 100.w, height: 12.h),
                            Responsive.spaceXs.gapH,
                            ShimmerLine(width: 64.w, height: 9.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

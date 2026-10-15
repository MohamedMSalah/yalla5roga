import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/core/widgets/segmented_tabs.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class OutingsSkeleton extends StatelessWidget {
  const OutingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return SafeArea(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: Responsive.pagePadding(),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionHeader(
                  eyebrow: l10n.makeAMemory,
                  title: l10n.outingsTitle,
                ),
              ),
              const NotificationButton(),
            ],
          ),
          Responsive.spaceSm.gapH,
          CustomButton(
            label: l10n.plan,
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => Get.to(() => const CreateOutingPage()),
          ),
          Responsive.spaceMd.gapH,
          SegmentedTabs(
            labels: [l10n.upcoming, l10n.voting, l10n.past],
            index: 0,
            onChanged: (_) {},
          ),
          Responsive.spaceLg.gapH,
          SectionHeader(
            title: l10n.discover,
            subtitle: l10n.exploreNearby,
            actionLabel: l10n.seeAll,
            onAction: () => Get.to(() => const DiscoverPage()),
          ),
          12.gapH,
          const AppShimmer(child: ShimmerDiscoverStrip(count: 4)),
          Responsive.spaceLg.gapH,
          Text(
            l10n.thisWeekend.toUpperCase(),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: Responsive.fontCaption,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          Responsive.spaceSm.gapH,
          const AppShimmer(child: ShimmerOutingList(count: 3)),
        ],
      ),
    );
  }
}

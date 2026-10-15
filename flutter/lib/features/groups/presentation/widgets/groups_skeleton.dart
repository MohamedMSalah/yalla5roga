import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/filter_chip_row.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/create_group_card.dart';

class GroupsSkeleton extends StatelessWidget {
  const GroupsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
                  eyebrow: l10n.yourCircles,
                  title: l10n.groupsTitle,
                  subtitle: l10n.activeGroupsFriends(0, 0),
                ),
              ),
              const NotificationButton(),
            ],
          ),
          Responsive.spaceSm.gapH,
          Row(
            children: [
              AppIconButton(icon: Icons.search, onTap: () {}),
              Responsive.spaceSm.gapW,
              AppIconButton(
                icon: Icons.add,
                background: AppColors.brand600,
                foreground: Colors.white,
                onTap: () => Get.to(() => const CreateGroupPage()),
              ),
            ],
          ),
          Responsive.spaceMd.gapH,
          Text(
            l10n.activeVotes,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontMd,
            ),
          ),
          Responsive.spaceSm.gapH,
          AppShimmer(
            child: SizedBox(
              height: Responsive.voteCardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 2,
                separatorBuilder: (_, _) => Responsive.spaceMd.gapW,
                itemBuilder: (_, _) => const ShimmerVoteCard(),
              ),
            ),
          ),
          Responsive.spaceMd.gapH,
          FilterChipRow(
            labels: [l10n.allGroups, l10n.mostActive, l10n.recentlyAdded],
            index: 0,
            onChanged: (_) {},
          ),
          Responsive.spaceMd.gapH,
          Text(
            l10n.groupsTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontMd,
            ),
          ),
          Responsive.spaceSm.gapH,
          AppShimmer(
            child: Column(
              children: [
                const ShimmerFeaturedGroup(),
                10.gapH,
                const ShimmerGroupCard(),
                10.gapH,
                const ShimmerGroupCard(),
              ],
            ),
          ),
          Responsive.spaceSm.gapH,
          CreateGroupCard(onTap: () => Get.to(() => const CreateGroupPage())),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/discover_section.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/cards/featured_outing_card.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/lists/happening_now_list.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/quick_actions.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onSeeAllOutings});

  final VoidCallback? onSeeAllOutings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outingsReady = context.watch<OutingsProvider>().hasLoaded;

    return SafeArea(
      child: ListView(
        padding: Responsive.pagePadding(),
        children: [
          const HomeHeader(),
          Responsive.spaceMd.gapH,
          if (outingsReady)
            const FeaturedOutingCard()
          else
            const _HomeFeedPlaceholder(height: 176),
          Responsive.spaceLg.gapH,
          SectionHeader(title: l10n.quickActions, subtitle: l10n.makeItHappen),
          12.gapH,
          const QuickActions(),
          Responsive.spaceLg.gapH,
          const DiscoverSection(showPlaces: true, limit: 3),
          Responsive.spaceLg.gapH,
          if (outingsReady)
            HappeningNowList(onSeeAll: onSeeAllOutings)
          else
            const _HomeFeedPlaceholder(height: 88),
        ],
      ),
    );
  }
}

class _HomeFeedPlaceholder extends StatelessWidget {
  const _HomeFeedPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ShimmerBone(width: double.infinity, height: height.h, radius: 24),
    );
  }
}

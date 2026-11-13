import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_fade_switcher.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_nearby_section.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/cards/featured_outing_card.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/quick_actions.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onSeeAllOutings, this.onDiscover});

  final VoidCallback? onSeeAllOutings;
  final VoidCallback? onDiscover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = context.select<OutingsProvider, bool>((p) => p.hasLoaded);
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: ListView(
            padding: Responsive.pagePadding().add(
              EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            ),
            children: [
              const HomeHeader(),
              AppOfflineIndicator(
                isOffline: context.select<AppSyncProvider, bool>(
                  (p) => p.status == SyncStatus.offline,
                ),
              ),
              Responsive.spaceXl.gapH,
              SectionHeader(
                title: l10n.nextUp,
                actionLabel: l10n.seeAll,
                onAction: onSeeAllOutings,
              ),
              Responsive.spaceSm.gapH,
              AppFadeSwitcher(
                child: ready
                    ? const FeaturedOutingCard(key: ValueKey('upcoming'))
                    : AppShimmer(
                        key: const ValueKey('loading'),
                        child: ShimmerBone(
                          width: double.infinity,
                          height: 120.h,
                          radius: 16,
                        ),
                      ),
              ),
              Responsive.spaceXl.gapH,
              SectionHeader(title: l10n.quickActions),
              Responsive.spaceSm.gapH,
              const QuickActions(),
              Responsive.spaceXl.gapH,
              HomeNearbySection(onSeeAll: onDiscover),
            ],
          ),
        ),
      ),
    );
  }
}

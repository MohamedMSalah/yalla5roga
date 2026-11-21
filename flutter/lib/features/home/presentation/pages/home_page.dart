import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/cards/featured_outing_card.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_hero_banner.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_nearby_section.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_section_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/quick_actions.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onSeeAllOutings, this.onDiscover});

  final VoidCallback? onSeeAllOutings;
  final VoidCallback? onDiscover;

  @override
  Widget build(BuildContext context) {
    const inset = EdgeInsets.symmetric(horizontal: HomeStyle.gutter);
    return HomeBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: ListView(
              padding: EdgeInsets.only(
                // The extended Scaffold body supplies the measured pill height.
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
              ),
              children: [
                const HomeHeader(),
                Padding(
                  padding: inset,
                  child: HomeHeroBanner(
                    onTap: () => Get.to(() => const CreateOutingPage()),
                  ),
                ),
                const Padding(padding: inset, child: _HomeOfflineNotice()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HomeStyle.gutter,
                    15,
                    HomeStyle.gutter,
                    HomeStyle.sectionGap,
                  ),
                  child: NextUpSection(onSeeAll: onSeeAllOutings),
                ),
                Padding(
                  padding: inset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HomeSectionHeader(
                        title: context.l10n.quickActions,
                        icon: Icons.bolt_outlined,
                      ),
                      const SizedBox(height: HomeStyle.headerGap),
                      const QuickActions(),
                    ],
                  ),
                ),
                const SizedBox(height: HomeStyle.sectionGap),
                HomeNearbySection(onSeeAll: onDiscover),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = HomeStyle(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.upperBackground, style.background, style.background],
          stops: const [0, .56, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            height: 285,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const AlignmentDirectional(.44, -.35),
                    radius: .58,
                    colors: [style.glow, style.glow.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _HomeOfflineNotice extends StatelessWidget {
  const _HomeOfflineNotice();

  @override
  Widget build(BuildContext context) {
    final offline = context.select<AppSyncProvider, bool>(
      (p) => p.status == SyncStatus.offline,
    );
    return Padding(
      padding: EdgeInsets.only(top: offline ? 12 : 0),
      child: AppOfflineIndicator(isOffline: offline),
    );
  }
}

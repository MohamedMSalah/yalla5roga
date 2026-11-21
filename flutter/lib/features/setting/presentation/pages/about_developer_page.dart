import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/cards/about_developer_card.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/cards/developer_link_card.dart';

import 'profile_info_page.dart';

class AboutDeveloperPage extends StatelessWidget {
  const AboutDeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final links = [
      DeveloperLinkCard(
        platform: DeveloperPlatform.portfolio,
        title: l10n.portfolio,
        subtitle: l10n.viewMyPortfolio,
        destination: AppConfig.developerPortfolioUrl,
      ),
      DeveloperLinkCard(
        platform: DeveloperPlatform.linkedIn,
        title: l10n.linkedIn,
        subtitle: l10n.developerLinkedInSubtitle,
        destination: AppConfig.developerLinkedInUrl,
      ),
      DeveloperLinkCard(
        platform: DeveloperPlatform.github,
        title: l10n.github,
        subtitle: l10n.viewMyProjects,
        destination: AppConfig.developerGitHubUrl,
      ),
      DeveloperLinkCard(
        platform: DeveloperPlatform.email,
        title: l10n.email,
        subtitle: l10n.getInTouch,
        destination: AppConfig.contactEmail,
      ),
    ].where((link) => link.destination.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppPageBar(title: l10n.aboutDeveloper),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                const AboutDeveloperCard(),
                Responsive.spaceLg.gapH,
                AppCard(
                  padding: EdgeInsets.all(Responsive.spaceLg),
                  child: ProfileInfoBlock(
                    title: l10n.developerAboutHeading,
                    body: l10n.developerAboutBody,
                  ),
                ),
                Responsive.spaceMd.gapH,
                AppCard(
                  color: palette.brandSoft,
                  borderColor: palette.brandSoftBorder,
                  showBorder: true,
                  padding: EdgeInsets.all(Responsive.spaceLg),
                  child: ProfileInfoBlock(
                    title: l10n.developerStoryHeading,
                    body: l10n.developerStoryBody,
                  ),
                ),
                if (links.isNotEmpty) ...[
                  Responsive.spaceXl.gapH,
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.developerConnect,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Responsive.spaceMd.gapH,
                  ListCard(children: links),
                ],
                Responsive.spaceXl.gapH,
                const _DeveloperFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeveloperFooter extends StatelessWidget {
  const _DeveloperFooter();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Icon(Icons.favorite_rounded, color: context.palette.brand, size: 15.w),
        Responsive.spaceSm.gapH,
        Text(
          l10n.developerFooterPassion,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Responsive.spaceXs.gapH,
        Text(l10n.developerFooterLove, textAlign: TextAlign.center),
        Responsive.spaceSm.gapH,
        Text(
          l10n.developerCopyright(DateTime.now().year),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.palette.textMuted),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';

import 'outing_info_style.dart';

class TieResultsSection extends StatelessWidget {
  const TieResultsSection({
    super.key,
    required this.options,
    required this.round,
    required this.canResolve,
    required this.busy,
    required this.onRandom,
    required this.onRevote,
  });
  final List<VoteOption> options;
  final int round;
  final bool canResolve, busy;
  final VoidCallback onRandom, onRevote;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = OutingInfoStyle(context);
    final noVotes =
        options.isNotEmpty && options.every((option) => option.votes == 0);
    return OutingInfoPanel(
      padding: const EdgeInsets.all(14),
      radius: 18,
      outline: Color.alphaBlend(
        style.warning.withValues(alpha: .38),
        style.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.balance, color: style.warning, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.outingTieTitle,
                    style: style.type(20, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            noVotes ? l.noLocationVotesExplanation : l.outingTieSubtitle,
            style: style.type(13, color: style.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            l.votingRound(round),
            style: style.type(11, color: style.warning),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            TiePlaceCategories(
              builder: (context, categories) => Column(
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TiedPlaceCard(
                        option: option,
                        category: categories[option.categoryId],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (canResolve) ...[
            _TieResolutionAction(
              icon: Icons.repeat,
              title: l.outingRevoteTitle,
              subtitle: l.outingRevoteSubtitle,
              primary: true,
              onTap: busy ? null : onRevote,
            ),
            const SizedBox(height: 8),
            _TieResolutionAction(
              icon: Icons.casino_outlined,
              title: l.rollTheDice,
              subtitle: l.outingDiceSubtitle,
              onTap: busy ? null : onRandom,
            ),
          ] else
            Row(
              children: [
                Icon(Icons.hourglass_empty, color: style.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.waitingForOutingCreator,
                    style: style.type(13, color: style.secondary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class TiePlaceCategories extends StatefulWidget {
  const TiePlaceCategories({super.key, required this.builder});
  final Widget Function(BuildContext context, Map<String, String> categories)
  builder;

  @override
  State<TiePlaceCategories> createState() => _TiePlaceCategoriesState();
}

class _TiePlaceCategoriesState extends State<TiePlaceCategories> {
  late final Future<List<CatalogDefinition>> _categories = context
      .read<DiscoverProvider>()
      .repository
      .getDefinitions('categories')
      .then((result) => result.fold((_) => const [], (items) => items));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CatalogDefinition>>(
    future: _categories,
    builder: (context, snapshot) {
      final language = context.l10n.locale.languageCode;
      return widget.builder(context, {
        for (final category in snapshot.data ?? const <CatalogDefinition>[])
          category.id: category.label(language),
      });
    },
  );
}

class _TiedPlaceCard extends StatelessWidget {
  const _TiedPlaceCard({required this.option, this.category});
  final VoteOption option;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    final l = context.l10n;
    final id = option.catalogPlaceId;
    final subtitle = category?.isNotEmpty == true ? category! : option.area;
    return OutingInfoPanel(
      padding: const EdgeInsets.all(8),
      radius: 13,
      onTap: id == null || id.isEmpty
          ? null
          : () => Get.to(() => DiscoverPlaceDetailsPage(placeId: id)),
      child: Row(
        children: [
          TiePlacePhoto(option: option, width: 52, height: 49),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: style.type(13, weight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: style.type(11, color: style.secondary)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l.votesPercent(option.votes, option.percent),
                      style: style.type(11, color: style.secondary),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: style.control,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          l.outingTied,
                          style: style.type(10, color: style.warning),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: option.percent.clamp(0, 100) / 100,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                  color: style.accent,
                  backgroundColor: style.border,
                  semanticsLabel: l.votesPercent(option.votes, option.percent),
                ),
              ],
            ),
          ),
          if (id != null && id.isNotEmpty) ...[
            const SizedBox(width: 7),
            Icon(Icons.arrow_forward_ios, color: style.icon, size: 13),
          ],
        ],
      ),
    );
  }
}

class TiePlacePhoto extends StatelessWidget {
  const TiePlacePhoto({
    super.key,
    required this.option,
    required this.width,
    required this.height,
  });
  final VoteOption option;
  final double width, height;

  @override
  Widget build(BuildContext context) =>
      option.imageUrl.isEmpty && option.categoryId.isNotEmpty
      ? PlaceCoverImage(
          url: '',
          vibe: OutingVibe.food,
          categoryId: option.categoryId,
          width: width,
          height: height,
          radius: 8,
        )
      : PlanningCover(
          url: option.imageUrl,
          art: PlanningCoverArt.outing,
          width: width,
          height: height,
          radius: 8,
        );
}

class _TieResolutionAction extends StatelessWidget {
  const _TieResolutionAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    final foreground = primary ? Colors.white : style.text;
    return Semantics(
      enabled: onTap != null,
      button: true,
      child: OutingInfoPanel(
        gradient: primary ? OutingInfoStyle.purple : null,
        outline: primary ? const Color(0xFF7544A8) : style.accent,
        padding: const EdgeInsets.all(11),
        radius: 14,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 22, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: style.type(
                      14,
                      weight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: style.type(
                      11.5,
                      color: primary
                          ? const Color(0xFFEFE2FF)
                          : style.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, color: foreground, size: 14),
          ],
        ),
      ),
    );
  }
}

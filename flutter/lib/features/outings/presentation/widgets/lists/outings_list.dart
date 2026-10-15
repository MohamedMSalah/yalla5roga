import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

/// Outings list: optional title + outing cards / empty state.
class OutingsList extends StatelessWidget {
  const OutingsList({
    super.key,
    this.title,
    this.limit,
    this.filtered = false,
    this.titleStyle,
  });

  final String? title;
  final int? limit;
  final bool filtered;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<OutingsProvider>();
    final outings = filtered ? provider.filtered : provider.outings;
    final items = limit == null ? outings : outings.take(limit!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style:
                titleStyle ??
                TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontMd,
                ),
          ),
          Responsive.spaceSm.gapH,
        ],
        if (items.isEmpty)
          AppEmptyState(
            icon: Icons.explore_outlined,
            message: filtered ? l10n.noOutingsInFilter : l10n.noOutings,
            subtitle: filtered
                ? l10n.noOutingsInFilterHint
                : l10n.noOutingsHint,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final outing = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 8.h,
                ),
                child: OutingListTile(
                  title: outing.title,
                  subtitle: l10n.digits(
                    [
                      if (outing.date.isNotEmpty) outing.date,
                      if (outing.time.isNotEmpty) outing.time,
                      l10n.goingCount(outing.going),
                    ].join(' · '),
                  ),
                  image: outing.image,
                  onTap: () => Get.to(() => EventPage(event: outing)),
                ),
              );
            },
          ),
      ],
    );
  }
}

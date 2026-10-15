import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

/// Group outings section: title + cards / empty state.
class GroupOutingsList extends StatelessWidget {
  const GroupOutingsList({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outings = context.watch<OutingsProvider>().forGroup(group.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.groupOutings,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        if (outings.isEmpty)
          AppEmptyState(
            icon: Icons.event_busy_outlined,
            message: l10n.noGroupOutings,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: outings.length,
            itemBuilder: (context, index) {
              final outing = outings[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == outings.length - 1 ? 0 : 8.h,
                ),
                child: OutingListTile(
                  title: outing.title,
                  subtitle: l10n.digits(
                    '${outing.date} · ${outing.time} · ${outing.meta}',
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

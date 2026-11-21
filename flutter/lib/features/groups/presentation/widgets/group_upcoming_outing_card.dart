import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/participant_avatar_stack.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class GroupUpcomingOutingCard extends StatelessWidget {
  const GroupUpcomingOutingCard({super.key, required this.outing});
  final Outing outing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = GroupPageColors(context);
    final avatars = context.select(
      (OutingsProvider provider) => provider
          .membersForOuting(outing)
          .where(
            (member) =>
                provider.attendanceFor(outing.id, member.id) ==
                AttendanceStatus.going,
          )
          .take(3)
          .map((member) => member.avatar)
          .toList(growable: false),
    );
    final going = context.select(
      (OutingsProvider provider) => provider.goingCountFor(outing.id),
    );
    final winnerImage = context.select(
      (OutingsProvider provider) =>
          provider.winningOptionFor(outing.id)?.imageUrl,
    );
    final placeId = outing.location?.placeId;
    final placeImage = context.select(
      (DiscoverProvider provider) =>
          placeId == null ? null : provider.findById(placeId)?.coverImageUrl,
    );
    final url =
        [
              winnerImage,
              placeImage,
              if (placeId != null)
                ...outing.votePlaces
                    .where((place) => place.id == placeId)
                    .map((place) => place.imageUrl),
              outing.image,
            ]
            .whereType<String>()
            .map((url) => url.trim())
            .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    final place = outing.location?.name.trim() ?? '';
    final instant = outing.scheduledAt;
    final date = instant == null
        ? outing.localizedDate(l10n)
        : l10n.formatHomeOutingDate(instant.toLocal());

    return GroupSurface(
      padding: const EdgeInsets.all(10),
      onTap: () => Get.to(() => EventPage(event: outing)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth * .29).clamp(60.0, 94.0);
          final titleStyle = context.texts.titleMedium?.copyWith(
            color: style.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          );
          return Row(
            children: [
              PlanningCover(
                url: url,
                art: outing.occasion.coverArt,
                width: width,
                height: 105,
                radius: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date.isNotEmpty) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7030BE), Color(0xFF51218F)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_available_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  date,
                                  style: context.texts.labelMedium?.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      outing.title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: style.accent,
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.isEmpty ? l10n.groupLocationPending : place,
                            style: context.texts.bodyMedium?.copyWith(
                              color: style.muted,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (going > 0 || avatars.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: ParticipantAvatarStack(
                          urls: avatars,
                          extra: (going - avatars.length).clamp(0, going),
                          ring: style.border,
                          counterFill: style.iconSurface,
                          counterText: style.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(context.chevronForward, size: 20, color: style.accent),
            ],
          );
        },
      ),
    );
  }
}

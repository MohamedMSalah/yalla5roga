import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_preview_card.dart';

class ActiveVotesList extends StatelessWidget {
  const ActiveVotesList({
    super.key,
    required this.items,
    required this.onOpen,
    this.limit,
  });

  final List<Outing> items;
  final ValueChanged<Outing> onOpen;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: limit == null ? items.length : items.length.clamp(0, limit!),
      itemBuilder: (context, index) {
        final outing = items[index];
        return Padding(
          key: ValueKey(outing.id),
          padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
          child: ActiveVotePreviewCard(
            outing: outing,
            onTap: () => onOpen(outing),
          ),
        );
      },
    );
  }
}

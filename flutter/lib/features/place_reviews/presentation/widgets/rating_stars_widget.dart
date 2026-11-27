import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class RatingStarsWidget extends StatelessWidget {
  const RatingStarsWidget({super.key, required this.rating, this.onChanged});

  final int rating;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    final l10n = context.l10n;
    final colors = context.palette;
    Widget star(int value) => Icon(
      value <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
      size: change == null ? 18 : 32,
      color: value <= rating ? colors.brandStrong : colors.textSecondary,
    );

    if (change == null) {
      return Semantics(
        label: l10n.placeStars(rating),
        excludeSemantics: true,
        child: Wrap(children: [for (var i = 1; i <= 5; i++) star(i)]),
      );
    }
    return Wrap(
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            selected: i == rating,
            child: IconButton(
              icon: star(i),
              tooltip: l10n.placeStars(i),
              onPressed: () => change(i),
            ),
          ),
      ],
    );
  }
}

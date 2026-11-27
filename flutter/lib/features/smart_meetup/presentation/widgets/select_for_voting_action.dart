import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class SelectForVotingAction extends StatelessWidget {
  const SelectForVotingAction({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.how_to_vote_outlined),
    label: Text(context.l10n.meetupSelectVotingPlaces),
  );
}

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Navigation callback only: creating/publishing remains in the existing wizard.
class DiscoverSelectedPlaceAction extends StatelessWidget {
  const DiscoverSelectedPlaceAction({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    onPressed: onPressed,
    icon: const Icon(Icons.add_location_alt_outlined),
    label: Text(
      context.l10n.discoverCreateOutingHere,
      textAlign: TextAlign.center,
    ),
  );
}

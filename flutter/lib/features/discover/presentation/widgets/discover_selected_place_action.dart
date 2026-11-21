import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Navigation callback only: creating/publishing remains in the existing wizard.
class DiscoverSelectedPlaceAction extends StatelessWidget {
  const DiscoverSelectedPlaceAction({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => CustomButton(
    onPressed: onPressed,
    icon: Icons.add_location_alt_outlined,
    label: context.l10n.discoverCreateOutingHere,
  );
}

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';

class DiscoverMapControls extends StatelessWidget {
  const DiscoverMapControls({
    super.key,
    required this.onLocate,
    this.busy = false,
  });
  final VoidCallback onLocate;
  final bool busy;
  @override
  Widget build(BuildContext context) =>
      MapCurrentLocationButton(onPressed: onLocate, busy: busy);
}

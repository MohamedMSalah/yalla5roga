import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';

class DiscoverFloatingSearchBar extends StatelessWidget {
  const DiscoverFloatingSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => MapSearchBar(
    controller: controller,
    onChanged: onChanged,
    trailing: const NotificationButton(),
  );
}

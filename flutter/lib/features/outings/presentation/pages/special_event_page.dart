import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

/// Dedicated entry point using the established route-local Provider and wizard.
class SpecialEventPage extends StatelessWidget {
  const SpecialEventPage({super.key, this.group});
  final Group? group;
  @override
  Widget build(BuildContext context) =>
      CreateOutingPage(specialEvent: true, group: group);
}

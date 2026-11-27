import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

import '../../domain/entities/saved_location.dart';

extension SavedLocationTypePresentation on SavedLocationType {
  String label(L10n l) => switch (this) {
    SavedLocationType.home => l.savedLocationHome,
    SavedLocationType.work => l.savedLocationWork,
    SavedLocationType.university => l.savedLocationUniversity,
    SavedLocationType.gym => l.savedLocationGym,
    SavedLocationType.custom => l.savedLocationCustom,
  };

  IconData get icon => switch (this) {
    SavedLocationType.home => Icons.home_outlined,
    SavedLocationType.work => Icons.work_outline,
    SavedLocationType.university => Icons.school_outlined,
    SavedLocationType.gym => Icons.fitness_center,
    SavedLocationType.custom => Icons.place_outlined,
  };
}

class SavedLocationCard extends StatelessWidget {
  const SavedLocationCard({
    super.key,
    required this.location,
    required this.isDefault,
    this.onTap,
    this.onRemove,
  });

  final SavedLocation location;
  final bool isDefault;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final subtitle = [
      location.type.label(l),
      ?location.approximateArea,
      if (isDefault) l.startingDefaultIndicator,
    ].join(' · ');
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(location.type.icon, color: context.palette.brandStrong),
        title: Text(location.name),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: onRemove == null
            ? (isDefault ? const Icon(Icons.check_circle_outline) : null)
            : IconButton(
                onPressed: onRemove,
                tooltip: l.savedLocationDelete,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}

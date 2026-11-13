import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';

extension OutingL10n on Outing {
  String statusLabel(L10n l10n) => switch (status) {
    OutingStatus.voting => l10n.voting,
    OutingStatus.past => l10n.completedOuting,
    OutingStatus.cancelled => l10n.cancelledOuting,
    OutingStatus.draft => l10n.draftOuting,
    OutingStatus.confirmed => l10n.confirmed,
  };

  String localizedDate(L10n l10n) => l10n.formatStoredDate(scheduledAt, date);

  String localizedTime(L10n l10n) => l10n.formatStoredTime(scheduledAt, time);

  String localizedWhen(L10n l10n) =>
      l10n.formatWhen(scheduledAt, date: date, time: time);

  String get localizedPlace {
    if (location != null && location!.area.trim().isNotEmpty) {
      return location!.area.trim();
    }
    if (location != null && location!.name.trim().isNotEmpty) {
      return location!.name.trim();
    }
    return meta.split('·').first.trim();
  }

  /// Area/name plus localized clock — replaces stored English `meta`.
  String localizedMeta(L10n l10n) {
    final place = localizedPlace;
    final clock = localizedTime(l10n);
    if (place.isEmpty) return clock;
    if (clock.isEmpty) return place;
    return '$place · $clock';
  }
}

extension OutingCoverArt on OutingOccasion {
  PlanningCoverArt get coverArt => switch (this) {
    OutingOccasion.none => PlanningCoverArt.outing,
    OutingOccasion.birthday => PlanningCoverArt.birthday,
    OutingOccasion.wedding => PlanningCoverArt.wedding,
  };
}

import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';

class SavedOuting {
  const SavedOuting({
    required this.id,
    required this.title,
    required this.image,
    required this.location,
  });

  final String id;
  final String title;
  final String image;
  final PlaceLocation location;

  factory SavedOuting.fromEvent(Outing event) {
    return SavedOuting(
      id: event.id,
      title: event.title,
      image: event.image,
      location:
          event.location ??
          PlaceLocation(name: event.meta.split('·').first.trim()),
    );
  }

  factory SavedOuting.fromJson(Map<String, dynamic> json) {
    return SavedOuting(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      image: json['image'] as String? ?? '',
      location: PlaceLocation.fromJson(
        (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'image': image,
    'location': location.toJson(),
  };
}

class OutingDraft {
  const OutingDraft({
    required this.id,
    required this.title,
    required this.image,
    required this.location,
    required this.date,
    required this.hour,
    required this.minute,
    required this.vibe,
    this.groupId,
    this.occasion = OutingOccasion.none,
    this.specialEvent = false,
    this.guestIds = const [],
    this.letVote = false,
    this.voteDeadlineHours,
    this.selectedPlaces = const [],
  });

  final String id;
  final String title;
  final String image;
  final PlaceLocation location;
  final DateTime date;
  final int hour;
  final int minute;
  final int vibe;
  final String? groupId;
  final OutingOccasion occasion;
  final bool specialEvent;
  final List<String> guestIds;
  final bool letVote;
  final int? voteDeadlineHours;
  final List<Place> selectedPlaces;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  factory OutingDraft.fromJson(Map<String, dynamic> json) {
    return OutingDraft(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      image: json['image'] as String? ?? '',
      location: PlaceLocation.fromJson(
        (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      hour: json['hour'] as int? ?? 11,
      minute: json['minute'] as int? ?? 30,
      vibe: json['vibe'] as int? ?? 0,
      groupId: json['groupId'] as String?,
      occasion: OutingOccasion.values.firstWhere(
        (item) => item.name == json['occasion'],
        orElse: () => OutingOccasion.none,
      ),
      specialEvent: json['specialEvent'] as bool? ?? false,
      guestIds: [
        for (final item in json['guestIds'] as List? ?? const [])
          if (item is String) item,
      ],
      letVote: json['letVote'] as bool? ?? false,
      voteDeadlineHours: json['voteDeadlineHours'] as int?,
      selectedPlaces: [
        for (final item in json['selectedPlaces'] as List? ?? const [])
          if (item is Map) Place.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'image': image,
    'location': location.toJson(),
    'date': date.toIso8601String(),
    'hour': hour,
    'minute': minute,
    'vibe': vibe,
    'groupId': groupId,
    'occasion': occasion.name,
    'specialEvent': specialEvent,
    'guestIds': guestIds,
    'letVote': letVote,
    'voteDeadlineHours': voteDeadlineHours,
    'selectedPlaces': [for (final place in selectedPlaces) place.toJson()],
  };
}

class SavedItem {
  const SavedItem.bookmark(this.outing)
    : draft = null,
      kind = SavedKind.bookmark;

  const SavedItem.draft(this.draft) : outing = null, kind = SavedKind.draft;

  final SavedKind kind;
  final SavedOuting? outing;
  final OutingDraft? draft;

  bool get isDraft => kind == SavedKind.draft;

  String get id => draft?.id ?? outing!.id;

  String get title => draft?.title ?? outing!.title;

  String get image => draft?.image ?? outing!.image;

  PlaceLocation get location => draft?.location ?? outing!.location;
}

enum SavedKind { bookmark, draft }

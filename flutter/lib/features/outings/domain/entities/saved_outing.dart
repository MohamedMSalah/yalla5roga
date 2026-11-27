import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_result_handoff_model.dart';

class SavedOuting {
  const SavedOuting({
    required this.id,
    required this.title,
    required this.image,
    required this.location,
    this.occasion = OutingOccasion.none,
  });

  final String id;
  final String title;
  final String image;
  final PlaceLocation location;
  final OutingOccasion occasion;

  factory SavedOuting.fromEvent(Outing event) {
    return SavedOuting(
      id: event.id,
      title: event.title,
      image: event.image,
      occasion: event.occasion,
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
      occasion: OutingOccasion.values.firstWhere(
        (item) => item.name == json['occasion'],
        orElse: () => OutingOccasion.none,
      ),
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
    'occasion': occasion.name,
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
    this.guestPhones = const [],
    this.letVote = false,
    this.voteDeadlineHours,
    this.selectedPlaces = const [],
    this.meetupSelection,
    this.remoteVersion,
    this.pending = false,
    this.deleted = false,
    this.conflict = false,
  });

  final String? remoteVersion;
  bool get deviceLocalLocation =>
      location.placeId == null && location.hasCoordinates ||
      selectedPlaces.any((p) => p.id.isEmpty && p.hasCoordinates);
  final bool pending;
  final bool deleted;
  final bool conflict;
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
  final List<String> guestPhones;
  final bool letVote;
  final int? voteDeadlineHours;
  final List<Place> selectedPlaces;
  final MeetupResultHandoffModel? meetupSelection;

  OutingDraft withSync({
    String? id,
    String? version,
    bool? pending,
    bool? deleted,
    bool? conflict,
  }) => OutingDraft.fromJson({
    ...toJson(),
    'id': ?id,
    'remoteVersion': version ?? remoteVersion,
    'pending': pending ?? this.pending,
    'deleted': deleted ?? this.deleted,
    'conflict': conflict ?? this.conflict,
  });

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  factory OutingDraft.fromJson(Map<String, dynamic> json) {
    final placeRows = (json['selectedPlaces'] as List? ?? const [])
        .whereType<Map>();
    final places = [
      for (final row in placeRows)
        Place.fromJson(Map<String, dynamic>.from(row)),
    ];
    return OutingDraft(
      id: json['id'] as String? ?? '',
      remoteVersion: json['remoteVersion'] as String?,
      pending: json['pending'] == true,
      deleted: json['deleted'] == true,
      conflict: json['conflict'] == true,
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
      guestPhones: [
        for (final item in json['guestPhones'] as List? ?? const [])
          if (item is String) item,
      ],
      guestIds: [
        for (final item in json['guestIds'] as List? ?? const [])
          if (item is String) item,
      ],
      letVote: json['letVote'] as bool? ?? false,
      voteDeadlineHours: json['voteDeadlineHours'] as int?,
      selectedPlaces: places,
      meetupSelection: MeetupResultHandoffModel.fromDraftJson(
        placeRows.firstOrNull?['smart_meetup_selection'],
        places,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'remoteVersion': remoteVersion,
    'pending': pending,
    'deleted': deleted,
    'conflict': conflict,
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
    'guestPhones': guestPhones,
    'letVote': letVote,
    'voteDeadlineHours': voteDeadlineHours,
    'selectedPlaces': selectedPlacesJson(),
  };

  List<Map<String, dynamic>> selectedPlacesJson() => [
    for (final (index, place) in selectedPlaces.indexed)
      {
        ...place.toJson(),
        if (index == 0 && meetupSelection != null)
          'smart_meetup_selection': meetupSelection!.toDraftJson(),
      },
  ];
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

  OutingOccasion get occasion => draft?.occasion ?? outing!.occasion;

  PlaceLocation get location => draft?.location ?? outing!.location;
}

enum SavedKind { bookmark, draft }

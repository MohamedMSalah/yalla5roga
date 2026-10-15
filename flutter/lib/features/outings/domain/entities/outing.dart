import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';

/// Core outing entity (UI historically called this [HeroSlide]).
class Outing {
  const Outing({
    required this.id,
    required this.image,
    required this.title,
    required this.meta,
    required this.date,
    this.time = '',
    this.going = 0,
    this.groupId,
    this.location,
    this.occasion = OutingOccasion.none,
    this.guestIds = const [],
    this.status = OutingStatus.upcoming,
    this.votePlaces = const [],
    this.voteDeadlineHours,
    this.suggestedBy,
    this.scheduledAt,
    this.createdById,
  });

  final String id;
  final String image;
  final String title;

  /// Display meta line (derived from location/time when possible).
  final String meta;

  /// Display date string (sourced from [scheduledAt] when possible).
  final String date;
  final String time;
  final int going;
  final String? groupId;
  final PlaceLocation? location;
  final OutingOccasion occasion;
  final List<String> guestIds;
  final OutingStatus status;

  /// Places the group can vote on (2+ when status is voting).
  final List<Place> votePlaces;

  /// Hours the creator set for the vote countdown.
  final int? voteDeadlineHours;

  /// Display name of who suggested the places (group suggest flow).
  final String? suggestedBy;

  /// When the outing is scheduled (source of truth for past / chat closed).
  final DateTime? scheduledAt;

  /// Member/user id of the creator (auto attendance = going).
  final String? createdById;

  String get coverUrl => image;

  int get goingCount => going;

  bool get hasVotePlaces => votePlaces.length >= 2;

  /// Primary vibe from the first vote place (food fallback).
  OutingVibe get primaryVibe =>
      votePlaces.isNotEmpty ? votePlaces.first.vibe : OutingVibe.food;

  /// Localized date · time line for cards (empty when both are blank).
  String dateTimeLine(String Function(String) digits) {
    final dateText = date.trim();
    final timeText = time.trim();
    if (dateText.isEmpty && timeText.isEmpty) return '';
    if (timeText.isEmpty) return digits(dateText);
    if (dateText.isEmpty) return digits(timeText);
    return digits('$dateText · $timeText');
  }

  /// True when status is past or [scheduledAt] has passed.
  bool get isPastOuting {
    if (status == OutingStatus.past) return true;
    final at = scheduledAt;
    if (at == null) return false;
    return !at.isAfter(DateTime.now());
  }

  /// Final location is hidden while place voting is still open.
  bool get isLocationHidden =>
      status == OutingStatus.voting && location == null;

  List<String> get _dateParts {
    return date
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String get calendarDay => _dateParts.length >= 2 ? _dateParts[1] : date;

  String get calendarMonth => _dateParts.length >= 3 ? _dateParts.last : '';

  Outing copyWith({
    String? id,
    String? image,
    String? title,
    String? meta,
    String? date,
    String? time,
    int? going,
    String? groupId,
    PlaceLocation? location,
    bool clearLocation = false,
    OutingOccasion? occasion,
    List<String>? guestIds,
    OutingStatus? status,
    List<Place>? votePlaces,
    int? voteDeadlineHours,
    String? suggestedBy,
    DateTime? scheduledAt,
    String? createdById,
  }) {
    return Outing(
      id: id ?? this.id,
      image: image ?? this.image,
      title: title ?? this.title,
      meta: meta ?? this.meta,
      date: date ?? this.date,
      time: time ?? this.time,
      going: going ?? this.going,
      groupId: groupId ?? this.groupId,
      location: clearLocation ? null : (location ?? this.location),
      occasion: occasion ?? this.occasion,
      guestIds: guestIds ?? this.guestIds,
      status: status ?? this.status,
      votePlaces: votePlaces ?? this.votePlaces,
      voteDeadlineHours: voteDeadlineHours ?? this.voteDeadlineHours,
      suggestedBy: suggestedBy ?? this.suggestedBy,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdById: createdById ?? this.createdById,
    );
  }
}

/// Backward-compatible alias used across existing UI.
typedef HeroSlide = Outing;

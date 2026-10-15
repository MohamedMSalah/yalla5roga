import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/outings/domain/entities/group_place_suggestion.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';

class OutingSnapshot {
  const OutingSnapshot({
    required this.outings,
    required this.suggestions,
    required this.votesByOuting,
    required this.attendanceByOuting,
  });

  final List<Outing> outings;
  final List<GroupPlaceSuggestion> suggestions;
  final Map<String, PlaceVote> votesByOuting;
  final Map<String, Map<String, AttendanceStatus>> attendanceByOuting;
}

abstract class OutingsRepository {
  Future<Either<Failure, OutingSnapshot>> load({bool forceRefresh = false});

  Future<Either<Failure, OutingSnapshot>> add(
    Outing outing, {
    String? creatorId,
  });

  Future<Either<Failure, OutingSnapshot>> suggestPlaces({
    required String groupId,
    required String title,
    required List<Place> places,
    required int deadlineHours,
    required String createdBy,
    String? createdById,
    String? image,
    DateTime? scheduledAt,
  });

  Future<Either<Failure, OutingSnapshot>> selectVote(
    String outingId,
    int optionIndex,
  );

  Future<Either<Failure, OutingSnapshot>> finalizeVote(String outingId);

  Future<Either<Failure, OutingSnapshot>> clearVotes(String outingId);

  Future<Either<Failure, OutingSnapshot>> setAttendance({
    required String outingId,
    required String memberId,
    required AttendanceStatus status,
  });

  Future<Either<Failure, OutingSnapshot>> refreshLifecycle();

  List<Place> get catalogPlaces;

  List<GroupMember> membersForOuting(Outing outing);

  String specialEventImage(OutingOccasion occasion);
}

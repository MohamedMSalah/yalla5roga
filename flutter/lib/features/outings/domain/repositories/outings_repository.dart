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

  OutingSnapshot withoutOuting(String id) {
    return OutingSnapshot(
      outings: outings.where((outing) => outing.id != id).toList(),
      suggestions: suggestions.where((item) => item.outingId != id).toList(),
      votesByOuting: Map.of(votesByOuting)..remove(id),
      attendanceByOuting: Map.of(attendanceByOuting)..remove(id),
    );
  }

  final List<Outing> outings;
  final List<GroupPlaceSuggestion> suggestions;
  final Map<String, PlaceVote> votesByOuting;
  final Map<String, Map<String, AttendanceStatus>> attendanceByOuting;
}

class TieBreakResult {
  const TieBreakResult({required this.snapshot, required this.winningOptionId});

  final OutingSnapshot snapshot;
  final String winningOptionId;
}

abstract class OutingsRepository {
  Future<Either<Failure, OutingSnapshot>> load({bool forceRefresh = false});

  Future<Either<Failure, void>> delete(String outingId);

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

  /// Owner tie-break; returns snapshot plus server-selected winning option id.
  Future<Either<Failure, TieBreakResult>> breakTie(String outingId);

  Future<Either<Failure, OutingSnapshot>> clearVotes(String outingId);

  Future<Either<Failure, OutingSnapshot>> setAttendance({
    required String outingId,
    required String memberId,
    required AttendanceStatus status,
  });

  /// Refresh lifecycle. When [outingId] is set, only that outing is reloaded.
  /// When unset, uses the snapshot TTL unless [forceRefresh] is true.
  Future<Either<Failure, OutingSnapshot>> refreshLifecycle({
    String? outingId,
    bool forceRefresh = false,
  });

  void clearCache();

  List<Place> get catalogPlaces;

  List<GroupMember> membersForOuting(Outing outing);

  String specialEventImage(OutingOccasion occasion);
}

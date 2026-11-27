import 'package:yalla_5roga/features/place_reviews/domain/entities/place_rating_statistics.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

class VoteOption {
  const VoteOption(
    this.placeId,
    this.label,
    this.votes,
    this.percent, {
    this.area = '',
    this.categoryId = '',
    this.address = '',
    this.imageUrl = '',
    this.catalogPlaceId,
    this.ratingStatistics,
  });

  final String area, categoryId, address;
  final String imageUrl;
  final String? catalogPlaceId;
  final PlaceRatingStatistics? ratingStatistics;

  final String placeId;
  final String label;
  final int votes;
  final int percent;

  VoteOption copyWith({
    String? placeId,
    String? label,
    int? votes,
    int? percent,
  }) {
    return VoteOption(
      placeId ?? this.placeId,
      label ?? this.label,
      votes ?? this.votes,
      percent ?? this.percent,
      area: area,
      categoryId: categoryId,
      address: address,
      imageUrl: imageUrl,
      catalogPlaceId: catalogPlaceId,
      ratingStatistics: ratingStatistics,
    );
  }

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'label': label,
    'votes': votes,
    'percent': percent,
    'area': area,
    'category_id': categoryId,
    'address': address,
    'imageUrl': imageUrl,
    if (catalogPlaceId != null) 'catalogPlaceId': catalogPlaceId,
  };

  factory VoteOption.fromJson(Map<String, dynamic> json) {
    return VoteOption(
      json['placeId'] as String? ?? '',
      json['label'] as String? ?? '',
      json['votes'] as int? ?? 0,
      json['percent'] as int? ?? 0,
      categoryId: json['category_id'] as String? ?? '',
      address: json['address'] as String? ?? '',
      area: json['area'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      catalogPlaceId: json['catalogPlaceId'] as String?,
    );
  }
}

class PlaceVote {
  const PlaceVote({
    required this.outingId,
    required this.options,
    this.endsAt,
    this.cuserOptionIds = const [],
    this.suggestedById,
    this.eligibleVoterCount = 0,
    this.votedCount = 0,
    this.hasParticipationCounts = false,
    this.finalized = false,
    this.winningOptionId,
    this.roundNumber = 1,
    this.votingState = 'active',
    this.canResolveTie = false,
    this.tiedOptionIds = const [],
  });

  final String outingId;
  final List<VoteOption> options;
  final DateTime? endsAt;
  final List<String> cuserOptionIds;
  final String? suggestedById;
  final bool finalized;
  final String? winningOptionId;
  final int roundNumber;
  final String votingState;
  final bool canResolveTie;
  final List<String> tiedOptionIds;
  final int eligibleVoterCount;
  final int votedCount;
  final bool hasParticipationCounts;

  /// First selected option (legacy single-select helpers).
  String? get cuserOptionId =>
      cuserOptionIds.isEmpty ? null : cuserOptionIds.first;

  int? get cuserOptionIndex {
    final id = cuserOptionId;
    if (id == null) return null;
    final index = options.indexWhere((option) => option.placeId == id);
    return index < 0 ? null : index;
  }

  Set<int> get cuserOptionIndexes {
    final indexes = <int>{};
    for (final id in cuserOptionIds) {
      final index = options.indexWhere((option) => option.placeId == id);
      if (index >= 0) indexes.add(index);
    }
    return indexes;
  }

  bool isOptionSelected(int index) => cuserOptionIndexes.contains(index);

  bool get hasVoted => cuserOptionIds.isNotEmpty;

  PlaceVote copyWith({
    List<VoteOption>? options,
    DateTime? endsAt,
    List<String>? cuserOptionIds,
    bool clearCuserOptions = false,
    bool? finalized,
  }) {
    return PlaceVote(
      outingId: outingId,
      options: options ?? this.options,
      endsAt: endsAt ?? this.endsAt,
      cuserOptionIds: clearCuserOptions
          ? const []
          : (cuserOptionIds ?? this.cuserOptionIds),
      suggestedById: suggestedById,
      eligibleVoterCount: eligibleVoterCount,
      votedCount: votedCount,
      hasParticipationCounts: hasParticipationCounts,
      finalized: finalized ?? this.finalized,
      winningOptionId: winningOptionId,
      roundNumber: roundNumber,
      votingState: votingState,
      canResolveTie: canResolveTie,
      tiedOptionIds: tiedOptionIds,
    );
  }
}

class Attendance {
  const Attendance({
    required this.outingId,
    required this.userId,
    required this.status,
  });

  final String outingId;
  final String userId;
  final AttendanceStatus status;

  Map<String, dynamic> toJson() => {
    'outingId': outingId,
    'userId': userId,
    'status': status.name,
  };

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      outingId: json['outingId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      status: AttendanceStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => AttendanceStatus.unset,
      ),
    );
  }
}

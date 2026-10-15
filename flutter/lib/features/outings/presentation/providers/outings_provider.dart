import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/monitoring/analytics_service.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/outings/domain/entities/group_place_suggestion.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';

export 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart'
    show VoteOption;

class OutingsProvider extends ChangeNotifier {
  OutingsProvider({required this.repository});

  final OutingsRepository repository;

  var _outings = <Outing>[];
  var _suggestions = <GroupPlaceSuggestion>[];
  var _votesByOuting = <String, PlaceVote>{};
  var _attendanceByOuting = <String, Map<String, AttendanceStatus>>{};
  int _filter = 0;
  int _featuredIndex = 0;
  var _hasLoaded = false;
  var _isCreating = false;
  String? _errorMessage;

  static const maxVotePlaces = 5;

  List<Place> get places => repository.catalogPlaces;

  List<Outing> get outings => List.unmodifiable(_outings);

  List<GroupPlaceSuggestion> get suggestions => List.unmodifiable(_suggestions);

  bool get hasLoaded => _hasLoaded;

  bool get isCreating => _isCreating;

  String? get errorMessage => _errorMessage;

  List<Outing> get filtered {
    final status =
        OutingStatus.values[_filter.clamp(0, OutingStatus.values.length - 1)];
    return [
      for (final outing in _outings)
        if (outing.status == status) outing,
    ];
  }

  List<Outing> get needsYourVote {
    return [
      for (final outing in activeVotes)
        if (!hasVoted(outing.id)) outing,
    ];
  }

  /// Open place-voting outings (not expired). Source of truth for active vote UIs.
  List<Outing> get activeVotes {
    return [
      for (final outing in _outings)
        if (outing.status == OutingStatus.voting &&
            optionsFor(outing.id).isNotEmpty &&
            !isVoteExpired(outing.id))
          outing,
    ];
  }

  List<Outing> activeVotesForGroup(String groupId) {
    return [
      for (final outing in activeVotes)
        if (outing.groupId == groupId) outing,
    ];
  }

  int get filter => _filter;

  int get featuredIndex => _featuredIndex;

  Future<void> load({bool forceRefresh = false}) async {
    final result = await repository.load(forceRefresh: forceRefresh);
    result.fold((failure) {
      _errorMessage = failure.message;
      AppErrorFeedback.report(
        failure,
        kind: AppErrorKind.load,
        context: 'loadOutings',
      );
    }, _applySnapshot);
    _hasLoaded = true;
    notifyListeners();
  }

  void _applySnapshot(OutingSnapshot snapshot) {
    _outings = List.of(snapshot.outings);
    _suggestions = List.of(snapshot.suggestions);
    _votesByOuting = Map.of(snapshot.votesByOuting);
    _attendanceByOuting = {
      for (final entry in snapshot.attendanceByOuting.entries)
        entry.key: Map.of(entry.value),
    };
    _errorMessage = null;
  }

  List<Outing> forGroup(String groupId) {
    return _outings.where((outing) => outing.groupId == groupId).toList();
  }

  List<GroupPlaceSuggestion> suggestionsForGroup(String groupId) {
    return [
      for (final item in _suggestions)
        if (item.groupId == groupId) item,
    ];
  }

  List<VoteOption> optionsFor(String outingId) {
    return List.unmodifiable(_votesByOuting[outingId]?.options ?? const []);
  }

  int? voteIndexFor(String outingId) =>
      _votesByOuting[outingId]?.cuserOptionIndex;

  Set<int> voteIndexesFor(String outingId) =>
      Set<int>.from(_votesByOuting[outingId]?.cuserOptionIndexes ?? const {});

  bool hasVoted(String outingId) => _votesByOuting[outingId]?.hasVoted ?? false;

  bool isVoteFinalized(String outingId) =>
      _votesByOuting[outingId]?.finalized ?? false;

  /// Locked after the user confirms I'm In + at least one place.
  bool isParticipationLocked(String outingId) => isVoteFinalized(outingId);

  bool canSelectPlaces(String outingId, String? userId) {
    if (!canVote(outingId)) return false;
    if (isVoteFinalized(outingId)) return false;
    // Not In blocks place voting; I'm In / still deciding can pick places.
    return cuserAttendance(outingId, userId) != AttendanceStatus.notGoing;
  }

  DateTime? voteEndsAt(String outingId) => _votesByOuting[outingId]?.endsAt;

  bool isVoteExpired(String outingId) {
    final ends = voteEndsAt(outingId);
    if (ends == null) return false;
    return !ends.isAfter(DateTime.now());
  }

  Duration? voteRemaining(String outingId) {
    final ends = voteEndsAt(outingId);
    if (ends == null) return null;
    final remaining = ends.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int votedCountFor(String outingId) {
    final options = optionsFor(outingId);
    if (options.isEmpty) return 0;
    return options.fold<int>(0, (sum, option) => sum + option.votes);
  }

  bool canVote(String outingId) {
    final outing = findById(outingId);
    return outing?.status == OutingStatus.voting &&
        optionsFor(outingId).isNotEmpty &&
        !isVoteExpired(outingId);
  }

  Outing? findById(String id) {
    for (final outing in _outings) {
      if (outing.id == id) return outing;
    }
    return null;
  }

  /// Stand-in for deep links when the outing is not yet loaded.
  Outing byId(String id) =>
      findById(id) ?? (_outings.isNotEmpty ? _outings.first : _emptyOuting(id));

  static Outing _emptyOuting(String id) {
    return Outing(id: id, image: '', title: '', meta: '', date: '');
  }

  Map<String, AttendanceStatus> attendanceMapFor(String outingId) {
    return Map.unmodifiable(_attendanceByOuting[outingId] ?? const {});
  }

  AttendanceStatus attendanceFor(String outingId, String memberId) {
    return _attendanceByOuting[outingId]?[memberId] ??
        AttendanceStatus.notVoted;
  }

  AttendanceStatus cuserAttendance(String outingId, String? memberId) {
    if (memberId == null || memberId.isEmpty) return AttendanceStatus.notVoted;
    return attendanceFor(outingId, memberId);
  }

  int goingCountFor(String outingId) {
    final map = _attendanceByOuting[outingId];
    if (map == null || map.isEmpty) {
      return findById(outingId)?.going ?? 0;
    }
    return map.values
        .where((status) => status == AttendanceStatus.going)
        .length;
  }

  List<GroupMember> membersForOuting(Outing outing) {
    return repository.membersForOuting(outing);
  }

  bool canChangeAttendance(String outingId, {String? userId}) {
    final outing = findById(outingId);
    if (outing == null) return false;
    if (outing.isPastOuting || outing.status == OutingStatus.past) return false;
    if (isVoteFinalized(outingId)) return false;
    return true;
  }

  Future<bool> setAttendance(
    String outingId,
    String memberId,
    AttendanceStatus status,
  ) async {
    if (isVoteFinalized(outingId)) return false;
    final result = await repository.setAttendance(
      outingId: outingId,
      memberId: memberId,
      status: status,
    );
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'setAttendance',
        );
        notifyListeners();
        return false;
      },
      (snapshot) {
        _applySnapshot(snapshot);
        notifyListeners();
        return true;
      },
    );
  }

  void setFilter(int value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void setFeaturedIndex(int value) {
    if (_featuredIndex == value) return;
    _featuredIndex = value;
    notifyListeners();
  }

  Future<bool> selectVoteFor(String outingId, int value) async {
    if (isVoteFinalized(outingId) || isVoteExpired(outingId)) return false;
    final result = await repository.selectVote(outingId, value);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'submitVote',
        );
        notifyListeners();
        return false;
      },
      (snapshot) {
        _applySnapshot(snapshot);
        AnalyticsService.instance.submitVote();
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> finalizeVoteFor(String outingId) async {
    if (!hasVoted(outingId) || isVoteFinalized(outingId)) return false;
    final result = await repository.finalizeVote(outingId);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'finalizeVote',
        );
        notifyListeners();
        return false;
      },
      (snapshot) {
        _applySnapshot(snapshot);
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> add(Outing outing, {String? creatorId}) async {
    if (_isCreating) return false;
    _isCreating = true;
    notifyListeners();

    var ok = false;
    final result = await repository.add(outing, creatorId: creatorId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'createOuting',
        );
      },
      (snapshot) {
        _applySnapshot(snapshot);
        AnalyticsService.instance.createOuting(source: 'form');
        ok = true;
      },
    );
    _isCreating = false;
    notifyListeners();
    return ok;
  }

  Future<Outing?> suggestPlaces({
    required String groupId,
    required String title,
    required List<Place> places,
    required int deadlineHours,
    required String createdBy,
    String? createdById,
    String? image,
    DateTime? scheduledAt,
  }) async {
    if (_isCreating) return null;
    _isCreating = true;
    notifyListeners();

    final result = await repository.suggestPlaces(
      groupId: groupId,
      title: title,
      places: places,
      deadlineHours: deadlineHours,
      createdBy: createdBy,
      createdById: createdById,
      image: image,
      scheduledAt: scheduledAt,
    );
    Outing? created;
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'suggestPlaces',
        );
      },
      (snapshot) {
        _applySnapshot(snapshot);
        created = snapshot.outings.isNotEmpty ? snapshot.outings.first : null;
        AnalyticsService.instance.createOuting(source: 'suggest');
      },
    );
    _isCreating = false;
    notifyListeners();
    return created;
  }

  void clear() {
    _outings = [];
    _suggestions = [];
    _votesByOuting = {};
    _attendanceByOuting = {};
    _filter = 0;
    _featuredIndex = 0;
    _hasLoaded = false;
    _isCreating = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> refreshLifecycle() async {
    final result = await repository.refreshLifecycle();
    var changed = false;
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'refreshLifecycle',
        );
      },
      (snapshot) {
        changed =
            snapshot.outings.length != _outings.length ||
            snapshot.outings.map((e) => e.status).join() !=
                _outings.map((e) => e.status).join();
        _applySnapshot(snapshot);
      },
    );
    notifyListeners();
    return changed;
  }

  String specialEventImage(OutingOccasion occasion) =>
      repository.specialEventImage(occasion);

  static String placeKey(Place place) => place.placeId;
}

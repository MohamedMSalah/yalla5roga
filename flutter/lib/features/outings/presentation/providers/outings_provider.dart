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
  final _deletedOutingIds = <String>{};
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
    final tab = _filter.clamp(0, 2);
    return [
      for (final outing in _outings)
        if (_matchesFilterTab(outing.status, tab)) outing,
    ];
  }

  bool _matchesFilterTab(OutingStatus status, int tab) {
    switch (tab) {
      case 0:
        return status == OutingStatus.draft || status == OutingStatus.confirmed;
      case 1:
        return status == OutingStatus.voting;
      default:
        return status == OutingStatus.past || status == OutingStatus.cancelled;
    }
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
      _errorMessage = AppErrorFeedback.messageOf(failure);
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
    // A refresh started before DELETE may still contain the old outing.
    for (final id in _deletedOutingIds) {
      if (snapshot.outings.any((outing) => outing.id == id) ||
          snapshot.suggestions.any((item) => item.outingId == id)) {
        snapshot = snapshot.withoutOuting(id);
      }
    }
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
    // Attendance is independent of place voting.
    return userId != null && userId.isNotEmpty;
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
    return _attendanceByOuting[outingId]?[memberId] ?? AttendanceStatus.unset;
  }

  AttendanceStatus cuserAttendance(String outingId, String? memberId) {
    if (memberId == null || memberId.isEmpty) return AttendanceStatus.unset;
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
    if (outing.status == OutingStatus.past ||
        outing.status == OutingStatus.cancelled) {
      return false;
    }
    // Owner attendance is fixed Going on the backend.
    if (userId != null && userId.isNotEmpty && outing.createdById == userId) {
      return false;
    }
    return true;
  }

  bool isTied(String outingId) {
    final outing = findById(outingId);
    if (outing == null) return false;
    return outing.status == OutingStatus.voting && isVoteFinalized(outingId);
  }

  Future<String?> breakTieFor(String outingId) async {
    final result = await repository.breakTie(outingId);
    return result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'breakTie',
        );
        notifyListeners();
        return null;
      },
      (snapshot) {
        _applySnapshot(snapshot.snapshot);
        notifyListeners();
        return snapshot.winningOptionId;
      },
    );
  }

  Future<bool> setAttendance(
    String outingId,
    String memberId,
    AttendanceStatus status,
  ) async {
    // Attendance is independent of voting lock (product scenarios §3.10).
    final result = await repository.setAttendance(
      outingId: outingId,
      memberId: memberId,
      status: status,
    );
    return result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
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
        _errorMessage = AppErrorFeedback.messageOf(failure);
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

  /// Refresh after server-side closure (no client authority to finalize).
  Future<bool> finalizeVoteFor(String outingId) async {
    final result = await repository.refreshLifecycle(outingId: outingId);
    return result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        notifyListeners();
        return false;
      },
      (snapshot) {
        _applySnapshot(snapshot);
        notifyListeners();
        return isVoteFinalized(outingId);
      },
    );
  }

  Future<bool> delete(String outingId) async {
    final result = await repository.delete(outingId);
    return result.fold(
      (failure) {
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'deleteOuting',
        );
        return false;
      },
      (_) {
        _deletedOutingIds.add(outingId);
        _outings.removeWhere((outing) => outing.id == outingId);
        _suggestions.removeWhere((item) => item.outingId == outingId);
        _votesByOuting.remove(outingId);
        _attendanceByOuting.remove(outingId);
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
        _errorMessage = AppErrorFeedback.messageOf(failure);
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
        _errorMessage = AppErrorFeedback.messageOf(failure);
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
    _deletedOutingIds.clear();
    repository.clearCache();
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

  /// Refresh outing lifecycle. Prefer [outingId] on detail screens.
  Future<bool> refreshLifecycle({
    String? outingId,
    bool forceRefresh = false,
  }) async {
    final result = await repository.refreshLifecycle(
      outingId: outingId,
      forceRefresh: forceRefresh,
    );
    var changed = false;
    result.fold(
      (failure) {
        final message = AppErrorFeedback.messageOf(failure);
        changed = _errorMessage != message;
        _errorMessage = message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'refreshLifecycle',
        );
      },
      (snapshot) {
        changed = _snapshotDiffers(snapshot);
        _applySnapshot(snapshot);
      },
    );
    if (changed) notifyListeners();
    return changed;
  }

  bool _snapshotDiffers(OutingSnapshot snapshot) {
    if (!_sameOutings(_outings, snapshot.outings)) return true;
    if (_suggestions.length != snapshot.suggestions.length) return true;
    if (_votesByOuting.length != snapshot.votesByOuting.length) return true;
    if (_attendanceByOuting.length != snapshot.attendanceByOuting.length) {
      return true;
    }
    return false;
  }

  bool _sameOutings(List<Outing> a, List<Outing> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].status != b[i].status ||
          a[i].image != b[i].image ||
          a[i].title != b[i].title ||
          a[i].going != b[i].going) {
        return false;
      }
    }
    return true;
  }

  String specialEventImage(OutingOccasion occasion) =>
      repository.specialEventImage(occasion);

  static String placeKey(Place place) => place.placeId;
}

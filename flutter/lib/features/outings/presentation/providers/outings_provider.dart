import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:yalla_5roga/core/monitoring/analytics_service.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
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
  OutingsProvider({
    required this.repository,
    DateTime Function()? now,
    this.mediaUploads,
  }) : _now = now ?? DateTime.now;

  final OutingsRepository repository;
  final DateTime Function() _now;
  final MediaUploadService? mediaUploads;
  Timer? _scheduleTimer;
  final _visibleFeeds = <Object>{};
  final _checkedVoteDeadlines = <String, DateTime>{};

  DateTime currentTime() => _now();

  var _outings = <Outing>[];
  final _deletedOutingIds = <String>{};
  var _suggestions = <GroupPlaceSuggestion>[];
  var _votesByOuting = <String, PlaceVote>{};
  var _attendanceByOuting = <String, Map<String, AttendanceStatus>>{};
  final _pendingAttendance =
      <String, ({String user, AttendanceStatus status})>{};
  int _featuredIndex = 0;
  var _hasLoaded = false;
  var _hasCompleteOutingsList = false;
  List<Outing>? _groupCountsSource;
  Map<String, int> _groupCounts = const {};
  var _isCreating = false;
  String? _errorMessage;

  static const maxVotePlaces = 5;

  int _managementEpoch = 0;
  final _managing = <String>{};
  final _guests = <String, List<GroupMember>>{};
  final _guestLoads = <String, Future<void>>{};
  final _guestErrors = <String, String>{};
  bool guestsLoading(String id) => _guestLoads.containsKey(id);
  String? guestsError(String id) => _guestErrors[id];
  bool isManaging(String id) => _managing.contains(id);
  List<GroupMember> guestsFor(String id) => _guests[id] ?? const [];
  String? invitationStatus(String id, String uid) {
    final guest = guestsFor(id).where((g) => g.id == uid).firstOrNull;
    return guest == null
        ? null
        : guest.isPending
        ? 'pending'
        : 'accepted';
  }

  Future<void> loadGuests(String id) {
    final epoch = _managementEpoch;
    return _guestLoads[id] ??= _loadGuests(id).whenComplete(() {
      if (epoch == _managementEpoch) {
        _guestLoads.remove(id);
        notifyListeners();
      }
    });
  }

  Future<void> _loadGuests(String id) async {
    final epoch = _managementEpoch;
    final result = await repository.guests(id);
    if (epoch != _managementEpoch) return;
    result.fold(
      (failure) => _guestErrors[id] = AppErrorFeedback.messageOf(failure),
      (items) {
        _guestErrors.remove(id);
        _guests[id] = items;
      },
    );
    notifyListeners();
  }

  Future<bool> _manage(
    String id,
    Future<Either<Failure, OutingSnapshot>> Function() action,
  ) async {
    if (!_managing.add(id)) return false;
    _errorMessage = null;
    notifyListeners();
    final epoch = _managementEpoch;
    try {
      final result = await action();
      if (epoch != _managementEpoch) return false;
      return result.fold<bool>(
        (failure) {
          _errorMessage = AppErrorFeedback.messageOf(failure);
          return false;
        },
        (snapshot) {
          _applySnapshot(snapshot);
          return true;
        },
      );
    } finally {
      _managing.remove(id);
      notifyListeners();
    }
  }

  Future<bool> update(String id, Map<String, dynamic> changes) =>
      _manage(id, () async {
        final patch = Map<String, dynamic>.of(changes);
        final image = patch['image_url'] as String?;
        if (isLocalFilePath(image)) {
          try {
            if (mediaUploads == null) {
              return const Left(ServerFailure('Image upload unavailable'));
            }
            patch['image_url'] = (await mediaUploads!.uploadLocalImage(
              path: image!,
              purpose: MediaPurpose.outing,
            )).reference;
          } catch (error) {
            return Left(ExceptionMapper.toFailure(error));
          }
        }
        return repository.update(id, patch);
      });
  Future<bool> cancel(String id) => _manage(id, () => repository.cancel(id));
  Future<bool> removeGuest(String id, String uid) async {
    final ok = await _manage(id, () => repository.removeGuest(id, uid));
    if (ok) await loadGuests(id);
    return ok;
  }

  Future<bool> respondToInvitation(String id, {required bool accept}) async {
    final ok = await _manage(
      id,
      () => repository.respondToInvitation(id, accept: accept),
    );
    if (ok && accept) await loadGuests(id);
    return ok;
  }

  List<Place> get places => repository.catalogPlaces;

  List<Outing> get outings => List.unmodifiable(_outings);

  List<GroupPlaceSuggestion> get suggestions => List.unmodifiable(_suggestions);

  bool get hasLoaded => _hasLoaded;

  Map<String, int>? get groupOutingCounts {
    if (!_hasCompleteOutingsList) return null;
    if (!identical(_groupCountsSource, _outings)) {
      _groupCountsSource = _outings;
      final counts = <String, int>{};
      for (final outing in _outings) {
        if (outing.groupId case final id?) {
          counts.update(id, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      if (!mapEquals(counts, _groupCounts)) {
        _groupCounts = Map.unmodifiable(counts);
      }
    }
    return _groupCounts;
  }

  bool get isCreating => _isCreating;

  String? get errorMessage => _errorMessage;

  L10n? get _l10n => Get.context?.l10n;

  List<Outing> get history {
    final now = _now();
    return [
      for (final outing in _outings)
        if (_isArchived(outing, now)) outing,
    ]..sort(
      (a, b) => (b.scheduledAt ?? DateTime(0)).compareTo(
        a.scheduledAt ?? DateTime(0),
      ),
    );
  }

  List<Outing>? _sectionSource;
  DateTime? _sectionsReadAt;
  DateTime? _nextSectionChange;
  var _sections = (active: const <Outing>[], upcoming: const <Outing>[]);

  List<Outing> get upcoming => _feedSections().upcoming;

  /// Open place-voting outings with server options and an unexpired deadline.
  List<Outing> get activeVotes => _feedSections().active;

  ({List<Outing> active, List<Outing> upcoming}) _feedSections() {
    final now = _now();
    if (identical(_sectionSource, _outings) &&
        !now.isBefore(_sectionsReadAt!) &&
        (_nextSectionChange?.isAfter(now) ?? true)) {
      return _sections;
    }

    final active = <Outing>[];
    final upcoming = <Outing>[];
    DateTime? nextChange;
    void consider(DateTime? at) {
      if (at != null && (nextChange == null || at.isBefore(nextChange!))) {
        nextChange = at;
      }
    }

    for (final outing in _outings) {
      if (_isArchived(outing, now)) continue;
      consider(outing.scheduledAt);
      final deadline = voteDeadlineFor(outing);
      if (_isOpenVoteRound(outing) && (deadline?.isAfter(now) ?? true)) {
        active.add(outing);
        consider(deadline);
      } else {
        upcoming.add(outing);
      }
    }
    upcoming.sort((a, b) {
      final first = a.scheduledAt;
      final second = b.scheduledAt;
      if (first == null && second != null) return 1;
      if (first != null && second == null) return -1;
      final byDate = first == null ? 0 : first.compareTo(second!);
      return byDate == 0 ? a.id.compareTo(b.id) : byDate;
    });
    _sectionSource = _outings;
    _sectionsReadAt = now;
    _nextSectionChange = nextChange;
    return _sections = (
      active: List.unmodifiable(active),
      upcoming: List.unmodifiable(upcoming),
    );
  }

  bool _isArchived(Outing outing, DateTime now) =>
      outing.status == OutingStatus.cancelled || outing.isPastAt(now);

  void openFeed(Object owner) {
    if (_visibleFeeds.add(owner) && _visibleFeeds.length == 1) {
      _scheduleNextStart();
    }
  }

  void closeFeed(Object owner) {
    if (_visibleFeeds.remove(owner) && _visibleFeeds.isEmpty) {
      _scheduleNextStart();
    }
  }

  void refreshSchedule() {
    _sectionSource = null;
    _scheduleNextStart();
    notifyListeners();
  }

  void _scheduleNextStart() {
    _scheduleTimer?.cancel();
    final now = _now();
    DateTime? nextBoundary;
    void consider(DateTime at) {
      if (nextBoundary == null || at.isBefore(nextBoundary!)) {
        nextBoundary = at;
      }
    }

    final expired = <String, DateTime>{};
    final unresolved = <String>{};
    for (final outing in _outings) {
      if (_isArchived(outing, now)) continue;
      final start = outing.scheduledAt;
      if (start != null) consider(start);
      if (!_isOpenVoteRound(outing)) continue;
      final deadline = voteDeadlineFor(outing);
      if (deadline == null) continue;
      unresolved.add(outing.id);
      if (deadline.isAfter(now)) {
        consider(deadline);
      } else if (_visibleFeeds.isNotEmpty &&
          _checkedVoteDeadlines[outing.id] != deadline) {
        expired[outing.id] = deadline;
      }
    }
    _checkedVoteDeadlines.removeWhere((id, _) => !unresolved.contains(id));

    if (expired.isNotEmpty) {
      // Refresh once per deadline through the existing targeted read. Socket
      // invalidations still reconcile the result when the server closes a round.
      _scheduleTimer = Timer(Duration.zero, () {
        for (final entry in expired.entries) {
          _checkedVoteDeadlines[entry.key] = entry.value;
          unawaited(refreshLifecycle(outingId: entry.key, forceRefresh: true));
        }
        refreshSchedule();
      });
    } else if (nextBoundary case final at?) {
      _scheduleTimer = Timer(at.difference(now), refreshSchedule);
    }
  }

  List<Outing> get needsYourVote {
    return [
      for (final outing in activeVotes)
        if (!hasVoted(outing.id)) outing,
    ];
  }

  bool _isOpenVoteRound(Outing outing) {
    final vote = _votesByOuting[outing.id];
    return outing.status == OutingStatus.voting &&
        vote != null &&
        vote.options.isNotEmpty &&
        !vote.finalized &&
        (vote.votingState == 'active' || vote.votingState == 'revote_active');
  }

  int _sessionEpoch = 0;
  final _openOutings = <String, int>{};
  Iterable<String> get openOutingIds => _openOutings.keys;
  final _unavailableOutings = <String>{};
  bool isUnavailable(String id) =>
      _deletedOutingIds.contains(id) || _unavailableOutings.contains(id);
  bool containsOuting(String id) => findById(id) != null;

  bool applyAttendanceChange(
    String id,
    String userId,
    AttendanceStatus status,
    DateTime updatedAt,
  ) {
    final snapshot = repository.applyAttendanceChange(
      id,
      userId,
      status,
      updatedAt,
    );
    if (snapshot == null) return false;
    if (_snapshotDiffers(snapshot)) {
      _applySnapshot(snapshot, reschedule: false);
      notifyListeners();
    }
    return true;
  }

  void openOuting(String id) =>
      _openOutings.update(id, (count) => count + 1, ifAbsent: () => 1);

  void closeOuting(String id) {
    final count = _openOutings[id] ?? 0;
    if (count <= 1) {
      _openOutings.remove(id);
    } else {
      _openOutings[id] = count - 1;
    }
  }

  int get featuredIndex => _featuredIndex;

  Future<void> load({bool forceRefresh = false}) async {
    final epoch = _sessionEpoch;
    final result = await repository.load(forceRefresh: forceRefresh);
    if (epoch != _sessionEpoch ||
        OfflineSnapshots.cacheOnly && result.isLeft()) {
      return;
    }
    var changed = !_hasLoaded;
    result.fold(
      (failure) {
        changed =
            changed || _errorMessage != AppErrorFeedback.messageOf(failure);
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'loadOutings',
        );
      },
      (snapshot) {
        // A fresh authorized list can restore access after a group re-add.
        // Keep explicit deletion tombstones, but release old access denials.
        _unavailableOutings.removeAll(
          snapshot.outings.map((outing) => outing.id),
        );
        changed =
            changed ||
            _hasCompleteOutingsList != snapshot.hasCompleteOutingsList ||
            _errorMessage != null ||
            _snapshotDiffers(snapshot);
        if (changed) _applySnapshot(snapshot);
      },
    );
    _hasLoaded = true;
    if (changed) notifyListeners();
  }

  void _applySnapshot(OutingSnapshot snapshot, {bool reschedule = true}) {
    // An overlapping detail request may still contain a revoked or deleted outing.
    for (final id in {..._deletedOutingIds, ..._unavailableOutings}) {
      if (snapshot.outings.any((outing) => outing.id == id) ||
          snapshot.suggestions.any((item) => item.outingId == id)) {
        snapshot = snapshot.withoutOuting(id);
      }
    }
    _outings = List.of(snapshot.outings);
    _hasCompleteOutingsList = snapshot.hasCompleteOutingsList;
    _suggestions = List.of(snapshot.suggestions);
    _votesByOuting = Map.of(snapshot.votesByOuting);
    _attendanceByOuting = {
      for (final entry in snapshot.attendanceByOuting.entries)
        entry.key: Map.of(entry.value),
    };
    _errorMessage = null;
    if (reschedule) _scheduleNextStart();
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

  DateTime? voteDeadlineFor(Outing outing) =>
      voteEndsAt(outing.id) ?? outing.voteEndsAt;

  DateTime? _voteDeadlineById(String id) =>
      voteEndsAt(id) ?? findById(id)?.voteEndsAt;

  bool isVoteExpired(String outingId) =>
      _voteDeadlineById(outingId)?.isAfter(_now()) == false;

  Duration? voteRemaining(String outingId) {
    final ends = _voteDeadlineById(outingId);
    if (ends == null) return null;
    final remaining = ends.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  ({int voted, int eligible})? voteParticipationFor(String id) {
    final vote = _votesByOuting[id];
    if (vote == null || !vote.hasParticipationCounts) return null;
    return (voted: vote.votedCount, eligible: vote.eligibleVoterCount);
  }

  int eligibleVoterCountFor(String outingId) =>
      _votesByOuting[outingId]?.eligibleVoterCount ?? 0;

  int votedCountFor(String outingId) {
    return _votesByOuting[outingId]?.votedCount ?? 0;
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
  Outing byId(String id) => findById(id) ?? _emptyOuting(id);

  static Outing _emptyOuting(String id) {
    return Outing(id: id, image: '', title: '', meta: '', date: '');
  }

  bool hasAttendanceFor(String outingId) =>
      _attendanceByOuting.containsKey(outingId);

  int? attendanceParticipantCount(String outingId) =>
      _attendanceByOuting[outingId]?.length;

  bool isAttendanceParticipant(String outingId, String? userId) =>
      userId != null &&
      (_attendanceByOuting[outingId]?.containsKey(userId) ?? false);

  Map<String, AttendanceStatus> attendanceMapFor(String outingId) {
    final attendance = _attendanceByOuting[outingId];
    if (attendance == null) return const {};
    final pending = _pendingAttendance[outingId];
    return Map.unmodifiable({
      ...attendance,
      if (pending != null && attendance.containsKey(pending.user))
        pending.user: pending.status,
    });
  }

  bool isSavingAttendance(String outingId) =>
      _pendingAttendance.containsKey(outingId);

  AttendanceStatus attendanceFor(String outingId, String memberId) {
    final pending = _pendingAttendance[outingId];
    if (pending?.user == memberId &&
        isAttendanceParticipant(outingId, memberId)) {
      return pending!.status;
    }
    return _attendanceByOuting[outingId]?[memberId] ?? AttendanceStatus.unset;
  }

  AttendanceStatus cuserAttendance(String outingId, String? memberId) {
    if (memberId == null || memberId.isEmpty) return AttendanceStatus.unset;
    return attendanceFor(outingId, memberId);
  }

  int goingCountFor(String outingId) =>
      attendanceMapFor(outingId).values
          .where((status) => status == AttendanceStatus.going)
          .length;

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

  bool isTied(String outingId) =>
      _votesByOuting[outingId]?.votingState == 'tie_pending';
  bool canResolveTie(String outingId) =>
      isTied(outingId) && _votesByOuting[outingId]!.canResolveTie;
  int roundNumberFor(String outingId) =>
      _votesByOuting[outingId]?.roundNumber ?? 1;
  VoteOption? winningOptionFor(String id) {
    final vote = _votesByOuting[id];
    return vote?.options
        .where((o) => o.placeId == vote.winningOptionId)
        .firstOrNull;
  }

  List<VoteOption> tiedOptionsFor(String outingId) {
    final vote = _votesByOuting[outingId];
    return vote == null
        ? const []
        : vote.options
              .where((o) => vote.tiedOptionIds.contains(o.placeId))
              .toList();
  }

  Future<bool> startRevoteFor(
    String outingId,
    DateTime deadline,
    int roundNumber,
  ) async {
    if (_managing.contains(outingId) ||
        !canResolveTie(outingId) ||
        roundNumberFor(outingId) != roundNumber) {
      return false;
    }
    final epoch = _managementEpoch;
    _managing.add(outingId);
    notifyListeners();
    final result = await repository.startRevote(
      outingId,
      deadline,
      roundNumber,
    );
    if (epoch != _managementEpoch) return false;
    var success = result.fold((failure) => false, (snapshot) {
      _applySnapshot(snapshot);
      return true;
    });
    if (!success) {
      await refreshLifecycle(outingId: outingId, forceRefresh: true);
    }
    if (epoch != _managementEpoch) return false;
    _managing.remove(outingId);
    if (!success && roundNumberFor(outingId) == roundNumber + 1) success = true;
    if (!success) {
      result.fold(
        (failure) => AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'startRevote',
        ),
        (_) {},
      );
    }
    notifyListeners();
    return success;
  }

  Future<String?> breakTieFor(String outingId, [int? roundNumber]) async {
    if (_managing.contains(outingId) ||
        !canResolveTie(outingId) ||
        (roundNumber != null && roundNumberFor(outingId) != roundNumber)) {
      return null;
    }
    final epoch = _managementEpoch;
    _managing.add(outingId);
    notifyListeners();
    final result = await repository.breakTie(outingId, roundNumber);
    if (epoch != _managementEpoch) return null;
    if (result.isLeft()) {
      await refreshLifecycle(outingId: outingId, forceRefresh: true);
    }
    if (epoch != _managementEpoch) return null;
    _managing.remove(outingId);
    if (result.isLeft() && _votesByOuting[outingId]?.winningOptionId != null) {
      _errorMessage = null;
      notifyListeners();
      return null;
    }
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
    // Attendance is independent of voting lock (product scenarios Ãƒâ€šÃ‚Â§3.10).
    if (isSavingAttendance(outingId) ||
        !canChangeAttendance(outingId, userId: memberId) ||
        !isAttendanceParticipant(outingId, memberId)) {
      return false;
    }
    final epoch = _sessionEpoch;
    if (attendanceFor(outingId, memberId) == status) return true;
    final change = (user: memberId, status: status);
    _pendingAttendance[outingId] = change;
    notifyListeners();
    final result = await repository.setAttendance(
      outingId: outingId,
      memberId: memberId,
      status: status,
    );
    if (epoch != _sessionEpoch || _pendingAttendance[outingId] != change) {
      return false;
    }
    _pendingAttendance.remove(outingId);
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

  Future<bool> confirmVenue(String outingId, String optionId) async {
    final result = await repository.confirmVenue(outingId, optionId);
    return result.fold(
      (failure) {
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'confirmVenue',
        );
        return false;
      },
      (snapshot) {
        _applySnapshot(snapshot);
        notifyListeners();
        return true;
      },
    );
  }

  void setFeaturedIndex(int value) {
    if (_featuredIndex == value) return;
    _featuredIndex = value;
    notifyListeners();
  }

  Future<bool> setBallotFor(String outingId, Set<int> indexes) async {
    if (isVoteFinalized(outingId) || isVoteExpired(outingId)) return false;
    final result = await repository.setBallot(outingId, indexes);
    return result.fold(
      (failure) {
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'submitBallot',
        );
        return false;
      },
      (snapshot) {
        _applySnapshot(snapshot);
        notifyListeners();
        return true;
      },
    );
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
        _outings = _outings.where((outing) => outing.id != outingId).toList();
        _suggestions.removeWhere((item) => item.outingId == outingId);
        _votesByOuting.remove(outingId);
        _attendanceByOuting.remove(outingId);
        refreshSchedule();
        return true;
      },
    );
  }

  Future<OutingCreation?> add(
    Outing outing, {
    String? creatorId,
    VoidCallback? onStaleMeetupResult,
  }) async {
    if (_isCreating) return null;
    final epoch = _sessionEpoch;
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    var outgoing = outing;
    if (isLocalFilePath(outgoing.image)) {
      final uploads = mediaUploads;
      if (uploads == null) {
        _isCreating = false;
        _errorMessage = _l10n?.imageUploadFailed;
        notifyListeners();
        return null;
      }
      try {
        final uploaded = await uploads.uploadLocalImage(
          path: outgoing.image,
          purpose: MediaPurpose.outing,
        );
        if (epoch != _sessionEpoch) return null;
        outgoing = outgoing.copyWith(image: uploaded.reference);
      } catch (_) {
        if (epoch != _sessionEpoch) return null;
        _isCreating = false;
        _errorMessage = _l10n?.imageUploadFailed;
        notifyListeners();
        return null;
      }
    }

    final result = await repository.add(outgoing, creatorId: creatorId);
    if (epoch != _sessionEpoch) return null;
    final created = result.fold<OutingCreation?>(
      (failure) {
        if (onStaleMeetupResult != null &&
            failure.code == ErrorCodes.staleMeetupResult) {
          onStaleMeetupResult();
          return null;
        }
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'createOuting',
        );
        return null;
      },
      (creation) {
        _applySnapshot(creation.snapshot);
        AnalyticsService.instance.createOuting(source: 'form');
        return creation;
      },
    );
    _isCreating = false;
    notifyListeners();
    return created;
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

    var imageRef = image;
    if (isLocalFilePath(imageRef)) {
      final uploads = mediaUploads;
      if (uploads == null) {
        _isCreating = false;
        _errorMessage = _l10n?.imageUploadFailed;
        notifyListeners();
        return null;
      }
      try {
        final uploaded = await uploads.uploadLocalImage(
          path: imageRef!,
          purpose: MediaPurpose.outing,
        );
        imageRef = uploaded.reference;
      } catch (_) {
        _isCreating = false;
        _errorMessage = _l10n?.imageUploadFailed;
        notifyListeners();
        return null;
      }
    }

    final result = await repository.suggestPlaces(
      groupId: groupId,
      title: title,
      places: places,
      deadlineHours: deadlineHours,
      createdBy: createdBy,
      createdById: createdById,
      image: imageRef,
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
    _sessionEpoch++;
    _openOutings.clear();
    _unavailableOutings.clear();
    _pendingAttendance.clear();
    _deletedOutingIds.clear();
    repository.clearCache();
    _managementEpoch++;
    _guests.clear();
    _guestLoads.clear();
    _guestErrors.clear();
    _managing.clear();
    _outings = [];
    _suggestions = [];
    _votesByOuting = {};
    _checkedVoteDeadlines.clear();
    _attendanceByOuting = {};
    _featuredIndex = 0;
    _hasLoaded = false;
    _hasCompleteOutingsList = false;
    _groupCountsSource = null;
    _groupCounts = const {};
    _isCreating = false;
    _errorMessage = null;
    refreshSchedule();
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
  }

  void applyDetailsSnapshot(OutingSnapshot snapshot) {
    _applySnapshot(snapshot);
    notifyListeners();
  }

  /// Refresh outing lifecycle. Prefer [outingId] on detail screens.
  Future<bool> refreshLifecycle({
    String? outingId,
    bool forceRefresh = false,
  }) async {
    final epoch = _sessionEpoch;
    final result = await repository.refreshLifecycle(
      outingId: outingId,
      forceRefresh: forceRefresh,
    );
    if (epoch != _sessionEpoch ||
        OfflineSnapshots.cacheOnly && result.isLeft()) {
      return false;
    }
    var changed = false;
    result.fold(
      (failure) {
        if (outingId != null &&
            (failure.statusCode == 403 || failure.statusCode == 404)) {
          changed = _unavailableOutings.add(outingId);
          _outings = _outings.where((item) => item.id != outingId).toList();
          _votesByOuting.remove(outingId);
          _attendanceByOuting.remove(outingId);
          return;
        }
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
        changed =
            (outingId != null && _unavailableOutings.remove(outingId)) ||
            _errorMessage != null ||
            _snapshotDiffers(snapshot);
        _errorMessage = null;
        _applySnapshot(snapshot, reschedule: changed);
      },
    );
    if (changed) notifyListeners();
    return changed;
  }

  bool _snapshotDiffers(OutingSnapshot snapshot) {
    if (!_sameOutings(_outings, snapshot.outings)) return true;
    if (_suggestions.length != snapshot.suggestions.length) return true;
    if (_votesByOuting.length != snapshot.votesByOuting.length ||
        _attendanceByOuting.length != snapshot.attendanceByOuting.length) {
      return true;
    }
    for (final entry in snapshot.attendanceByOuting.entries) {
      if (!mapEquals(entry.value, _attendanceByOuting[entry.key])) return true;
    }
    for (final entry in snapshot.votesByOuting.entries) {
      final next = entry.value;
      final previous = _votesByOuting[entry.key];
      if (previous == null ||
          previous.roundNumber != next.roundNumber ||
          previous.votingState != next.votingState ||
          previous.canResolveTie != next.canResolveTie ||
          previous.winningOptionId != next.winningOptionId ||
          !listEquals(previous.tiedOptionIds, next.tiedOptionIds) ||
          previous.finalized != next.finalized ||
          previous.endsAt != next.endsAt ||
          previous.eligibleVoterCount != next.eligibleVoterCount ||
          previous.votedCount != next.votedCount ||
          previous.hasParticipationCounts != next.hasParticipationCounts ||
          !listEquals(previous.cuserOptionIds, next.cuserOptionIds) ||
          previous.options.length != next.options.length) {
        return true;
      }
      for (var index = 0; index < next.options.length; index++) {
        final before = previous.options[index];
        final after = next.options[index];
        if (before.placeId != after.placeId ||
            before.catalogPlaceId != after.catalogPlaceId ||
            before.label != after.label ||
            before.area != after.area ||
            before.categoryId != after.categoryId ||
            before.imageUrl != after.imageUrl ||
            before.votes != after.votes ||
            before.percent != after.percent) {
          return true;
        }
      }
    }
    return false;
  }

  bool _sameOutings(List<Outing> a, List<Outing> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].status != b[i].status ||
          a[i].scheduledAt != b[i].scheduledAt ||
          a[i].endsAt != b[i].endsAt ||
          a[i].location?.label != b[i].location?.label ||
          a[i].location?.latitude != b[i].location?.latitude ||
          a[i].location?.longitude != b[i].location?.longitude ||
          a[i].image != b[i].image ||
          a[i].title != b[i].title ||
          a[i].going != b[i].going ||
          a[i].meta != b[i].meta ||
          a[i].date != b[i].date ||
          a[i].time != b[i].time ||
          a[i].groupId != b[i].groupId ||
          a[i].location?.placeId != b[i].location?.placeId ||
          a[i].occasion != b[i].occasion ||
          a[i].type != b[i].type ||
          a[i].createdById != b[i].createdById ||
          a[i].suggestedBy != b[i].suggestedBy ||
          a[i].voteDeadlineHours != b[i].voteDeadlineHours ||
          a[i].voteEndsAt != b[i].voteEndsAt ||
          !listEquals(a[i].guestIds, b[i].guestIds) ||
          !listEquals(a[i].guestPhones, b[i].guestPhones) ||
          a[i].votePlaces.length != b[i].votePlaces.length) {
        return false;
      }
      for (var index = 0; index < a[i].votePlaces.length; index++) {
        if (!mapEquals(
          a[i].votePlaces[index].toJson(),
          b[i].votePlaces[index].toJson(),
        )) {
          return false;
        }
      }
    }
    return true;
  }

  String specialEventImage(OutingOccasion occasion) =>
      repository.specialEventImage(occasion);

  static String placeKey(Place place) => place.placeId;
}

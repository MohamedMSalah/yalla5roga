exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit(f+'features/outings/data/datasources/outings_remote_datasource.dart',
 ("import 'package:dio/dio.dart';","import 'package:dio/dio.dart';\nimport 'package:yalla_5roga/core/cache/offline_snapshots.dart';"),
 ("RequestDeduper.keyFor(method: 'GET', path: 'outing-details:$outingId'),","""RequestDeduper.keyFor(
          method: 'GET',
          path: 'outing-details:$outingId',
          query: {'preview': OfflineSnapshots.cacheOnly, 'row': includeOutingRow},
        ),"""),
 ('''    PlaceVote? vote;
    Map<String, AttendanceStatus>? attendance;

    if (loadVotes && loadAttendance) {
      final results = await Future.wait<Object>([
        _loadVotes(outingId),
        _loadAttendance(outingId),
      ]);
      vote = results[0] as PlaceVote;
      attendance = results[1] as Map<String, AttendanceStatus>;
    } else if (loadVotes) {
      vote = await _loadVotes(outingId);
    } else if (loadAttendance) {
      attendance = await _loadAttendance(outingId);
    }

    return _HydratedOuting(
      outingId: outingId,
      vote: vote,
      attendance: attendance,
    );''','''    final votes = loadVotes ? _optionalRead(() => _loadVotes(outingId)) : Future<PlaceVote?>.value();
    final attendance = loadAttendance ? _optionalRead(() => _loadAttendance(outingId)) : Future<Map<String, AttendanceStatus>?>.value();
    final results = await Future.wait<Object?>([votes, attendance]);
    return _HydratedOuting(
      outingId: outingId,
      vote: results[0] as PlaceVote?,
      attendance: results[1] as Map<String, AttendanceStatus>?,
    );'''),
 ('  Future<List<Map<String, dynamic>>> _ensureOptions', '''  Future<T?> _optionalRead<T>(Future<T> Function() load) async {
    try {
      return await load();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (error.error is NetworkException || status == 403 || status == 404 ||
          (status ?? 0) >= 500) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _ensureOptions'''))
edit(f+'features/groups/presentation/providers/groups_provider.dart',
 ('''    final result = await repository.getGroup(
      groupId,''','''    if (allowStale && !OfflineSnapshots.cacheOnly &&
        (existing == null || existing.members.isEmpty)) {
      final preview = await OfflineSnapshots.preview(() =>
          repository.getGroup(groupId, forceRefresh: true));
      if (epoch != _epoch) return null;
      preview.fold((_) {}, (group) {
        if (findById(groupId) == null) {
          _groups = [group, ..._groups];
        } else {
          _groups[_groups.indexWhere((item) => item.id == groupId)] = group;
        }
        notifyListeners();
      });
    }
    final result = await repository.getGroup(
      groupId,'''),
 ('      return allowStale ? existing : null;', '      return allowStale ? findById(groupId) : null;'))
edit(f+'features/outings/presentation/pages/event_page.dart',
 ("import 'package:yalla_5roga/core/animations/flying_item_animator.dart';","import 'package:yalla_5roga/core/animations/flying_item_animator.dart';\nimport 'package:yalla_5roga/core/cache/offline_snapshots.dart';\nimport 'package:yalla_5roga/core/widgets/app_empty_state.dart';"),
 ('''    await context.read<OutingsProvider>().refreshLifecycle(
      outingId: widget.event.id,
    );
    if (mounted) setState(() => _loadingDetails = false);''','''    final outings = context.read<OutingsProvider>();
    final changed = await OfflineSnapshots.preview(
      () => outings.refreshLifecycle(outingId: widget.event.id),
    );
    if (mounted && changed) setState(() => _loadingDetails = false);
    await outings.refreshLifecycle(outingId: widget.event.id);
    if (mounted && _loadingDetails) setState(() => _loadingDetails = false);'''),
 ('''    final live = outings.findById(widget.event.id) ?? widget.event;''','''    if (outings.isUnavailable(widget.event.id)) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.navOutings),
        body: AppEmptyState(icon: Icons.event_busy_outlined, message: l10n.dataLoadFailed),
      );
    }
    final live = outings.findById(widget.event.id) ?? widget.event;'''))
edit(f+'features/outings/presentation/providers/outings_provider.dart',
 ('  bool containsOuting', '  final _unavailableOutings = <String>{};\n  bool isUnavailable(String id) => _unavailableOutings.contains(id);\n  bool containsOuting'),
 ('    _openOutings.clear();','    _openOutings.clear();\n    _unavailableOutings.clear();'),
 ('''        final message = AppErrorFeedback.messageOf(failure);
        changed = _errorMessage != message;''','''        if (outingId != null && (failure.statusCode == 403 || failure.statusCode == 404)) {
          changed = _unavailableOutings.add(outingId);
          _outings.removeWhere((item) => item.id == outingId);
          _votesByOuting.remove(outingId);
          _attendanceByOuting.remove(outingId);
          return;
        }
        final message = AppErrorFeedback.messageOf(failure);
        changed = _errorMessage != message;'''),
 ('''        changed = _errorMessage != null || _snapshotDiffers(snapshot);''','''        changed = (outingId != null && _unavailableOutings.remove(outingId)) ||
            _errorMessage != null || _snapshotDiffers(snapshot);'''))
edit('backend/src/services/outings/vote-resolution.ts',
 ('import { notifyOutingParticipants }', 'import { publishOutingChange } from "../../realtime/data-changes.js";\nimport { notifyOutingParticipants }'),
 ('  const { outing, outcome } = result;', '  const { outing, outcome } = result;\n  await publishOutingChange(outing.id);'))

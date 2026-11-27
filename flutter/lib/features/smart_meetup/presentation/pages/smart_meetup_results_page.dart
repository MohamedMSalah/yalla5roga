import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/widgets/realtime_route.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

import 'package:yalla_5roga/features/route_preview/presentation/route_preview_page.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_result_handoff_model.dart';
import '../../domain/entities/meetup_results.dart';
import '../../domain/entities/meetup_session.dart'
    show MeetupCalculationStatus, MeetupSessionStatus;
import '../../domain/repositories/smart_meetup_repository.dart';
import '../../domain/smart_meetup_realtime.dart';
import '../providers/meetup_results_provider.dart';
import '../widgets/applied_preferences_bar.dart';
import '../widgets/meetup_recommendation_card.dart';
import '../widgets/meetup_result_states.dart';
import '../widgets/meetup_results_map_layer.dart';
import '../widgets/meetup_venue_selection_sheet.dart';
import '../widgets/meetup_widgets.dart';
import '../widgets/select_for_voting_action.dart';
import '../widgets/stale_meetup_result_dialog.dart';
import '../widgets/smart_meetup_realtime_route.dart';

class SmartMeetupResultsPage extends StatefulWidget {
  const SmartMeetupResultsPage({
    super.key,
    required this.sessionId,
    required this.inputVersion,
    required this.expiresAt,
    this.groupId,
    this.categories = const [],
    this.selectionLimit,
    this.refreshOnOpen = false,
  });

  final String sessionId;
  final int inputVersion;
  final DateTime expiresAt;
  final String? groupId;
  final List<MeetupCategoryOption> categories;
  final int? selectionLimit;
  final bool refreshOnOpen;

  @override
  State<SmartMeetupResultsPage> createState() => _SmartMeetupResultsPageState();
}

class _SmartMeetupResultsPageState extends State<SmartMeetupResultsPage>
    with
        RealtimeRoute<SmartMeetupResultsPage>,
        WidgetsBindingObserver,
        SmartMeetupRealtimeRoute<SmartMeetupResultsPage> {
  late final AuthProvider _auth;
  late final AppSyncProvider _sync;
  late final GroupsProvider _groups;
  late final MeetupResultsProvider _provider;
  late final String? _account;
  bool _selecting = false;
  String? _focusedId;
  final _cards = <String, GlobalKey>{};

  @override
  String? get realtimeGroupId => widget.groupId;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>()..addListener(_accountChanged);
    _account = _auth.user?.id;
    _sync = context.read<AppSyncProvider>()..addListener(_syncChanged);
    _groups = context.read<GroupsProvider>();
    _provider = MeetupResultsProvider(
      context.read<SmartMeetupRepository>(),
      widget.sessionId,
      _account,
      widget.inputVersion,
      realtime: context.read<SmartMeetupRealtime>(),
      sessionExpiresAt: widget.expiresAt,
    )..setOffline(_sync.status == SyncStatus.offline);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          widget.refreshOnOpen ? _provider.refresh() : _provider.load(),
        );
      }
    });
  }

  @override
  void setMeetupRouteActive(bool active) => _provider.setActive(active);

  void _accountChanged() =>
      _provider.accountChanged(_auth.isAuthenticated ? _auth.user?.id : null);

  void _syncChanged() =>
      _provider.setOffline(_sync.status == SyncStatus.offline);

  @override
  void dispose() {
    _sync.removeListener(_syncChanged);
    _auth.removeListener(_accountChanged);
    _provider.dispose();
    super.dispose();
  }

  void _focusCard(String id) {
    setState(() => _focusedId = id);
    final card = _cards[id]?.currentContext;
    if (card != null) {
      unawaited(Scrollable.ensureVisible(card, alignment: .1));
    }
  }

  bool get _isCurrent =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      _account == _auth.user?.id;

  Future<void> _openDetails(String placeId) async {
    final checked = await _provider.validate({placeId});
    if (!_isCurrent || checked == null) return;
    await Get.to(() => DiscoverPlaceDetailsPage(placeId: placeId));
  }

  Future<void> _useVenues(Set<String> placeIds) async {
    if (!_isCurrent) return;
    final groupId = widget.groupId;
    final group = groupId == null ? null : _groups.findById(groupId);
    if (groupId != null && group == null) return;
    final checked = await _provider.validate(placeIds);
    if (!mounted || !_isCurrent) return;
    final calculation = _provider.result?.calculation;
    if (checked == null || calculation == null) {
      if (_provider.isStale ||
          [404, 409].contains(_provider.failure?.statusCode)) {
        final refresh = await StaleMeetupResultDialog.show(context);
        if (refresh && _isCurrent) await _provider.refresh();
      }
      return;
    }
    final handoff = MeetupResultHandoffModel(
      sessionId: widget.sessionId,
      calculationId: calculation.id,
      groupId: groupId,
      places: checked.map((row) => row.place.toOutingPlace()),
    );
    if (widget.selectionLimit != null) {
      Navigator.of(context).pop(handoff);
      return;
    }
    await Get.to(
      () => CreateOutingPage(
        group: group,
        meetupSelection: handoff,
        suggestionOwner: _account,
      ),
    );
  }

  Future<void> _selectForVoting(List<MeetupRecommendation> rows) async {
    if (!_provider.canConsume || _selecting) return;
    final calculationId = _provider.result!.calculation!.id;
    _selecting = true;
    try {
      final selected = await MeetupVenueSelectionSheet.show(
        context,
        provider: _provider,
        calculationId: calculationId,
        recommendations: rows,
        limit: widget.selectionLimit ?? 5,
      );
      if (selected != null &&
          _isCurrent &&
          _provider.result?.calculation?.id == calculationId) {
        await _useVenues(selected);
      }
    } finally {
      _selecting = false;
    }
  }

  void _openRoute(MeetupRecommendation row, MeetupCalculation calculation) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoutePreviewPage(
          target: (
            scope: (
              context: StartingLocationContext.meetup,
              id: widget.sessionId,
            ),
            recommendation: (
              placeId: row.place.id,
              calculationId: calculation.id,
              inputVersion: calculation.inputVersion,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _provider,
    builder: (context, _) {
      final l10n = context.l10n;
      final groupId = widget.groupId;
      final title = groupId == null
          ? l10n.quickMeetup
          : context.watch<GroupsProvider>().findById(groupId)?.name ??
                l10n.smartMeetup;
      final result = _provider.result;
      final failure = _provider.failure;
      final offline = _provider.offline || failure is NetworkFailure;
      final stale = _provider.isStale;
      final sessionStatus = _provider.sessionStatus;
      final closed = sessionStatus != MeetupSessionStatus.active;
      final rows =
          result?.canConsume == true && !stale && !offline && failure == null
          ? result!.recommendations
          : const <MeetupRecommendation>[];
      final canUse = _provider.canConsume;
      final canCreate =
          canUse && (groupId == null || _groups.findById(groupId) != null);
      _cards.removeWhere((id, _) => !rows.any((row) => row.place.id == id));
      return GroupPageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GroupPageAppBar(title: title),
          body: RefreshIndicator(
            onRefresh: _provider.refresh,
            child: GroupPageList(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (offline)
                  const AppOfflineIndicator(isOffline: true)
                else if (failure != null)
                  MeetupResultNotice(
                    icon: Icons.error_outline,
                    message: FailureMessageMapper.localize(failure, l10n),
                  ),
                if (closed)
                  MeetupResultNotice(
                    icon: Icons.event_busy_outlined,
                    message: sessionStatus == MeetupSessionStatus.expired
                        ? l10n.meetupExpired
                        : l10n.meetupCancelled,
                  )
                else if (result == null && failure == null && !offline)
                  const MeetupSkeleton(),
                if (result != null) ...[
                  if (result.intendedParticipantCount > 0)
                    MeetupReadinessSummary(result: result),
                  const SizedBox(height: 8),
                  AppliedPreferencesBar(
                    preferences: result.preferences,
                    categories: widget.categories,
                  ),
                  const SizedBox(height: 8),
                  if (stale)
                    const StaleResultsBanner()
                  else if (!offline && failure == null)
                    ..._statusWidgets(context, result),
                ],
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      height: (constraints.maxWidth * .67)
                          .clamp(210, 330)
                          .toDouble(),
                      child: MeetupResultsMapLayer(
                        recommendations: rows,
                        focusedId: _focusedId,
                        onPlaceTap: _focusCard,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          for (final row in rows)
                            SizedBox(
                              key: _cards.putIfAbsent(
                                row.place.id,
                                GlobalKey.new,
                              ),
                              width: math.min(
                                constraints.maxWidth *
                                    (rows.length == 1 ? 1 : .90),
                                340,
                              ),
                              child: MeetupRecommendationCard(
                                recommendation: row,
                                selected: row.place.id == _focusedId,
                                onFocus: () =>
                                    setState(() => _focusedId = row.place.id),
                                onDetails: canUse
                                    ? () => _openDetails(row.place.id)
                                    : null,
                                onRoutePreview:
                                    canUse && result?.calculation != null
                                    ? () =>
                                          _openRoute(row, result!.calculation!)
                                    : null,
                                onCreateOuting: canCreate
                                    ? () => _useVenues({row.place.id})
                                    : null,
                                selectionMode: widget.selectionLimit != null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if ((widget.selectionLimit ?? 5) >= 2 && rows.length >= 2)
                  SelectForVotingAction(
                    onPressed: canCreate ? () => _selectForVoting(rows) : null,
                  ),
                if (!closed)
                  TextButton.icon(
                    onPressed: _provider.loading || _provider.offline
                        ? null
                        : _provider.refresh,
                    icon: _provider.loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(l10n.meetupRefreshResults),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _statusWidgets(BuildContext context, MeetupResults result) {
    final l10n = context.l10n;
    return [
      if (result.isPartial &&
          (result.status == MeetupCalculationStatus.partial ||
              result.status == MeetupCalculationStatus.noMatchingVenues))
        PartialResultsBanner(count: result.includedParticipantCount),
      switch (result.status) {
        MeetupCalculationStatus.routingUnavailable =>
          const RoutingUnavailableWidget(),
        MeetupCalculationStatus.insufficientData => MeetupResultNotice(
          icon: Icons.location_off_outlined,
          message: l10n.meetupMissingInputs,
        ),
        MeetupCalculationStatus.queued ||
        MeetupCalculationStatus.calculating => MeetupResultNotice(
          icon: Icons.hourglass_top,
          message: l10n.meetupCalculating,
        ),
        MeetupCalculationStatus.failed => MeetupResultNotice(
          icon: Icons.error_outline,
          message: l10n.meetupCalculationFailed,
        ),
        MeetupCalculationStatus.noMatchingVenues => MeetupResultNotice(
          icon: Icons.search_off,
          message: l10n.meetupNoMatchingVenues,
        ),
        _ => const SizedBox.shrink(),
      },
      if (result.calculation?.calculatedAt?.toLocal() case final at?)
        Text(l10n.meetupCalculatedAt(at), style: context.texts.bodySmall),
      if (result.calculation?.calculatedAt != null)
        if (result.calculation?.expiresAt?.toLocal() case final at?)
          Text(l10n.meetupValidUntil(at), style: context.texts.bodySmall),
    ];
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/maps/personal_location_map_layer.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/starting_location_editor.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/location_privacy/presentation/pages/location_privacy_page.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/pages/my_locations_page.dart';

import '../../domain/entities/meetup_result_handoff_model.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/entities/standalone_participant.dart';
import '../../domain/repositories/smart_meetup_repository.dart';
import '../../domain/smart_meetup_realtime.dart';
import '../providers/smart_meetup_provider.dart';
import '../widgets/manual_participant_card.dart';
import '../widgets/manual_participant_editor.dart';
import '../widgets/meetup_preferences_summary.dart';
import '../widgets/meetup_widgets.dart';
import '../widgets/smart_meetup_realtime_route.dart';
import 'smart_meetup_results_page.dart';

class QuickMeetupPage extends StatefulWidget {
  const QuickMeetupPage({super.key, this.selectionLimit});

  final int? selectionLimit;

  @override
  State<QuickMeetupPage> createState() => _QuickMeetupPageState();
}

class _QuickMeetupPageState extends State<QuickMeetupPage>
    with WidgetsBindingObserver, SmartMeetupRealtimeRoute<QuickMeetupPage> {
  final _map = YallaMapController();
  late final SmartMeetupProvider _meetup;
  late final AuthProvider _auth;
  late final AppSyncProvider _sync;
  late SyncStatus _syncStatus;
  List<PersonalMapMarker> _markers = const [];

  Future<void> _openResults(MeetupSession session) async {
    final owner = _auth.user?.id;
    final sessionId = session.id;
    final inputVersion = session.inputVersion;
    final expiresAt = session.expiresAt;
    final selected = await Get.to<MeetupResultHandoffModel>(
      () => SmartMeetupResultsPage(
        sessionId: sessionId,
        inputVersion: inputVersion,
        expiresAt: expiresAt,
        categories: _meetup.preferences.categories ?? const [],
        selectionLimit: widget.selectionLimit,
      ),
    );
    if (mounted && owner == _auth.user?.id && selected != null) {
      Navigator.of(context).pop(selected);
    }
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>()..addListener(_accountChanged);
    _sync = context.read<AppSyncProvider>()..addListener(_syncChanged);
    _syncStatus = _sync.status;
    _meetup = SmartMeetupProvider.standalone(
      context.read<SmartMeetupRepository>(),
      _auth.user?.id,
      realtime: context.read<SmartMeetupRealtime>(),
    )..addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_meetup.open());
    });
  }

  void _accountChanged() =>
      _meetup.accountChanged(_auth.isAuthenticated ? _auth.user?.id : null);

  void _syncChanged() {
    final previous = _syncStatus;
    _syncStatus = _sync.status;
    if (previous == SyncStatus.offline && _syncStatus != SyncStatus.offline) {
      _meetup.requestReload();
    }
  }

  @override
  void setMeetupRouteActive(bool active) => _meetup.setActive(active);

  void _sessionChanged() {
    final session = _meetup.session;
    final expires = session?.status == MeetupSessionStatus.active
        ? session?.expiresAt
        : null;
    final active =
        _meetup.snapshotIsCurrent &&
        (expires?.isAfter(DateTime.now()) ?? false);
    final markers = [
      if (active)
        for (final participant in session!.standaloneParticipants)
          if (_point(participant) case final point?)
            (
              key: participant.id,
              point: point,
              icon: participant.isOwner
                  ? ManualParticipantCard.ownerIcon
                  : ManualParticipantCard.guestIcon,
              isDefault: participant.isOwner,
              catalogPlaceId: null,
            ),
    ];
    if (listEquals(_markers, markers)) return;
    _markers = markers;
    final points = markers.map((marker) => marker.point).toList();
    if (points.length == 1) {
      _map.focus(points.first, zoom: 14);
    } else if (points.isNotEmpty) {
      _map.fit(points, padding: const EdgeInsets.all(40));
    }
  }

  LatLng? _point(StandaloneParticipant participant) {
    final latitude = participant.latitude, longitude = participant.longitude;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude.clamp(-85.051129, 85.051129).toDouble(), longitude);
  }

  @override
  void dispose() {
    _auth.removeListener(_accountChanged);
    _sync.removeListener(_syncChanged);
    _meetup.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _edit([StandaloneParticipant? participant]) async {
    await AddParticipantBottomSheet.show(
      context,
      _meetup,
      participant: participant,
    );
    if (mounted && _meetup.failure != null) await _meetup.reload();
  }

  Future<void> _remove(StandaloneParticipant participant) async {
    final l10n = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l10n.meetupRemoveGuest,
      message: l10n.meetupRemoveGuestConfirmation,
      confirmText: l10n.meetupRemoveGuest,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (mounted && confirmed) await _meetup.removeParticipant(participant.id);
  }

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l10n.meetupCancel,
      message: l10n.meetupQuickCancelConfirmation,
      confirmText: l10n.meetupCancel,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (mounted && confirmed) await _meetup.cancel();
  }

  Future<void> _setup(Widget Function() page) async {
    await Get.to(page);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _meetup,
    builder: (context, _) {
      final l10n = context.l10n;
      final session = _meetup.session;
      final failure = _meetup.failure;
      final locallyExpired =
          session != null && !session.expiresAt.isAfter(DateTime.now());
      final closed =
          session != null &&
          (locallyExpired || session.status != MeetupSessionStatus.active);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.quickMeetup)),
        body: (session == null || !_meetup.snapshotIsCurrent) && failure != null
            ? AppErrorState(
                message: FailureMessageMapper.localize(failure, l10n),
                onRetry: _meetup.reload,
              )
            : RefreshIndicator(
                onRefresh: _meetup.reload,
                child: GroupPageList(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (session == null || !_meetup.snapshotIsCurrent)
                      const MeetupSkeleton()
                    else if (closed) ...[
                      Text(
                        session.status == MeetupSessionStatus.cancelled
                            ? l10n.meetupCancelled
                            : l10n.meetupExpired,
                      ),
                      FilledButton(
                        onPressed: _meetup.loading ? null : _meetup.open,
                        child: Text(l10n.meetupStartNew),
                      ),
                    ] else
                      ..._planning(context, session),
                  ],
                ),
              ),
      );
    },
  );

  List<Widget> _planning(BuildContext context, MeetupSession session) {
    final l10n = context.l10n;
    final enabled = session.canManage && !_meetup.loading;
    final guests = session.standaloneParticipants.where(
      (person) => !person.isOwner,
    );
    final owner = session.standaloneParticipants
        .where((person) => person.isOwner)
        .firstOrNull;
    final atLimit = guests.length >= session.manualParticipantLimit;
    Widget row(StandaloneParticipant participant) {
      final point = _point(participant);
      return ManualParticipantCard(
        key: ValueKey(participant.id),
        participant: participant,
        onFocus: point == null ? null : () => _map.focus(point, zoom: 14),
        onEdit: !enabled || participant.isOwner
            ? null
            : () => _edit(participant),
        onRemove: !enabled || participant.isOwner
            ? null
            : () => _remove(participant),
      );
    }

    return [
      SizedBox(
        height: 270,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.radiusMd),
          child: YallaMapView(controller: _map, personalLocations: _markers),
        ),
      ),
      if (_meetup.failure case final failure?)
        ListTile(
          title: Text(FailureMessageMapper.localize(failure, l10n)),
          trailing: TextButton(
            onPressed: _meetup.reload,
            child: Text(l10n.retry),
          ),
        ),
      StartingLocationEditor(
        scope: (context: StartingLocationContext.meetup, id: session.id),
        inputVersion: session.inputVersion,
        onChanged: _meetup.reload,
      ),
      if (owner != null) row(owner),
      if (owner?.latitude == null) ...[
        OutlinedButton(
          onPressed: () => _setup(() => const MyLocationsPage()),
          child: Text(l10n.myLocations),
        ),
        OutlinedButton(
          onPressed: () => _setup(() => const LocationPrivacyPage()),
          child: Text(l10n.locationPrivacyTitle),
        ),
      ],
      const Divider(),
      Text(l10n.meetupGuests, style: context.texts.titleLarge),
      Text(l10n.meetupApproximateHint, style: context.texts.bodyMedium),
      for (final guest in guests) row(guest),
      FilledButton.icon(
        onPressed: enabled && !atLimit ? () => _edit() : null,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.meetupAddGuest),
      ),
      if (atLimit) Text(l10n.meetupGuestLimit(session.manualParticipantLimit)),
      const Divider(),
      MeetupPreferencesSummary(session: session, provider: _meetup),
      FilledButton.icon(
        onPressed: _meetup.loading ? null : () => _openResults(session),
        icon: const Icon(Icons.place_outlined),
        label: Text(l10n.meetupViewResults),
      ),
      TextButton(
        onPressed: enabled ? _cancel : null,
        child: Text(l10n.meetupCancel),
      ),
    ];
  }
}

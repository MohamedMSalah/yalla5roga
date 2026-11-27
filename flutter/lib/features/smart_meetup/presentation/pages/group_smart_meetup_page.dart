import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/starting_location_editor.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/realtime_route.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/location_privacy/presentation/pages/location_privacy_page.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/pages/my_locations_page.dart';

import '../../domain/entities/meetup_result_handoff_model.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/repositories/smart_meetup_repository.dart';
import '../../domain/smart_meetup_realtime.dart';
import '../providers/smart_meetup_provider.dart';
import '../widgets/meetup_preferences_summary.dart';
import '../widgets/meetup_widgets.dart';
import '../widgets/request_location_button.dart';
import '../widgets/smart_meetup_realtime_route.dart';
import 'smart_meetup_results_page.dart';

class GroupSmartMeetupPage extends StatefulWidget {
  const GroupSmartMeetupPage({
    super.key,
    required this.groupId,
    this.selectionLimit,
  });
  final String groupId;
  final int? selectionLimit;

  @override
  State<GroupSmartMeetupPage> createState() => _GroupSmartMeetupPageState();
}

class _GroupSmartMeetupPageState extends State<GroupSmartMeetupPage>
    with
        RealtimeRoute<GroupSmartMeetupPage>,
        WidgetsBindingObserver,
        SmartMeetupRealtimeRoute<GroupSmartMeetupPage> {
  late final AuthProvider _auth;
  late final AppSyncProvider _sync;
  late final SmartMeetupProvider _meetup;
  late SyncStatus _syncStatus;

  @override
  String get realtimeGroupId => widget.groupId;

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
        groupId: widget.groupId,
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
    _meetup = SmartMeetupProvider(
      context.read<SmartMeetupRepository>(),
      widget.groupId,
      _auth.user?.id,
      realtime: context.read<SmartMeetupRealtime>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_meetup.open());
    });
  }

  @override
  void setMeetupRouteActive(bool active) => _meetup.setActive(active);

  void _accountChanged() {
    _meetup.accountChanged(_auth.isAuthenticated ? _auth.user?.id : null);
  }

  void _syncChanged() {
    final previous = _syncStatus;
    _syncStatus = _sync.status;
    if (previous == SyncStatus.offline && _syncStatus != SyncStatus.offline) {
      _meetup.requestReload();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_accountChanged);
    _sync.removeListener(_syncChanged);
    _meetup.dispose();
    super.dispose();
  }

  Future<void> _copySetupRequest() async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: l10n.meetupSetupRequest));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.meetupRequestCopied)));
    }
  }

  Future<void> _confirmCancel() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.meetupCancel),
        content: Text(l10n.meetupCancelConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.meetupCancel),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _meetup.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _meetup,
      builder: (context, _) {
        final l10n = context.l10n;
        final session = _meetup.session;
        final failure = _meetup.failure;
        final readiness = session?.readiness;
        return GroupPageBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: GroupPageAppBar(title: l10n.smartMeetup),
            body:
                (session == null || !_meetup.snapshotIsCurrent) &&
                    failure != null
                ? AppErrorState(
                    message: FailureMessageMapper.localize(failure, l10n),
                    onRetry: _meetup.reload,
                  )
                : RefreshIndicator(
                    onRefresh: _meetup.reload,
                    child: GroupPageList(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (session == null ||
                            !_meetup.snapshotIsCurrent ||
                            (readiness == null &&
                                session.status == MeetupSessionStatus.active))
                          const MeetupSkeleton()
                        else if (readiness == null) ...[
                          Text(
                            session.status == MeetupSessionStatus.expired
                                ? l10n.meetupExpired
                                : l10n.meetupCancelled,
                          ),
                          FilledButton(
                            onPressed: _meetup.loading ? null : _meetup.open,
                            child: Text(l10n.meetupStartNew),
                          ),
                        ] else ...[
                          if (failure != null)
                            ListTile(
                              title: Text(
                                FailureMessageMapper.localize(failure, l10n),
                              ),
                              trailing: TextButton(
                                onPressed: _meetup.reload,
                                child: Text(l10n.retry),
                              ),
                            ),
                          MeetupReadinessHeader(summary: readiness),
                          StartingLocationEditor(
                            scope: (
                              context: StartingLocationContext.meetup,
                              id: session.id,
                            ),
                            inputVersion: session.inputVersion,
                            onChanged: _meetup.reload,
                          ),
                          MeetupPreferencesSummary(
                            session: session,
                            provider: _meetup,
                          ),
                          FilledButton.icon(
                            onPressed: _meetup.loading
                                ? null
                                : () => _openResults(session),
                            icon: const Icon(Icons.place_outlined),
                            label: Text(l10n.meetupViewResults),
                          ),
                          if (readiness.requiringSetup > 0)
                            MissingLocationsBanner(
                              count: readiness.requiringSetup,
                              onRequestSetup: _copySetupRequest,
                            ),
                          Text(
                            l10n.meetupMembers,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (final member in readiness.participants)
                            MemberReadinessTile(
                              key: member.requestTargetUserId == null
                                  ? null
                                  : ValueKey(member.requestTargetUserId),
                              member: member,
                              requestAction: switch (member
                                  .requestTargetUserId) {
                                final String target => RequestLocationButton(
                                  key: ValueKey((
                                    _auth.user?.id,
                                    session.id,
                                    target,
                                  )),
                                  sessionId: session.id,
                                  targetUserId: target,
                                  memberName: member.name,
                                ),
                                null => null,
                              },
                            ),
                          if (readiness.participants.any(
                            (member) => member.isSelf && !member.ready,
                          )) ...[
                            OutlinedButton(
                              onPressed: () =>
                                  Get.to(() => const MyLocationsPage()),
                              child: Text(l10n.myLocations),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  Get.to(() => const LocationPrivacyPage()),
                              child: Text(l10n.locationPrivacyTitle),
                            ),
                          ],
                          if (session.canManage)
                            TextButton(
                              onPressed: _meetup.loading
                                  ? null
                                  : _confirmCancel,
                              child: Text(l10n.meetupCancel),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

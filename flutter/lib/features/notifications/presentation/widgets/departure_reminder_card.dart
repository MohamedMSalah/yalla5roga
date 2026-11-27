import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/providers/saved_locations_provider.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/starting_location_editor.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_chip.dart';

import '../../domain/repositories/location_travel_notification_repository.dart';
import '../pages/departure_reminder_settings_page.dart';

class OutingDepartureReminderSection extends StatelessWidget {
  const OutingDepartureReminderSection({
    super.key,
    required this.outingId,
    required this.revision,
  });

  final String outingId;
  final Object revision;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.isAuthenticated ? auth.user?.id : null;
    final saved = context.read<SavedLocationsProvider>();
    final generation = context.select((SavedLocationsProvider p) => p.session);
    if (userId == null) return const SizedBox.shrink();
    final rsvp = context.select(
      (OutingsProvider store) => (
        store.attendanceMapFor(outingId)[userId],
        store.isSavingAttendance(outingId),
      ),
    );
    return _AccountDepartureReminderSection(
      key: ValueKey((userId, generation, outingId)),
      outingId: outingId,
      account: userId,
      current: () =>
          auth.isAuthenticated &&
          auth.user?.id == userId &&
          saved.matchesSession(generation),
      revision: (revision, rsvp.$1),
      savingRsvp: rsvp.$2,
    );
  }
}

class _AccountDepartureReminderSection extends StatefulWidget {
  const _AccountDepartureReminderSection({
    super.key,
    required this.outingId,
    required this.account,
    required this.current,
    required this.revision,
    required this.savingRsvp,
  });

  final String outingId;
  final String account;
  final bool Function() current;
  final Object revision;
  final bool savingRsvp;

  @override
  State<_AccountDepartureReminderSection> createState() =>
      _AccountDepartureReminderSectionState();
}

class _AccountDepartureReminderSectionState
    extends State<_AccountDepartureReminderSection> {
  DepartureReminder? _value;
  Failure? _failure;
  bool _busy = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _refreshAfterBuild();
  }

  @override
  void didUpdateWidget(covariant _AccountDepartureReminderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.savingRsvp &&
        (widget.revision != oldWidget.revision || oldWidget.savingRsvp)) {
      _refreshAfterBuild();
    }
  }

  void _refreshAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load({bool schedule = false, bool clear = false}) async {
    if (!mounted || !widget.current()) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final repo = context.read<LocationTravelNotificationRepository>();
    if (clear) {
      final result = await repo.clearDepartureReminder(
        widget.account,
        widget.outingId,
      );
      if (!mounted || !widget.current() || request != _request) return;
      final failure = result.fold<Failure?>((failure) => failure, (_) => null);
      if (failure != null) {
        setState(() {
          _failure = failure;
          _busy = false;
        });
        return;
      }
    }
    final result = await repo.departureReminder(
      widget.account,
      widget.outingId,
      schedule: schedule,
    );
    if (!mounted || !widget.current() || request != _request) return;
    setState(() {
      result.fold((failure) => _failure = failure, (value) => _value = value);
      _busy = false;
    });
  }

  Future<void> _settings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DepartureReminderSettingsPage()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StartingLocationEditor(
        scope: (context: StartingLocationContext.outing, id: widget.outingId),
        onChanged: _load,
      ),
      DepartureReminderCard(
        value: _value,
        busy: _busy || widget.savingRsvp,
        failure: _failure,
        onSettings: _settings,
        onRetry: _load,
        onSchedule: () => _load(schedule: true),
        onClear: () => _load(clear: true),
      ),
    ],
  );
}

class DepartureReminderCard extends StatelessWidget {
  const DepartureReminderCard({
    super.key,
    required this.value,
    required this.busy,
    required this.failure,
    required this.onSettings,
    required this.onRetry,
    required this.onSchedule,
    required this.onClear,
  });

  final DepartureReminder? value;
  final bool busy;
  final Failure? failure;
  final VoidCallback onSettings;
  final VoidCallback onRetry;
  final VoidCallback onSchedule;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reminder = value;
    final error = failure;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(l10n.departureReminders, style: context.texts.titleMedium),
            if (busy) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(FailureMessageMapper.localize(error, l10n)),
              TextButton(
                onPressed: busy ? null : onRetry,
                child: Text(l10n.retry),
              ),
            ] else if (reminder != null) ...[
              Text(
                reminder.preferences.enabled
                    ? l10n.departurePreferenceEnabled(
                        reminder.preferences.bufferMinutes,
                      )
                    : l10n.departurePreferenceDisabled,
              ),
              Text(
                '${l10n.meetupStartingPoint} · ${_location(context, reminder)}',
              ),
              Text(
                '${l10n.transportationTitle} · ${TransportationModeChip.label(l10n, reminder.mode)}',
              ),
              if (reminder.journeySeconds case final seconds?)
                Text(
                  '${l10n.departureJourney} · ${l10n.departureMinutes((seconds / 60).ceil())}',
                ),
              if (reminder.departureAt case final departure?)
                Text(
                  '${l10n.departureSuggested} · ${l10n.formatDate(departure.toLocal())} · ${l10n.formatTime(departure.toLocal())}',
                ),
              if (reminder.status == 'SCHEDULED')
                Text(l10n.departureScheduled)
              else if (reminder.status != 'AVAILABLE')
                DepartureReminderUnavailableState(status: reminder.status),
            ],
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onSettings, child: Text(l10n.settings)),
                if (error == null && reminder?.status == 'AVAILABLE')
                  TextButton(
                    onPressed: busy ? null : onSchedule,
                    child: Text(l10n.departureSchedule),
                  ),
                if (error == null && reminder?.status == 'SCHEDULED')
                  TextButton(
                    onPressed: busy ? null : onClear,
                    child: Text(l10n.departureClear),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _location(BuildContext context, DepartureReminder reminder) {
    final l10n = context.l10n;
    if (!reminder.hasLocation) return l10n.startingLocationSetupRequired;
    return (l10n.locale.languageCode == 'ar'
            ? reminder.arabicLocationName
            : null) ??
        reminder.locationName ??
        l10n.startingPointSelected;
  }
}

class DepartureReminderUnavailableState extends StatelessWidget {
  const DepartureReminderUnavailableState({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(switch (status) {
      'RSVP_REQUIRED' => l10n.departureRsvpRequired,
      'OPT_IN_REQUIRED' => l10n.departurePreferenceHint,
      'NOTIFICATIONS_DISABLED' => l10n.departureNotificationsDisabled,
      'STARTING_LOCATION_REQUIRED' => l10n.startingContextConsentRequired,
      'TRANSPORTATION_MODE_REQUIRED' => l10n.departureTransportationRequired,
      'ROUTING_UNAVAILABLE' => l10n.departureRoutingUnavailable,
      'DEPARTURE_PASSED' => l10n.departureTimePassed,
      'ALREADY_SENT' => l10n.departureAlreadySent,
      _ => l10n.departureUnavailable,
    });
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/location_travel_notification_repository.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/providers/saved_locations_provider.dart';

class RequestLocationButton extends StatefulWidget {
  const RequestLocationButton({
    super.key,
    required this.sessionId,
    required this.targetUserId,
    required this.memberName,
  });

  final String sessionId;
  final String targetUserId;
  final String memberName;

  @override
  State<RequestLocationButton> createState() => _RequestLocationButtonState();
}

class _RequestLocationButtonState extends State<RequestLocationButton> {
  bool _busy = false;
  LocationRequestResult? _result;
  Timer? _cooldown;

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    final account = auth.user?.id;
    if (!auth.isAuthenticated || account == null) return;
    final saved = context.read<SavedLocationsProvider>();
    final repository = context.read<LocationTravelNotificationRepository>();
    final l10n = context.l10n;
    final generation = saved.session;
    bool isCurrent() =>
        mounted &&
        auth.isAuthenticated &&
        auth.user?.id == account &&
        saved.matchesSession(generation);
    setState(() => _busy = true);
    try {
      if (!await RequestLocationConfirmationDialog.show(
            context,
            widget.memberName,
          ) ||
          !isCurrent()) {
        return;
      }
      final result = await repository.requestLocation(
        account,
        widget.sessionId,
        widget.targetUserId,
      );
      if (!isCurrent()) return;
      result.fold(
        (failure) =>
            AppSnackBar.showError(FailureMessageMapper.localize(failure, l10n)),
        (value) {
          setState(() => _result = value);
          if (value.retryAt case final retry?) {
            final wait = retry.difference(DateTime.now());
            _cooldown?.cancel();
            _cooldown = Timer(wait, () {
              if (isCurrent()) setState(() => _result = null);
            });
          }
        },
      );
    } finally {
      if (isCurrent()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_result?.status) {
    LocationRequestStatus.requested => const RequestSentState(),
    LocationRequestStatus.cooldown => LocationRequestCooldownState(
      retryAt: _result?.retryAt,
    ),
    LocationRequestStatus.unavailable => Text(
      context.l10n.locationRequestUnavailable,
    ),
    null => OutlinedButton(
      onPressed: _busy ? null : _request,
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(context.l10n.requestLocation),
    ),
  };
}

abstract final class RequestLocationConfirmationDialog {
  static Future<bool> show(BuildContext context, String memberName) {
    final l10n = context.l10n;
    return AppAlert.confirm(
      title: l10n.requestLocation,
      message: l10n.confirmLocationRequest(memberName),
      confirmText: l10n.requestLocation,
      cancelText: l10n.cancel,
    );
  }
}

class RequestSentState extends StatelessWidget {
  const RequestSentState({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(context.l10n.locationRequestSent),
  );
}

class LocationRequestCooldownState extends StatelessWidget {
  const LocationRequestCooldownState({super.key, required this.retryAt});

  final DateTime? retryAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final local = retryAt?.toLocal();
    return Semantics(
      liveRegion: true,
      child: Text(
        local == null
            ? l10n.locationRequestUnavailable
            : l10n.locationRequestRetryAt(
                '${l10n.formatDate(local)} · ${l10n.formatTime(local)}',
              ),
      ),
    );
  }
}

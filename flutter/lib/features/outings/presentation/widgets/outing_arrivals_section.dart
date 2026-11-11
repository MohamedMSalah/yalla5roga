import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_arrival.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outing_arrival_service.dart';

class OutingArrivalsSection extends StatefulWidget {
  const OutingArrivalsSection({
    super.key,
    required this.outing,
    required this.userId,
  });

  final Outing outing;
  final String userId;

  @override
  State<OutingArrivalsSection> createState() => _OutingArrivalsSectionState();
}

class _OutingArrivalsSectionState extends State<OutingArrivalsSection>
    with WidgetsBindingObserver {
  late final OutingArrivalService _service;
  late final StreamSubscription<String> _arrivalSubscription;
  late final StreamSubscription<bool> _connectionSubscription;
  Timer? _verificationTimer;
  Timer? _refreshTimer;
  OutingArrivalRoster? _roster;
  var _verification = ArrivalVerification.unverified;
  var _routeIsCurrent = false;
  var _foreground = true;
  var _loading = false;
  var _failed = false;
  var _refreshAgain = false;
  var _checking = false;
  var _permissionRequested = false;
  var _generation = 0;
  DateTime? _lastAttempt;

  bool get _active => mounted && _routeIsCurrent && _foreground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _service = context.read<OutingArrivalService>();
    _arrivalSubscription = _service.arrivalChanges.listen((id) {
      if (id == widget.outing.id) _queueRefresh();
    });
    _connectionSubscription = _service.connectionChanges.listen((connected) {
      if (connected) _queueRefresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current == _routeIsCurrent) return;
    _routeIsCurrent = current;
    _onVisibilityChanged();
  }

  @override
  void didUpdateWidget(covariant OutingArrivalsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.outing.status != oldWidget.outing.status ||
        widget.outing.scheduledAt != oldWidget.outing.scheduledAt ||
        widget.outing.endsAt != oldWidget.outing.endsAt) {
      _verificationTimer?.cancel();
      _generation++;
      _queueRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _onVisibilityChanged();
  }

  void _onVisibilityChanged() {
    _generation++;
    _verificationTimer?.cancel();
    _refreshTimer?.cancel();
    if (!_active) return;
    _lastAttempt = null;
    _queueRefresh();
    unawaited(_service.connect().catchError((Object _) {}));
  }

  void _queueRefresh() {
    if (!_active) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 120), _refresh);
  }

  Future<void> _refresh() async {
    if (!_active) return;
    if (_loading) {
      _refreshAgain = true;
      return;
    }
    _loading = true;
    final generation = _generation;
    try {
      final roster = await _service.list(widget.outing.id);
      if (!_active || generation != _generation) return;
      setState(() {
        _roster = roster;
        _failed = false;
      });
      _scheduleVerification(roster, immediate: true);
    } catch (_) {
      if (_active && generation == _generation) setState(() => _failed = true);
    } finally {
      _loading = false;
      if (_refreshAgain) {
        _refreshAgain = false;
        _queueRefresh();
      }
    }
  }

  void _scheduleVerification(
    OutingArrivalRoster roster, {
    required bool immediate,
  }) {
    _verificationTimer?.cancel();
    if (!_active ||
        widget.outing.status != OutingStatus.confirmed ||
        roster.venue == null ||
        _verification == ArrivalVerification.arrived ||
        roster.arrivals.any((arrival) => arrival.userId == widget.userId)) {
      return;
    }
    final now = DateTime.now();
    final end = roster.closesAt;
    final start = roster.opensAt;
    if (start == null || end == null || !now.isBefore(end)) return;
    if (now.isBefore(start)) {
      _verificationTimer = Timer(start.difference(now), _refresh);
      return;
    }
    if (!roster.open) return;
    const interval = Duration(minutes: 1);
    final lastAttempt = _lastAttempt;
    final remaining = lastAttempt?.add(interval).difference(now);
    final delay = remaining != null && !remaining.isNegative
        ? remaining
        : immediate
        ? Duration.zero
        : interval;
    if (now.add(delay).isBefore(end)) {
      _verificationTimer = Timer(delay, () => _verify(roster));
    }
  }

  Future<void> _verify(OutingArrivalRoster roster) async {
    if (!_active || _checking) return;
    final end = roster.closesAt;
    if (end == null) return;
    final generation = _generation;
    bool isActive() =>
        _active && generation == _generation && DateTime.now().isBefore(end);
    if (!isActive()) return;
    _lastAttempt = DateTime.now();
    _checking = true;
    try {
      final result = await _service.verify(
        widget.outing.id,
        roster,
        isActive: isActive,
        shouldRequestPermission: () {
          if (_permissionRequested) return false;
          _permissionRequested = true;
          return true;
        },
      );
      if (!isActive()) return;
      setState(() => _verification = result);
      if (result == ArrivalVerification.arrived) _queueRefresh();
    } catch (_) {
      if (isActive()) setState(() => _failed = true);
    } finally {
      _checking = false;
      final latest = _roster;
      if (_active && latest != null) {
        _scheduleVerification(latest, immediate: generation != _generation);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_arrivalSubscription.cancel());
    unawaited(_connectionSubscription.cancel());
    _verificationTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(top: Responsive.spaceLg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.whoArrived),
            Responsive.spaceSm.gapH,
            if (_failed)
              TextButton(
                onPressed: _refresh,
                child: Text(l10n.arrivalsLoadFailed),
              )
            else if (roster == null)
              const LinearProgressIndicator(),
            if (roster != null) ...[
              if (roster.venue != null &&
                  widget.outing.status == OutingStatus.confirmed)
                Text(l10n.automaticArrivalHint, style: context.texts.bodySmall)
              else if (widget.outing.status != OutingStatus.past)
                Text(l10n.arrivalNeedsVenue, style: context.texts.bodySmall),
              Text(l10n.confirmedArrivals(roster.arrivals.length)),
              for (final arrival in roster.arrivals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(arrival.name),
                  subtitle: Text(
                    '${l10n.arrivalVerified} · ${l10n.formatTime(arrival.arrivedAt)}',
                  ),
                ),
              for (final person in roster.unconfirmed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(person.name),
                  subtitle: Text(
                    person.id == widget.userId &&
                            _verification == ArrivalVerification.unavailable
                        ? l10n.arrivalLocationUnavailable
                        : l10n.arrivalUnconfirmed,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

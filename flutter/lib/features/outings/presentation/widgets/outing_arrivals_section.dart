import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/widgets/loading_indicator.dart';
import 'package:yalla_5roga/core/widgets/participant_avatar_stack.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

import 'outing_info_style.dart';

import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
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
  late final AuthProvider? _auth;
  StreamSubscription<String>? _arrivalSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _verificationTimer;
  Timer? _refreshTimer;
  Timer? _startTimer;
  Timer? _closeTimer;
  OutingArrivalRoster? _roster;
  var _verification = ArrivalVerification.unverified;
  var _routeIsCurrent = false;
  var _foreground = true;
  var _loading = false;
  var _failed = false;
  var _refreshAgain = false;
  var _checking = false;
  var _submitting = false;
  var _checkInFailed = false;
  var _showRoster = false;
  var _permissionRequested = false;
  var _generation = 0;
  DateTime? _lastAttempt;

  bool get _active =>
      mounted &&
      _routeIsCurrent &&
      _foreground &&
      (_auth == null || _auth.user?.id == widget.userId);
  bool get _canLoadRoster => switch (widget.outing.status) {
    OutingStatus.confirmed ||
    OutingStatus.past ||
    OutingStatus.cancelled => true,
    _ => false,
  };

  bool _canVerify(OutingArrivalRoster roster) {
    final now = DateTime.now();
    final opens = roster.opensAt;
    final closes = roster.closesAt;
    return _active &&
        _hasStarted &&
        widget.outing.status == OutingStatus.confirmed &&
        roster.venue != null &&
        roster.open &&
        opens != null &&
        closes != null &&
        !now.isBefore(opens) &&
        now.isBefore(closes) &&
        _verification != ArrivalVerification.arrived &&
        roster.unconfirmed.any((person) => person.id == widget.userId) &&
        !roster.arrivals.any((person) => person.userId == widget.userId);
  }

  bool get _hasStarted {
    final start = widget.outing.scheduledAt;
    return start != null && !DateTime.now().isBefore(start);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _service = context.read<OutingArrivalService>();
    _auth = context.read<AuthProvider?>();
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
    if (widget.outing.id != oldWidget.outing.id ||
        widget.userId != oldWidget.userId ||
        widget.outing.status != oldWidget.outing.status ||
        widget.outing.scheduledAt != oldWidget.outing.scheduledAt ||
        widget.outing.endsAt != oldWidget.outing.endsAt ||
        widget.outing.location?.latitude !=
            oldWidget.outing.location?.latitude ||
        widget.outing.location?.longitude !=
            oldWidget.outing.location?.longitude) {
      _roster = null;
      _checkInFailed = false;
      _verification = ArrivalVerification.unverified;
      _failed = false;
      _onVisibilityChanged();
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
    _startTimer?.cancel();
    _closeTimer?.cancel();
    if (!_active || !_hasStarted || !_canLoadRoster) {
      _releaseRealtime();
    }
    if (!_active || !_canLoadRoster) return;
    _lastAttempt = null;
    if (!_hasStarted) {
      final start = widget.outing.scheduledAt;
      if (start != null && widget.outing.status != OutingStatus.cancelled) {
        final delay = start.difference(DateTime.now());
        _startTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
          if (!_active) return;
          setState(() {});
          _onVisibilityChanged();
        });
      }
      return;
    }
    _arrivalSubscription ??= _service.arrivalChanges.listen((id) {
      if (id == widget.outing.id) _queueRefresh();
    });
    _connectionSubscription ??= _service.connectionChanges.listen((connected) {
      if (connected) _queueRefresh();
    });
    _service.retainRealtime(this);
    _queueRefresh();
  }

  void _releaseRealtime() {
    unawaited(_arrivalSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    _arrivalSubscription = null;
    _connectionSubscription = null;
    _service.releaseRealtime(this);
  }

  void _queueRefresh() {
    if (!_active || !_hasStarted || !_canLoadRoster) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 120), _refresh);
  }

  Future<void> _refresh() async {
    if (!_active || !_hasStarted || !_canLoadRoster) return;
    if (_loading) {
      _refreshAgain = true;
      return;
    }
    _loading = true;
    final generation = _generation;
    try {
      final roster = await _service.list(widget.outing.id);
      if (!_active || !_hasStarted || generation != _generation) return;
      setState(() {
        _roster = roster;
        _failed = false;
      });
      _closeTimer?.cancel();
      if (roster.closesAt case final end?) {
        final remaining = end.difference(DateTime.now());
        if (!remaining.isNegative) {
          _closeTimer = Timer(remaining, () {
            if (_active) setState(() {});
          });
        }
      }
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
        !_hasStarted ||
        widget.outing.status != OutingStatus.confirmed ||
        roster.venue == null ||
        _verification == ArrivalVerification.arrived ||
        !roster.unconfirmed.any((person) => person.id == widget.userId) ||
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
    if (!_canVerify(roster) || _checking) return;
    final end = roster.closesAt;
    if (end == null) return;
    final generation = _generation;
    bool isActive() =>
        _active &&
        _hasStarted &&
        generation == _generation &&
        DateTime.now().isBefore(end);
    if (!isActive()) return;
    _lastAttempt = DateTime.now();
    setState(() {
      _checking = true;
      _checkInFailed = false;
    });
    try {
      final result = await _service.verify(
        widget.outing.id,
        roster,
        isActive: isActive,
        onSubmitting: () {
          if (isActive()) setState(() => _submitting = true);
        },
        shouldRequestPermission: () {
          if (_permissionRequested) return false;
          _permissionRequested = true;
          return true;
        },
      );
      if (!isActive()) return;
      setState(() {
        _verification = result;
        _failed = false;
      });
      if (result == ArrivalVerification.arrived) _queueRefresh();
    } catch (_) {
      if (isActive()) setState(() => _checkInFailed = true);
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _submitting = false;
        });
      }
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
    _releaseRealtime();
    _verificationTimer?.cancel();
    _refreshTimer?.cancel();
    _startTimer?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final l10n = context.l10n;
    final style = OutingInfoStyle(context);
    final verified =
        _verification == ArrivalVerification.arrived ||
        (roster?.arrivals.any((arrival) => arrival.userId == widget.userId) ??
            false);
    final available = roster != null && _canVerify(roster);
    final subtitle = !_canLoadRoster
        ? l10n.arrivalNeedsVenue
        : !_hasStarted &&
              widget.outing.scheduledAt != null &&
              widget.outing.status == OutingStatus.confirmed
        ? l10n.arrivalStartsAtOutingTime
        : _checking
        ? (_submitting ? l10n.outingArrivalSubmitting : l10n.checkingArrival)
        : verified
        ? l10n.arrivalVerified
        : _failed
        ? l10n.arrivalsLoadFailed
        : _checkInFailed
        ? l10n.outingArrivalSubmitFailed
        : switch (_verification) {
            ArrivalVerification.permissionDenied =>
              l10n.arrivalPermissionDenied,
            ArrivalVerification.outsideRadius => l10n.arrivalOutsideRadius,
            ArrivalVerification.unavailable => l10n.arrivalLocationUnavailable,
            _ =>
              available
                  ? l10n.outingArrivalPrompt
                  : roster != null && !roster.open
                  ? l10n.arrivalWindowClosed
                  : l10n.outingArrivalUnavailable,
          };
    final arrived = {
      for (final item in roster?.arrivals ?? const <OutingArrival>[])
        item.userId,
    };
    final ids = {
      ...arrived,
      for (final item in roster?.unconfirmed ?? const []) item.id,
    };
    final previews = ids.take(3).toList();
    final urls = context.select((OutingsProvider? store) {
      if (previews.isEmpty) return const <String>[];
      final members = {
        for (final member
            in store?.membersForOuting(widget.outing) ?? const <GroupMember>[])
          member.id: member.avatar,
      };
      return <String>[for (final id in previews) members[id] ?? ''];
    });

    return OutingInfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, limits) {
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.whoArrived,
                      style: style.type(18, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: style.type(12, color: style.secondary)),
                ],
              );
              final button = FilledButton.icon(
                onPressed: !available || _checking
                    ? null
                    : () {
                        _verificationTimer?.cancel();
                        _permissionRequested = false;
                        _verify(roster);
                      },
                icon: _checking
                    ? LoadingIndicator(
                        size: 15,
                        strokeWidth: 2,
                        color: style.icon,
                      )
                    : Icon(
                        verified ? Icons.check : Icons.place_outlined,
                        size: 17,
                      ),
                label: Text(verified ? l10n.arrivalVerified : l10n.checkIn),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF662DB6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(48, 34),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  textStyle: style.type(12, weight: FontWeight.w600),
                ),
              );
              if (limits.maxWidth < 255 ||
                  MediaQuery.textScalerOf(context).scale(13) > 19) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, button],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 8),
                  button,
                ],
              );
            },
          ),
          if (_failed)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _loading ? null : _refresh,
                child: Text(l10n.tryAgain),
              ),
            ),
          if (available &&
              _verification == ArrivalVerification.permissionDenied)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () async {
                  final permission = await AppPermissions.ensureLocation(l10n);
                  if (mounted && permission == AppPermissionResult.granted) {
                    _queueRefresh();
                  }
                },
                child: Text(l10n.outingArrivalLocationSettings),
              ),
            ),
          if (roster != null) ...[
            const SizedBox(height: 5),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: ids.isEmpty
                    ? null
                    : () => setState(() => _showRoster = !_showRoster),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      if (urls.isNotEmpty) ...[
                        ParticipantAvatarStack(
                          urls: urls,
                          extra: 0,
                          size: 32,
                          ring: style.border,
                          counterFill: style.control,
                          counterText: style.icon,
                          fallbackFill: const Color(0xFF4B2685),
                          verifiedIndexes: {
                            for (var i = 0; i < previews.length; i++)
                              if (arrived.contains(previews[i])) i,
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          l10n.outingArrivalRatio(arrived.length, ids.length),
                          style: style.type(
                            13,
                            color: style.secondary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (ids.isNotEmpty)
                        Icon(
                          _showRoster ? Icons.expand_less : Icons.expand_more,
                          color: style.icon,
                          size: 19,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showRoster) ...[
              for (final arrival in roster.arrivals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: style.success,
                  ),
                  title: Text(arrival.name),
                  subtitle: Text(
                    '${l10n.arrivalVerified} · ${l10n.formatTime(arrival.arrivedAt)}',
                  ),
                ),
              for (final person in roster.unconfirmed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline, color: style.icon),
                  title: Text(person.name),
                  subtitle: Text(l10n.arrivalUnconfirmed),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

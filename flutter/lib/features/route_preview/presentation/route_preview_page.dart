import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/maps/personal_route_map_layer.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/providers/saved_locations_provider.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/starting_location_editor.dart';

import '../domain/route_preview_entity.dart';
import '../domain/route_preview_repository.dart';
import 'route_preview_provider.dart';
import 'route_preview_widgets.dart';

class RoutePreviewPage extends StatefulWidget {
  const RoutePreviewPage({super.key, required this.target});

  final RoutePreviewTarget target;

  @override
  State<RoutePreviewPage> createState() => _RoutePreviewPageState();
}

class _RoutePreviewPageState extends State<RoutePreviewPage> {
  late final String? _openingAccount = context.read<AuthProvider>().user?.id;
  late final int _openingSession = context
      .read<SavedLocationsProvider>()
      .session;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final account = context.select(
      (AuthProvider auth) => auth.isAuthenticated ? auth.user?.id : null,
    );
    final saved = context.read<SavedLocationsProvider>();
    final session = context.select((SavedLocationsProvider p) => p.session);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.routePreviewTitle)),
      body:
          account == null ||
              account != _openingAccount ||
              session != _openingSession
          ? Center(child: Text(context.l10n.errorSessionExpired))
          : ChangeNotifierProvider(
              key: ValueKey((account, session, widget.target)),
              create: (_) => RoutePreviewProvider(
                context.read<RoutePreviewRepository>(),
                account,
                widget.target,
                () =>
                    auth.isAuthenticated &&
                    auth.user?.id == account &&
                    saved.matchesSession(session),
              ),
              child: _RoutePreviewContent(target: widget.target),
            ),
    );
  }
}

class _RoutePreviewContent extends StatefulWidget {
  const _RoutePreviewContent({required this.target});

  final RoutePreviewTarget target;

  @override
  State<_RoutePreviewContent> createState() => _RoutePreviewContentState();
}

class _RoutePreviewContentState extends State<_RoutePreviewContent>
    with WidgetsBindingObserver {
  late final AppSyncProvider _sync;
  late final RoutePreviewProvider _provider;
  late SyncStatus _status;

  @override
  void initState() {
    super.initState();
    _provider = context.read<RoutePreviewProvider>();
    _sync = context.read<AppSyncProvider>()..addListener(_syncChanged);
    _status = _sync.status;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_provider.load());
    });
  }

  void _syncChanged() {
    final old = _status;
    _status = _sync.status;
    if (_status != old &&
        (_status == SyncStatus.offline ||
            (_status == SyncStatus.idle &&
                (old == SyncStatus.offline ||
                    old == SyncStatus.reconnecting)))) {
      unawaited(_provider.load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_provider.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync.removeListener(_syncChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutePreviewProvider>();
    final l = context.l10n;
    final preview = provider.value;
    final error = provider.failure;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (provider.loading)
                LinearProgressIndicator(semanticsLabel: l.routePreviewTitle)
              else if (preview == null) ...[
                Text(
                  error == null
                      ? l.routePreviewUnavailable
                      : FailureMessageMapper.localize(error, l),
                ),
                if (widget.target.recommendation != null &&
                    error?.statusCode == 409)
                  Text(l.routePreviewRefreshMeetup)
                else
                  TextButton(onPressed: provider.load, child: Text(l.retry)),
              ],
              if (preview != null) ...[
                LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    height: (constraints.maxWidth * .65).clamp(200.0, 340.0),
                    child: _RouteMap(
                      preview: preview,
                      selected: provider.selected,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (preview.status != RoutePreviewStatus.available)
                  RouteUnavailableWidget(status: preview.status),
                RouteAlternativeSelector(
                  preview: preview,
                  selected: provider.selected,
                  onSelected: provider.select,
                ),
                RouteInformationCard(
                  preview: preview,
                  selected: provider.selected,
                ),
                ExternalNavigationAction(destination: preview.destination),
              ],
              StartingLocationEditor(
                scope: widget.target.scope,
                inputVersion: preview?.inputVersion,
                actionOnly: true,
                onChanged: provider.load,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.preview, required this.selected});

  final RoutePreviewEntity preview;
  final int selected;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final _map = YallaMapController();
  late PersonalRouteOverlay _overlay;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(covariant _RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview != widget.preview ||
        oldWidget.selected != widget.selected) {
      _update();
    }
  }

  void _update() {
    final preview = widget.preview;
    final routes = preview.routes;
    final selected = routes.isEmpty ? null : routes[widget.selected];
    _overlay = (
      selected: selected?.points ?? const [],
      alternatives: [
        if (preview.capabilities?.supportsAlternatives == true)
          for (final route in routes)
            if (route != selected) route.points,
      ],
      origin: preview.origin?.point,
      destination: preview.destination.point,
    );
    final points = {
      _overlay.destination,
      ?_overlay.origin,
      ..._overlay.selected,
    }.toList();
    if (points.length == 1) {
      _map.focus(points.single, zoom: 14);
    } else {
      _map.fit(points, padding: const EdgeInsets.all(36));
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Responsive.radiusMd),
    child: YallaMapView(
      controller: _map,
      center: _overlay.destination,
      personalRoute: _overlay,
    ),
  );
}

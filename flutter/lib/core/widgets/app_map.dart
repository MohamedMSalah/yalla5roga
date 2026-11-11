import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

const cairoMapCenter = LatLng(30.0444, 31.2357);

class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.center,
    this.zoom = 12,
    this.markers = const [],
    this.onTap,
    this.onUserMove,
    this.onUserIdle,
    this.attributionInset,
    this.selectionBottom = 0,
    this.scrollWheelZoom = true,
    this.tileProvider,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onUserMove;
  final ValueChanged<LatLng>? onUserIdle;
  final ValueListenable<double>? attributionInset;
  final double selectionBottom;
  final bool scrollWheelZoom;
  final TileProvider? tileProvider;

  @override
  State<AppMap> createState() => AppMapState();
}

class AppMapState extends State<AppMap> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final TileProvider _tiles = widget.tileProvider ?? NetworkTileProvider();
  final _tileFailed = ValueNotifier(false);
  final _tileReload = StreamController<void>.broadcast();
  final _pointers = <int>{};
  late final AnimationController _cameraAnimation;
  Timer? _idle;
  bool _moving = false;
  bool _ready = false;
  VoidCallback? _onReady;
  late LatLng _from;
  late LatLng _to;
  late double _fromZoom;
  late double _toZoom;

  @override
  void initState() {
    super.initState();
    _cameraAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..addListener(_animate);
  }

  @override
  void didUpdateWidget(covariant AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.center != oldWidget.center || widget.zoom != oldWidget.zoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus(widget.center, zoom: widget.zoom);
      });
    }
  }

  LatLng get selectionPoint {
    if (!_ready) return widget.center;
    final camera = _map.camera;
    final size = camera.nonRotatedSize;
    return camera.screenOffsetToLatLng(
      Offset(size.width / 2, (size.height - widget.selectionBottom) / 2),
    );
  }

  void focusSelection(LatLng point, {double zoom = 16}) => _whenReady(() {
    final camera = _map.camera.withPosition(center: point, zoom: zoom);
    final size = camera.nonRotatedSize;
    _move(
      camera.screenOffsetToLatLng(
        Offset(size.width / 2, (size.height + widget.selectionBottom) / 2),
      ),
      zoom,
    );
  });

  void focus(LatLng point, {double zoom = 16}) =>
      _whenReady(() => _move(point, zoom));

  void fit(List<LatLng> points, {required EdgeInsets padding}) {
    if (points.isEmpty) return;
    _whenReady(() {
      final camera = _map.camera;
      if (points.every((point) => point == points.first) ||
          camera.nonRotatedSize.height <= padding.vertical + 40) {
        focusSelection(points.first, zoom: 15);
        return;
      }
      final target = CameraFit.coordinates(
        coordinates: points,
        padding: padding,
        maxZoom: 16,
      ).fit(camera);
      _move(target.center, target.zoom);
    });
  }

  void _whenReady(VoidCallback action) {
    if (_ready) {
      action();
    } else {
      _onReady = action;
    }
  }

  void _move(LatLng point, double zoom) {
    _idle?.cancel();
    _moving = false;
    _cameraAnimation.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _map.move(point, zoom);
      return;
    }
    _from = _map.camera.center;
    _fromZoom = _map.camera.zoom;
    _to = point;
    _toZoom = zoom;
    _cameraAnimation.forward(from: 0);
  }

  void _animate() {
    final t = Curves.easeOutCubic.transform(_cameraAnimation.value);
    final longitudeDelta = (_to.longitude - _from.longitude + 540) % 360 - 180;
    _map.move(
      LatLng(
        _from.latitude + (_to.latitude - _from.latitude) * t,
        (_from.longitude + longitudeDelta * t + 540) % 360 - 180,
      ),
      _fromZoom + (_toZoom - _fromZoom) * t,
    );
  }

  void _onMapEvent(MapEvent event) {
    if (event is! MapEventWithMove ||
        event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera ||
        event.source == MapEventSource.nonRotatedSizeChange) {
      return;
    }
    _cameraAnimation.stop();
    if (!_moving) {
      _moving = true;
      widget.onUserMove?.call();
    }
    _scheduleIdle();
  }

  void _scheduleIdle() {
    _idle?.cancel();
    if (!_moving || _pointers.isNotEmpty) return;
    _idle = Timer(const Duration(milliseconds: 325), () {
      _moving = false;
      widget.onUserIdle?.call(selectionPoint);
    });
  }

  void _releasePointer(PointerEvent event) {
    _pointers.remove(event.pointer);
    _scheduleIdle();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _cameraAnimation.dispose();
    _map.dispose();
    _tileFailed.dispose();
    unawaited(_tileReload.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    final theme = Theme.of(context);
    final darkTiles = theme.brightness == Brightness.dark
        ? config.osmDarkTileUrlTemplate
        : null;
    final credit = darkTiles == null ? null : config.osmDarkTileAttribution;
    return Listener(
      onPointerDown: (event) {
        _pointers.add(event.pointer);
        _idle?.cancel();
        _cameraAnimation.stop();
      },
      onPointerUp: _releasePointer,
      onPointerCancel: _releasePointer,
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: widget.center,
          initialZoom: widget.zoom,
          backgroundColor: theme.colorScheme.surface,
          onMapReady: () {
            _ready = true;
            final action = _onReady;
            _onReady = null;
            action?.call();
          },
          onTap: (_, point) => widget.onTap?.call(point),
          onMapEvent: widget.onUserIdle == null ? null : _onMapEvent,
          interactionOptions: InteractionOptions(
            flags: widget.scrollWheelZoom
                ? InteractiveFlag.all
                : InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: darkTiles ?? config.osmTileUrlTemplate,
            tileProvider: _tiles,
            reset: _tileReload.stream,
            errorTileCallback: (_, _, _) {
              if (mounted) _tileFailed.value = true;
            },
            tileDisplay: MediaQuery.disableAnimationsOf(context)
                ? const TileDisplay.instantaneous()
                : const TileDisplay.fadeIn(),
            userAgentPackageName: 'com.example.yalla_5roga',
          ),
          MarkerLayer(markers: widget.markers),
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: ValueListenableBuilder<double>(
              valueListenable:
                  widget.attributionInset ?? const AlwaysStoppedAnimation(0.0),
              builder: (_, inset, child) => Padding(
                padding: EdgeInsets.only(bottom: inset),
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _tileFailed,
                    builder: (context, failed, _) => failed
                        ? Material(
                            color: theme.colorScheme.surface,
                            child: TextButton.icon(
                              onPressed: () {
                                _tileFailed.value = false;
                                _tileReload.add(null);
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(context.l10n.mapRetryTiles),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Material(
                    color: theme.colorScheme.surface,
                    child: TextButton(
                      onPressed: () => AppLauncher.open(
                        'https://www.openstreetmap.org/copyright',
                      ),
                      child: Text(
                        ['© OpenStreetMap contributors', ?credit].join(' · '),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

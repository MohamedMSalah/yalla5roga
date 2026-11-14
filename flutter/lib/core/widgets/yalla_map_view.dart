import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_clusters.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_markers.dart';
import 'package:yalla_5roga/core/maps/yalla_map_offline.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

/// Shared vector renderer. Routes retain search, network and commit ownership.
class YallaMapView extends StatefulWidget {
  const YallaMapView({
    super.key,
    required this.controller,
    this.center = cairoMapCenter,
    this.zoom = 12,
    this.places = const [],
    this.categories = const [],
    this.selection = const YallaMapPlaceSelection(),
    this.onPlaceTap,
    this.onTap,
    this.onUserMove,
    this.onUserIdle,
    this.onBoundsChanged,
    this.selectionBottom = 0,
    this.userLocation,
    this.controlsTop = 100,
    this.controlsBottom,
  });
  final YallaMapController controller;
  final LatLng center;
  final double zoom, selectionBottom;
  final List<Place> places;
  final List<CatalogDefinition> categories;
  final YallaMapPlaceSelection selection;
  final ValueChanged<Place>? onPlaceTap;
  final ValueChanged<LatLng>? onTap, onUserIdle;
  final VoidCallback? onUserMove;
  final ValueChanged<String>? onBoundsChanged;
  final LatLng? userLocation;
  final double controlsTop;
  final double? controlsBottom;
  @override
  State<YallaMapView> createState() => _YallaMapViewState();
}

class _YallaMapViewState extends State<YallaMapView>
    with SingleTickerProviderStateMixin {
  final _markers = YallaMapMarkers();
  late final AnimationController _selectionAnimation = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
  )..addListener(_animationFrame);
  ml.MapLibreMapController? _native;
  String _style = '', _language = 'en';
  Timer? _idle, _watchdog;
  Future<void> _work = Future.value();
  bool _ready = false,
      _installed = false,
      _dirty = false,
      _queued = false,
      _userMoving = false,
      _animating = false;
  final _pointers = <int>{};
  int _epoch = 0, _mapKey = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  bool _active = true;
  Widget? _nativeSurface;
  (String, int, double, double)? _surfaceKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_active) _settled();
    _active = active;
    _language = context.l10n.locale.languageCode;
    widget.controller.camera.reduceMotion = AppMotion.reduce(context);
    final style = YallaMapStyle.resolve(
      dark: Theme.of(context).brightness == Brightness.dark,
      language: _language,
    );
    if (_style != style) {
      _style = style;
      _epoch++;
      _ready = false;
      _installed = false;
      _markers.reset();
      widget.controller.ready = false;
      _startWatchdog();
    }
  }

  @override
  void didUpdateWidget(covariant YallaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
    }
    widget.controller.selectionBottom = widget.selectionBottom;
    if (!identical(oldWidget.places, widget.places) ||
        !identical(oldWidget.categories, widget.categories) ||
        oldWidget.selection.focusedId != widget.selection.focusedId ||
        oldWidget.selection.mode != widget.selection.mode ||
        !identical(oldWidget.selection.selected, widget.selection.selected) ||
        oldWidget.userLocation != widget.userLocation) {
      _queueLayers();
    }
    if (oldWidget.selection.focusedId != widget.selection.focusedId &&
        widget.selection.focusedId != null) {
      if (AppMotion.reduce(context)) {
        _selectionAnimation.value = 1;
      } else {
        _selectionAnimation.forward(from: 0);
      }
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 18), () {
      if (mounted && !_ready) widget.controller.reportFailure(true);
    });
  }

  void _created(ml.MapLibreMapController native) {
    _native = native;
    widget.controller.camera.native = native;
  }

  void _loaded() {
    if (!mounted) return;
    _watchdog?.cancel();
    _ready = true;
    _installed = false;
    _markers.reset();
    widget.controller.reportFailure(false);
    _queueLayers();
  }

  void _queueLayers() {
    _dirty = true;
    if (!_ready || _queued) return;
    _queued = true;
    final epoch = _epoch;
    final number = context.l10n.n;
    _work = _work
        .then((_) async {
          while (_dirty && mounted && _ready && epoch == _epoch) {
            _dirty = false;
            final map = _native!;
            final places = List<Place>.of(widget.places);
            final selection = widget.selection;
            final highlighted = YallaMapMarkers.highlighted(places, selection);
            final highlightedIds = highlighted.map((p) => p.id).toSet();
            final data = YallaMapMarkers.collection(
              places.where((p) => !highlightedIds.contains(p.id)),
              widget.categories,
            );
            final selected = YallaMapMarkers.collection(
              highlighted,
              widget.categories,
            );
            final custom = <String, dynamic>{
              'type': 'FeatureCollection',
              'features': [
                if (selection.mode != YallaMapSelectionMode.browse)
                  for (final (index, place) in selection.selected.indexed)
                    if (place.id.isEmpty && YallaMapMarkers.validPoint(place))
                      {
                        'type': 'Feature',
                        'id': index,
                        'geometry': {
                          'type': 'Point',
                          'coordinates': [place.longitude, place.latitude],
                        },
                        'properties': {
                          'custom_index': index,
                          'selection_order': number(index + 1),
                        },
                      },
              ],
            };
            if (selection.mode == YallaMapSelectionMode.multiple) {
              for (final feature in selected['features'] as List) {
                final index = selection.selected.indexWhere(
                  (p) => p.id == feature['properties']['place_id'],
                );
                if (index >= 0) {
                  feature['properties']['selection_order'] = number(index + 1);
                }
              }
            }
            await _markers.images(map, [
              ...places,
              ...highlighted,
            ], widget.categories);
            if (!mounted || epoch != _epoch) return;
            if (!_installed) {
              await YallaMapClusters.install(
                map,
                data,
                arabic: _language == 'ar',
              );
              await _markers.install(map);
              await map.addGeoJsonSource('yalla-user', {
                'type': 'FeatureCollection',
                'features': [],
              });
              await map.addCircleLayer(
                'yalla-user',
                'yalla-user-dot',
                const ml.CircleLayerProperties(
                  circleColor: '#346AC7',
                  circleRadius: 7,
                  circleStrokeWidth: 3,
                  circleStrokeColor: '#FFFFFF',
                ),
                enableInteraction: false,
              );
              if (!mounted || epoch != _epoch) return;
              _installed = true;
              widget.controller.attach();
              _settled();
            }
            if (!mounted || epoch != _epoch) return;
            await _markers.update(
              map,
              dataKey: jsonEncode(data),
              data: data,
              selected: selected,
              selectedKey: jsonEncode(selected),
              custom: custom,
              customKey: jsonEncode(custom),
            );
            if (widget.userLocation case final location?) {
              await map.setGeoJsonSource('yalla-user', {
                'type': 'FeatureCollection',
                'features': [
                  {
                    'type': 'Feature',
                    'geometry': {
                      'type': 'Point',
                      'coordinates': [location.longitude, location.latitude],
                    },
                    'properties': <String, dynamic>{},
                  },
                ],
              });
            }
          }
        })
        .catchError((Object error) {
          if (mounted && epoch == _epoch) widget.controller.reportFailure(true);
        })
        .whenComplete(() {
          _queued = false;
          if (_dirty && mounted && _ready && epoch != _epoch) _queueLayers();
        });
  }

  void _animationFrame() {
    if (!_ready ||
        !_installed ||
        _animating ||
        DateTime.now().difference(_lastFrame).inMilliseconds < 32) {
      return;
    }
    _animating = true;
    _lastFrame = DateTime.now();
    _work = _work
        .then((_) async {
          if (mounted && _ready && _installed) {
            await _markers.selectionFrame(
              _native!,
              AppMotion.enter.transform(_selectionAnimation.value),
            );
          }
        })
        .catchError((Object _) {})
        .whenComplete(() => _animating = false);
  }

  void _moving(ml.CameraPosition position) {
    widget.controller.camera.position = position;
    _idle?.cancel();
    if (_pointers.isNotEmpty && !_userMoving) {
      _userMoving = true;
      widget.onUserMove?.call();
    }
  }

  void _settled() {
    _idle?.cancel();
    _idle = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_publishViewport()),
    );
  }

  Future<void> _publishViewport() async {
    final native = _native;
    if (!mounted ||
        !_ready ||
        !_active ||
        native == null ||
        _pointers.isNotEmpty) {
      return;
    }
    final epoch = _epoch;
    try {
      final size = context.size;
      final box = await native.getVisibleRegion();
      final point = size == null
          ? native.cameraPosition!.target
          : await native.toLatLng(
              math.Point(
                size.width / 2,
                (size.height - widget.controller.selectionBottom) / 2,
              ),
            );
      if (!mounted || epoch != _epoch) return;
      final location = LatLng(point.latitude, point.longitude);
      widget.controller.selectionPoint = location;
      if (_userMoving) {
        _userMoving = false;
        widget.onUserIdle?.call(location);
      }
      // Bound precision avoids a new query for sub-pixel camera drift.
      final west = box.southwest.longitude.clamp(-180, 180);
      final east = box.northeast.longitude.clamp(-180, 180);
      if (west < east) {
        widget.onBoundsChanged?.call(
          [
            west,
            box.southwest.latitude.clamp(-85, 85),
            east,
            box.northeast.latitude.clamp(-85, 85),
          ].map((n) => n.toStringAsFixed(4)).join(','),
        );
      }
    } catch (_) {
      if (mounted && epoch == _epoch) widget.controller.reportFailure(true);
    }
  }

  Future<void> _tap(math.Point<double> screen, ml.LatLng coordinates) async {
    if (!_installed) return;
    final native = _native!;
    try {
      final features = await native.queryRenderedFeaturesInRect(
        Rect.fromCenter(
          center: Offset(screen.x, screen.y),
          width: 48,
          height: 48,
        ),
        [
          YallaMapMarkers.selectedPins,
          YallaMapMarkers.pins,
          YallaMapClusters.circles,
          YallaMapMarkers.customPoints,
        ],
        null,
      );
      if (!mounted) return;
      if (features.isNotEmpty) {
        final feature = features.first as Map;
        final properties = feature['properties'] as Map;
        if (properties['custom_index'] case final num index) {
          if (index.toInt() >= 0 &&
              index.toInt() < widget.selection.selected.length) {
            widget.onPlaceTap?.call(widget.selection.selected[index.toInt()]);
          }
          return;
        }
        final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
        if (properties['cluster'] == true ||
            properties.containsKey('point_count')) {
          // A cluster tap explores a new viewport, unlike focusing a place.
          widget.onUserMove?.call();
          final zoom = ((native.cameraPosition?.zoom ?? 12) + 2)
              .clamp(0, 18)
              .toDouble();
          widget.controller.focus(
            LatLng(
              (coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble(),
            ),
            zoom: zoom,
          );
          return;
        }
        final id = properties['place_id'];
        final place = [
          ...widget.places,
          ...widget.selection.selected,
        ].where((p) => p.id == id).firstOrNull;
        if (place != null) {
          widget.onPlaceTap?.call(place);
          return;
        }
      }
      widget.onTap?.call(LatLng(coordinates.latitude, coordinates.longitude));
    } catch (_) {
      if (mounted) widget.controller.reportFailure(true);
    }
  }

  void _retry() {
    _epoch++;
    _ready = false;
    _installed = false;
    if (identical(widget.controller.camera.native, _native)) {
      widget.controller.detach();
    }
    widget.controller.reportFailure(false);
    _markers.reset();
    _startWatchdog();
    setState(() => _mapKey++);
  }

  @override
  void dispose() {
    _epoch++;
    _ready = false;
    _idle?.cancel();
    _watchdog?.cancel();
    _selectionAnimation.dispose();
    // MapLibreMap owns/disposes its native controller; never double-dispose it.
    if (identical(widget.controller.camera.native, _native)) {
      widget.controller.detach();
    }
    _native = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epoch = _epoch;
    final key = (
      _style,
      _mapKey,
      MediaQuery.paddingOf(context).top,
      widget.controlsTop,
    );
    if (_surfaceKey != key) {
      _surfaceKey = key;
      // Selection updates GeoJSON layers without rebuilding the platform view.
      _nativeSurface = Listener(
        onPointerDown: (event) {
          _pointers.add(event.pointer);
          _idle?.cancel();
        },
        onPointerUp: (event) {
          _pointers.remove(event.pointer);
          if (_pointers.isEmpty) _settled();
        },
        onPointerCancel: (event) {
          _pointers.remove(event.pointer);
          if (_pointers.isEmpty) _settled();
        },
        child: ml.MapLibreMap(
          key: ValueKey((_mapKey, _style)),
          styleString: _style,
          initialCameraPosition:
              widget.controller.camera.position ??
              ml.CameraPosition(
                target: ml.LatLng(
                  widget.center.latitude,
                  widget.center.longitude,
                ),
                zoom: widget.zoom,
              ),
          onMapCreated: (map) {
            if (epoch == _epoch) _created(map);
          },
          onStyleLoadedCallback: () {
            if (epoch == _epoch) _loaded();
          },
          onCameraMove: (position) {
            if (epoch == _epoch) _moving(position);
          },
          onCameraIdle: () {
            if (epoch == _epoch) _settled();
          },
          onMapClick: (screen, point) {
            if (epoch == _epoch) unawaited(_tap(screen, point));
          },
          trackCameraPosition: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          featureTapsTriggersMapClick: true,
          minMaxZoomPreference: const ml.MinMaxZoomPreference(3, 20),
          attributionButtonPosition: ml.AttributionButtonPosition.topRight,
          compassViewPosition: ml.CompassViewPosition.topRight,
          compassViewMargins: math.Point(
            12,
            MediaQuery.paddingOf(context).top + widget.controlsTop + 56,
          ),
        ),
      );
    }
    widget.controller.selectionBottom = widget.selectionBottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        _nativeSurface!,
        PositionedDirectional(
          start: 8,
          end: 8,
          bottom: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: widget.controller.attributionInset,
            builder: (_, inset, _) => Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Material(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(8),
                  child: TextButton(
                    onPressed: () =>
                        AppLauncher.open(YallaMapStyle.attributionUrl),
                    child: Text(
                      YallaMapStyle.attribution,
                      style: context.texts.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: widget.controller,
          builder: (_, _) => widget.controller.failed
              ? PositionedDirectional(
                  top:
                      MediaQuery.paddingOf(context).top +
                      widget.controlsTop +
                      112,
                  start: 12,
                  end: 12,
                  child: Material(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.mapRetryTiles),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        PositionedDirectional(
          start: 12,
          top: widget.controlsBottom == null
              ? MediaQuery.paddingOf(context).top + widget.controlsTop + 56
              : null,
          bottom: widget.controlsBottom,
          child: IconButton.filledTonal(
            tooltip: context.l10n.mapRetryTiles,
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (YallaMapOffline.supported)
          PositionedDirectional(
            start: widget.controlsBottom == null ? 12 : 68,
            top: widget.controlsBottom == null
                ? MediaQuery.paddingOf(context).top + widget.controlsTop
                : null,
            bottom: widget.controlsBottom,
            child: AnimatedBuilder(
              animation: YallaMapOffline.instance,
              builder: (_, _) {
                final cache = YallaMapOffline.instance;
                return IconButton.filledTonal(
                  tooltip: cache.failed
                      ? context.l10n.mapOfflineFailed
                      : cache.complete
                      ? context.l10n.mapOfflineSaved
                      : context.l10n.mapSaveOffline,
                  onPressed: cache.busy
                      ? null
                      : () async {
                          if (!_ready) return;
                          try {
                            final bounds = await _native!.getVisibleRegion();
                            if (mounted) await cache.save(bounds, _style);
                          } catch (_) {
                            if (mounted) widget.controller.reportFailure(true);
                          }
                        },
                  icon: cache.busy
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            value: cache.progress > 0 ? cache.progress : null,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          cache.failed
                              ? Icons.error_outline
                              : cache.complete
                              ? Icons.offline_pin_outlined
                              : Icons.download_for_offline_outlined,
                        ),
                );
              },
            ),
          ),
      ],
    );
  }
}

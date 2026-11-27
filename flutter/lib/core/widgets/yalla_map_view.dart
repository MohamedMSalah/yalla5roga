import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals, mapEquals;
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/personal_location_map_layer.dart';
import 'package:yalla_5roga/core/maps/personal_route_map_layer.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_clusters.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_markers.dart';
import 'package:yalla_5roga/core/maps/yalla_map_offline.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
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
    this.placeLabelPrefixes = const {},
    this.privatePlaces = const [],
    this.personalLocations = const [],
    this.personalRoute,
    this.onPersonalLocationTap,
    this.categories = const [],
    this.selection = const YallaMapPlaceSelection(),
    this.onPlaceTap,
    this.idleDebounce = const Duration(milliseconds: 400),
    this.onTap,
    this.onUserMove,
    this.onUserIdle,
    this.onBoundsChanged,
    this.onViewportChanged,
    this.regionPicker = false,
    this.selectionBottom = 0,
    this.userLocation,
    this.userAccuracy,
    this.userLocationApproximate = false,
    this.darkBasemap,
    this.customControls = false,
    this.controlsTop = 100,
    this.controlsBottom,
  });
  final Duration idleDebounce;
  final YallaMapController controller;
  final LatLng center;
  final double zoom, selectionBottom;
  final List<Place> places, privatePlaces;
  final Map<String, String> placeLabelPrefixes;
  final List<PersonalMapMarker> personalLocations;
  final PersonalRouteOverlay? personalRoute;
  final void Function(String key, Place? catalogPlace)? onPersonalLocationTap;
  final List<CatalogDefinition> categories;
  final YallaMapPlaceSelection selection;
  final ValueChanged<Place>? onPlaceTap;
  final ValueChanged<LatLng>? onTap, onUserIdle;
  final VoidCallback? onUserMove;
  final ValueChanged<String>? onBoundsChanged;
  final void Function(String bounds, ml.CameraPosition position)?
  onViewportChanged;
  final bool regionPicker;
  final LatLng? userLocation;
  final double? userAccuracy;
  final bool userLocationApproximate, customControls;
  final bool? darkBasemap;
  final double controlsTop;
  final double? controlsBottom;
  @override
  State<YallaMapView> createState() => _YallaMapViewState();
}

class _YallaMapViewState extends State<YallaMapView>
    with SingleTickerProviderStateMixin {
  final _initialization = kDebugMode ? (Stopwatch()..start()) : null;
  final _markers = YallaMapMarkers();
  final _personal = PersonalLocationMapLayer();
  final _route = PersonalRouteMapLayer();
  bool _personalInstalled = false;
  late final AnimationController _selectionAnimation = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  )..addListener(_animationFrame);
  ml.MapLibreMapController? _native;
  String _style = '', _language = 'en';
  List<Place>? _mappedPlaces, _mappedPrivate;
  Map<String, String>? _mappedPrefixes;
  Map<String, dynamic>? _privateData;
  String? _privateKey, _privateLanguage;
  String? _mappedLanguage;
  Map<String, dynamic>? _mappedData;
  String? _mappedKey;
  (LatLng?, double?, bool)? _shownLocation;
  bool _dark = false;
  Timer? _idle, _watchdog;
  Future<void> _work = Future.value();
  bool _ready = false,
      _installed = false,
      _dirty = false,
      _queued = false,
      _userMoving = false,
      _animating = false;
  final _pointers = <int>{};
  int _epoch = 0, _mapKey = 0, _cameraRevision = 0, _styleLoads = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  bool _active = true;
  Widget? _nativeSurface;
  (String, int, double, double, TextDirection, bool)? _surfaceKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_active) _settled();
    _active = active;
    _language = context.l10n.locale.languageCode;
    final reduced = AppMotion.reduce(context);
    final motionChanged = widget.controller.camera.reduceMotion != reduced;
    widget.controller.camera.reduceMotion = reduced;
    _resolveStyle();
    if (motionChanged && reduced) {
      _selectionAnimation.stop();
      _queueLayers();
    }
  }

  void _resolveStyle() {
    final dark =
        widget.darkBasemap ?? (Theme.of(context).brightness == Brightness.dark);
    final style = YallaMapStyle.resolve(dark: dark, language: _language);
    if (_style != style || _dark != dark) {
      if (_style == style) _mapKey++;
      _dark = dark;
      _style = style;
      _epoch++;
      _pointers.clear();
      _userMoving = false;
      _ready = false;
      _installed = false;
      widget.controller.ready = false;
      _startWatchdog();
    }
  }

  @override
  void didUpdateWidget(covariant YallaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.darkBasemap != widget.darkBasemap) _resolveStyle();
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
    }
    widget.controller.selectionBottom = widget.selectionBottom;
    if (!identical(oldWidget.places, widget.places) ||
        !mapEquals(oldWidget.placeLabelPrefixes, widget.placeLabelPrefixes) ||
        !identical(oldWidget.privatePlaces, widget.privatePlaces) ||
        !listEquals(oldWidget.personalLocations, widget.personalLocations) ||
        oldWidget.personalRoute != widget.personalRoute ||
        !identical(oldWidget.categories, widget.categories) ||
        oldWidget.selection.focusedId != widget.selection.focusedId ||
        oldWidget.selection.mode != widget.selection.mode ||
        !identical(oldWidget.selection.selected, widget.selection.selected) ||
        oldWidget.userLocation != widget.userLocation ||
        oldWidget.userAccuracy != widget.userAccuracy ||
        oldWidget.userLocationApproximate != widget.userLocationApproximate) {
      _queueLayers();
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
    _selectionAnimation.stop();
    _styleLoads++;
    _ready = true;
    _installed = false;
    _personalInstalled = false;
    _personal.reset();
    _route.reset();
    widget.controller.ready = false;
    widget.controller.reportFailure(false);
    _queueLayers();
  }

  void _queueLayers() {
    _dirty = true;
    if (!_ready || _queued) return;
    _queued = true;
    final generation = (_epoch, _styleLoads);
    bool current() => mounted && _ready && generation == (_epoch, _styleLoads);
    final number = context.l10n.n;
    _work = _work
        .then((_) async {
          while (_dirty && current()) {
            _dirty = false;
            final map = _native!;
            final places = widget.places;
            final selection = widget.selection;
            final privatePlaces = widget.privatePlaces;
            final highlighted = YallaMapMarkers.highlighted([
              ...places,
              ...privatePlaces,
            ], selection);
            if (!identical(privatePlaces, _mappedPrivate) ||
                _privateLanguage != _language) {
              _mappedPrivate = privatePlaces;
              _privateLanguage = _language;
              _privateData = YallaMapMarkers.collection(
                privatePlaces,
                language: _language,
              );
              _privateKey = jsonEncode(_privateData);
            }
            if (!identical(places, _mappedPlaces) ||
                !mapEquals(widget.placeLabelPrefixes, _mappedPrefixes) ||
                _language != _mappedLanguage) {
              _mappedPlaces = places;
              _mappedPrefixes = widget.placeLabelPrefixes;
              _mappedLanguage = _language;
              _mappedData = YallaMapMarkers.collection(
                places,
                language: _language,
                labelPrefixes: widget.placeLabelPrefixes,
              );
              _mappedKey = jsonEncode(_mappedData);
            }
            final data = _mappedData!;
            final selected = YallaMapMarkers.collection(
              highlighted,
              language: _language,
              includeUnavailable: selection.showChecks,
              labelPrefixes: widget.placeLabelPrefixes,
            );
            final custom = <String, dynamic>{
              'type': 'FeatureCollection',
              'features': [
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
                        'name': place.displayName(_language),
                        if (selection.mode == YallaMapSelectionMode.multiple)
                          'selection_order': number(index + 1),
                      },
                    },
              ],
            };
            if (!_installed) {
              _markers.reset();
              _shownLocation = null;
            }
            await _markers.images(map, [
              ...places,
              ...privatePlaces,
              ...highlighted,
            ], dark: _dark);
            if (!current()) return;
            if (!_installed) {
              await YallaMapClusters.install(map, dark: _dark);
              await _markers.install(
                map,
                dark: _dark,
                showChecks: selection.showChecks,
              );
              await map.addGeoJsonSource('yalla-user', {
                'type': 'FeatureCollection',
                'features': [],
              });
              await map.addFillLayer(
                'yalla-user',
                'yalla-user-accuracy',
                const ml.FillLayerProperties(
                  fillColor: '#347CFA',
                  fillOpacity: .14,
                  fillOutlineColor: '#4379CC',
                ),
                filter: [
                  '==',
                  ['geometry-type'],
                  'Polygon',
                ],
                enableInteraction: false,
              );
              for (final (id, size, opacity) in [
                ('halo', 23.0, .13),
                ('ring', 15.0, .24),
                ('dot', 7.0, 1.0),
              ]) {
                await map.addCircleLayer(
                  'yalla-user',
                  'yalla-user-$id',
                  ml.CircleLayerProperties(
                    circleRadius: size,
                    circleColor: [
                      'case',
                      ['get', 'approximate'],
                      '#7B90B5',
                      '#3B87FF',
                    ],
                    circleOpacity: opacity,
                    circleStrokeWidth: id == 'dot' ? 2.5 : 0,
                    circleStrokeColor: '#F5F3FF',
                  ),
                  filter: [
                    '==',
                    ['geometry-type'],
                    'Point',
                  ],
                  enableInteraction: false,
                );
              }
              if (!current()) return;
              if (_initialization?.isRunning == true) {
                _initialization!.stop();
                debugPrint(
                  'Map initialization ${_initialization.elapsedMilliseconds} ms',
                );
              }
              _installed = true;
              widget.controller.attach();
              _settled();
            }
            if (!current()) return;
            final personal = widget.personalLocations;
            if (!_personalInstalled && personal.isNotEmpty) {
              await _personal.install(map, dark: _dark, current: current);
              if (!current()) return;
              _personalInstalled = true;
            }
            if (_personalInstalled) {
              await _personal.update(map, personal, current: current);
              if (!current()) return;
              await _markers.setPersonalOverlaps(map, {
                for (final place in [...places, ...highlighted])
                  if (YallaMapMarkers.validPoint(place) &&
                      personal.any(
                        (marker) =>
                            marker.catalogPlaceId == place.id &&
                            PersonalLocationMapLayer.overlaps(
                              marker.point,
                              LatLng(place.latitude!, place.longitude!),
                            ),
                      ))
                    place.id,
              });
              if (!current()) return;
            }
            await _route.render(
              map,
              widget.personalRoute,
              dark: _dark,
              current: current,
            );
            if (!current()) return;
            final markerTimer = kDebugMode ? (Stopwatch()..start()) : null;
            await _markers.update(
              map,
              dataKey: _mappedKey!,
              privateKey: _privateKey!,
              privateData: _privateData!,
              data: data,
              custom: custom,
              customKey: jsonEncode(custom),
            );
            if (!current()) return;
            final startAnimation = await _markers.updateSelection(
              map,
              selected,
              animate: !widget.controller.camera.reduceMotion,
              progress: AppMotion.settle.transform(_selectionAnimation.value),
            );
            if (startAnimation && current()) {
              _selectionAnimation.forward(from: 0);
            }
            if (!current()) return;
            if (kDebugMode) {
              debugPrint(
                'Map layers ${markerTimer!.elapsedMilliseconds} ms displayed=${places.length + privatePlaces.length}',
              );
            }
            final location = (
              widget.userLocation,
              widget.userAccuracy,
              widget.userLocationApproximate,
            );
            if (_shownLocation != location) {
              await map.setGeoJsonSource('yalla-user', _locationData(location));
              _shownLocation = location;
            }
          }
        })
        .catchError((Object error) {
          if (current()) widget.controller.reportFailure(true);
        })
        .whenComplete(() {
          _queued = false;
          if (_dirty && mounted && _ready) _queueLayers();
        });
  }

  Map<String, dynamic> _locationData((LatLng?, double?, bool) data) {
    final (point, accuracy, approximate) = data;
    final ring = [
      if (point != null &&
          accuracy != null &&
          accuracy.isFinite &&
          accuracy > 0 &&
          accuracy <= 5000)
        for (var i = 0; i <= 48; i++)
          const Distance().offset(point, accuracy, (i % 48) * 360 / 48),
    ];
    return {
      'type': 'FeatureCollection',
      'features': [
        if (ring.isNotEmpty &&
            ring.every(
              (p) =>
                  (p.longitude - point!.longitude).abs() < 180 &&
                  p.latitude.abs() <= 85.051129,
            ))
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  for (final p in ring) [p.longitude, p.latitude],
                ],
              ],
            },
            'properties': <String, dynamic>{},
          },
        if (point != null)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [point.longitude, point.latitude],
            },
            'properties': {'approximate': approximate},
          },
      ],
    };
  }

  void _animationFrame() {
    final value = _selectionAnimation.value;
    if (!_ready ||
        !_installed ||
        _animating ||
        value == 0 ||
        (value < 1 &&
            DateTime.now().difference(_lastFrame).inMilliseconds < 30)) {
      return;
    }
    _animating = true;
    final generation = (_epoch, _styleLoads);
    var progress = value;
    _work = _work
        .then((_) async {
          if (mounted &&
              _ready &&
              _installed &&
              generation == (_epoch, _styleLoads)) {
            progress = _selectionAnimation.value;
            _lastFrame = DateTime.now();
            await _markers.selectionFrame(
              _native!,
              AppMotion.settle.transform(progress),
            );
          }
        })
        .catchError((Object _) {})
        .whenComplete(() {
          _animating = false;
          // Always commit the last frame, even if the previous write was busy.
          if (mounted &&
              generation == (_epoch, _styleLoads) &&
              progress < 1 &&
              _selectionAnimation.isCompleted) {
            _animationFrame();
          }
        });
  }

  void _moving(ml.CameraPosition position) {
    _cameraRevision++;
    widget.controller.camera.position = position;
    _idle?.cancel();
    if (_pointers.isNotEmpty && !_userMoving) {
      _userMoving = true;
      widget.onUserMove?.call();
    }
  }

  void _settled() {
    _idle?.cancel();
    _idle = Timer(widget.idleDebounce, () => unawaited(_publishViewport()));
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
    final revision = _cameraRevision;
    try {
      final size = context.size;
      final box =
          widget.onBoundsChanged == null && widget.onViewportChanged == null
          ? null
          : await native.getVisibleRegion();
      final point = size == null
          ? native.cameraPosition!.target
          : await native.toLatLng(
              math.Point(
                size.width / 2,
                (size.height - widget.controller.selectionBottom) / 2,
              ),
            );
      if (!mounted || epoch != _epoch || revision != _cameraRevision) return;
      final location = LatLng(point.latitude, point.longitude);
      widget.controller.selectionPoint = location;
      if (_userMoving) {
        _userMoving = false;
        widget.onUserIdle?.call(location);
      }
      // Use exact native bounds, including wrapped viewports.
      if (box == null) return;
      double longitude(double value) =>
          value >= -180 && value <= 180 ? value : (value + 180) % 360 - 180;
      final world =
          (box.northeast.longitude - box.southwest.longitude).abs() >= 360;
      final west = world ? -180.0 : longitude(box.southwest.longitude);
      final east = world ? 180.0 : longitude(box.northeast.longitude);
      final south = box.southwest.latitude.clamp(-90, 90);
      final north = box.northeast.latitude.clamp(-90, 90);
      if (west != east && south < north && !(west == 180 && east == -180)) {
        final bounds = [west, south, east, north].join(',');
        widget.onBoundsChanged?.call(bounds);
        if (widget.controller.camera.position ?? native.cameraPosition
            case final position?) {
          widget.onViewportChanged?.call(bounds, position);
        }
      }
    } catch (_) {
      if (mounted && epoch == _epoch) widget.controller.reportFailure(true);
    }
  }

  Future<void> _tap(math.Point<double> screen, ml.LatLng coordinates) async {
    if (!_installed) return;
    final native = _native!;
    final generation = (_epoch, _styleLoads);
    bool current() =>
        mounted && _installed && generation == (_epoch, _styleLoads);
    try {
      final layers = [
        if (_personalInstalled && widget.personalLocations.isNotEmpty)
          PersonalLocationMapLayer.dots,
        YallaMapMarkers.selectedPins,
        YallaMapMarkers.pins,
        YallaMapMarkers.privatePins,
        YallaMapMarkers.customPoints,
        YallaMapMarkers.customOrder,
        YallaMapClusters.pins,
      ];
      final exact = await native.queryRenderedFeatures(screen, layers, null);
      if (!current()) return;
      final features = exact.isNotEmpty
          ? exact
          : await native.queryRenderedFeaturesInRect(
              Rect.fromCenter(
                center: Offset(screen.x, screen.y),
                width: 36,
                height: 36,
              ),
              layers,
              null,
            );
      if (!current()) return;
      for (final feature in features.whereType<Map>()) {
        final properties = feature['properties'];
        if (properties is! Map) continue;
        if (properties['personal_key'] case final String key) {
          final marker = widget.personalLocations
              .where((marker) => marker.key == key)
              .firstOrNull;
          if (marker != null) {
            final catalogPlace = marker.catalogPlaceId == null
                ? null
                : [...widget.places, ...widget.selection.selected]
                      .where((place) => place.id == marker.catalogPlaceId)
                      .firstOrNull;
            widget.onPersonalLocationTap?.call(key, catalogPlace);
            return;
          }
          continue;
        }
        if (properties['cluster_id'] case final num clusterId) {
          final geometry = feature['geometry'];
          final center = geometry is Map ? geometry['coordinates'] : null;
          if (center case [final num lng, final num lat, ...]) {
            final revision = _cameraRevision;
            final zoom = await native.getClusterExpansionZoom(
              YallaMapClusters.source,
              clusterId.toInt(),
            );
            if (!current() || revision != _cameraRevision) {
              return;
            }
            if (zoom > 0) {
              widget.controller.focusSelection(
                LatLng(lat.toDouble(), lng.toDouble()),
                zoom: math.max(
                  zoom.toDouble(),
                  widget.controller.camera.position?.zoom ?? 0,
                ),
              );
            }
          }
          return;
        }
        if (properties['custom_index'] case final num index) {
          if (index.toInt() >= 0 &&
              index.toInt() < widget.selection.selected.length) {
            widget.onPlaceTap?.call(widget.selection.selected[index.toInt()]);
          }
          return;
        }
        final id = properties['place_id'];
        if (id == null) continue;
        for (final list in [
          widget.privatePlaces,
          widget.places,
          widget.selection.selected,
        ]) {
          final place = list.where((p) => p.id == id).firstOrNull;
          if (place != null) {
            widget.onPlaceTap?.call(place);
            return;
          }
        }
      }
      widget.onTap?.call(LatLng(coordinates.latitude, coordinates.longitude));
    } catch (_) {
      if (current()) widget.controller.reportFailure(true);
    }
  }

  void _retry() {
    _epoch++;
    _pointers.clear();
    _userMoving = false;
    _ready = false;
    _installed = false;
    if (identical(widget.controller.camera.native, _native)) {
      widget.controller.detach();
    }
    widget.controller.reportFailure(false);
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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = (
      _style,
      _mapKey,
      MediaQuery.paddingOf(context).top,
      widget.controlsTop,
      Directionality.of(context),
      widget.customControls,
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
          styleString: YallaMapOffline.instance.renderStyle(_style),
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
          rotateGesturesEnabled: !widget.regionPicker,
          tiltGesturesEnabled: !widget.regionPicker,
          featureTapsTriggersMapClick: true,
          minMaxZoomPreference: const ml.MinMaxZoomPreference(3, 20),
          compassEnabled: !widget.customControls,
          attributionButtonPosition: rtl
              ? ml.AttributionButtonPosition.topLeft
              : ml.AttributionButtonPosition.topRight,
          attributionButtonMargins: math.Point(
            12,
            MediaQuery.paddingOf(context).top + widget.controlsTop + 112,
          ),
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
        if (!widget.customControls)
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
      ],
    );
  }
}

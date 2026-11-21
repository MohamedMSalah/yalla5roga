import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_offline.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';
import 'package:yalla_5roga/core/maps/yalla_offline_images.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

class OfflineMapsPage extends StatefulWidget {
  const OfflineMapsPage({super.key});

  @override
  State<OfflineMapsPage> createState() => _OfflineMapsPageState();
}

class _OfflineMapsPageState extends State<OfflineMapsPage> {
  final _offline = YallaMapOffline.instance;
  final _map = YallaMapController();
  OfflineMapDetail _detail = OfflineMapDetail.standard;
  ml.LatLngBounds? _bounds;
  Size? _size;
  double _fraction = .6;
  int _revision = 0;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_offline.refresh());
  }

  @override
  void dispose() {
    _revision++;
    _map.dispose();
    super.dispose();
  }

  OfflinePlaceCatalog? get _catalog {
    final repository = context.read<DiscoverProvider>().repository;
    return repository is OfflinePlaceCatalog
        ? repository as OfflinePlaceCatalog
        : null;
  }

  String _sizeMb(int bytes) => context.l10n.offlineMapMegabytes(
    context.l10n.n((bytes / (1024 * 1024)).ceil()),
  );

  double _side(Size size) => size.shortestSide * _fraction;

  void _layout(Size size) {
    if (_size == size) return;
    _size = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _choosing) unawaited(_project());
    });
  }

  Future<void> _project() async {
    final native = _map.camera.native;
    final size = _size;
    if (native == null || size == null || !_map.ready) return;
    final revision = ++_revision;
    final side = _side(size);
    final center = size.center(Offset.zero);
    try {
      final corners = await Future.wait([
        native.toLatLng(math.Point(center.dx - side / 2, center.dy + side / 2)),
        native.toLatLng(math.Point(center.dx + side / 2, center.dy - side / 2)),
      ]);
      if (!mounted || !_choosing || revision != _revision) return;
      setState(
        () => _bounds = ml.LatLngBounds(
          southwest: corners[0],
          northeast: corners[1],
        ),
      );
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _bounds = null);
    }
  }

  Future<void> _download(OfflineMapArea area) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final style = YallaMapStyle.resolve(
      dark: context.isDark,
      language: context.l10n.locale.languageCode,
    );
    setState(() => _choosing = false);
    await _offline.download(area, style, catalog);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineMaps)),
      body: !YallaMapOffline.supported
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.offlineMapsUnavailable,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SafeArea(
              child: ListenableBuilder(
                listenable: _offline,
                builder: (context, _) => _choosing ? _picker() : _regions(),
              ),
            ),
    );
  }

  Widget _regions() {
    final l10n = context.l10n;
    final catalog = _catalog;
    final tileBytes = _offline.entries.fold<int>(
      0,
      (size, entry) => size + entry.status.completedResourceSize,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed:
              _offline.online &&
                  !_offline.busy &&
                  catalog != null &&
                  _offline.entries.length < YallaMapOffline.maxPacks
              ? () => setState(() {
                  // The native picker uses its own camera and controller.
                  _bounds = null;
                  _size = null;
                  _choosing = true;
                })
              : null,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(l10n.offlineMapSelect),
        ),
        if (!_offline.online)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l10n.offlineMapInternetRequired),
          ),
        if (_offline.failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l10n.mapOfflineFailed),
          ),
        if (_offline.activeKey != null) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _offline.downloadingPhotos
                  ? l10n.offlineMapSavingPlaces
                  : l10n.offlineMapDownloading,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: _offline.progress),
                  if (_offline.downloadingPhotos)
                    Text(
                      l10n.offlineMapPhotoCount(
                        l10n.n(_offline.activePhotoCount),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _offline.pause,
                child: Text(l10n.offlineMapPause),
              ),
              TextButton(onPressed: _offline.cancel, child: Text(l10n.cancel)),
            ],
          ),
        ],
        if (_offline.entries.isEmpty && _offline.activeKey == null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.offlineMapEmpty),
          ),
        if (_offline.entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.offlineMapStorage(
                _sizeMb(tileBytes),
                _sizeMb(_offline.photoBytes),
              ),
            ),
          ),
        if (_offline.entries.length >= YallaMapOffline.maxPacks)
          Text(l10n.offlineMapLimit),
        for (final entry in _offline.entries) _regionTile(entry, catalog),
      ],
    );
  }

  Widget _regionTile(OfflineMapEntry entry, OfflinePlaceCatalog? catalog) {
    final l10n = context.l10n;
    final definition = entry.region.definition;
    final detail = definition.maxZoom >= OfflineMapDetail.detailed.maxZoom
        ? OfflineMapDetail.detailed
        : OfflineMapDetail.standard;
    final area = OfflineMapArea(definition.bounds, detail);
    final centerLat =
        (area.bounds.southwest.latitude + area.bounds.northeast.latitude) / 2;
    final centerLng =
        (area.bounds.southwest.longitude + area.bounds.northeast.longitude) / 2;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entry.complete ? Icons.offline_pin_outlined : Icons.download_outlined,
      ),
      title: Text(
        l10n.offlineMapCoordinates(
          centerLat.toStringAsFixed(3),
          centerLng.toStringAsFixed(3),
        ),
      ),
      subtitle: Text(
        [
          l10n.offlineMapCoverage(l10n.n((area.squareKm * 100).round() / 100)),
          _sizeMb(entry.status.completedResourceSize + entry.photoBytes),
          entry.complete ? l10n.mapOfflineSaved : l10n.offlineMapIncomplete,
        ].join(' · '),
      ),
      trailing: Wrap(
        children: [
          if (!entry.complete)
            IconButton(
              tooltip: l10n.offlineMapResume,
              onPressed: _offline.busy || !_offline.online || catalog == null
                  ? null
                  : () => _offline.retry(entry, catalog),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          IconButton(
            tooltip: l10n.offlineMapDelete,
            onPressed: _offline.busy ? null : () => _offline.delete(entry),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _picker() {
    final l10n = context.l10n;
    final bounds = _bounds;
    final area = bounds == null ? null : OfflineMapArea(bounds, _detail);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              final size = constraints.biggest;
              _layout(size);
              return Stack(
                fit: StackFit.expand,
                children: [
                  YallaMapView(
                    controller: _map,
                    regionPicker: true,
                    controlsTop: 8,
                    onUserMove: () {
                      _revision++;
                      if (_bounds != null) setState(() => _bounds = null);
                    },
                    onViewportChanged: (_, _) => unawaited(_project()),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: SizedBox.square(
                        dimension: _side(size),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.palette.brandStrong.withValues(
                              alpha: .1,
                            ),
                            border: Border.all(
                              color: context.palette.brandStrong,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Slider(
                  value: _fraction,
                  min: .2,
                  max: .85,
                  semanticFormatterCallback: (value) =>
                      l10n.offlineMapResize(l10n.n((value * 100).round())),
                  onChanged: (value) {
                    setState(() {
                      _fraction = value;
                      _bounds = null;
                    });
                    unawaited(_project());
                  },
                ),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final detail in OfflineMapDetail.values)
                      ChoiceChip(
                        label: Text(
                          detail == OfflineMapDetail.standard
                              ? l10n.offlineMapStandard
                              : l10n.offlineMapDetailed,
                        ),
                        selected: detail == _detail,
                        onSelected: (_) => setState(() => _detail = detail),
                      ),
                  ],
                ),
                if (area != null && area.valid)
                  Text(
                    [
                      l10n.offlineMapCoverage(
                        l10n.n((area.squareKm * 100).round() / 100),
                      ),
                      l10n.offlineMapEstimate(
                        _sizeMb(area.estimatedTileBytes),
                        _sizeMb(YallaOfflineImages.perRegionBytes),
                      ),
                    ].join(' · '),
                    textAlign: TextAlign.center,
                  ),
                if (!_offline.online)
                  Text(l10n.offlineMapInternetRequired)
                else if (area != null && !area.fitsLimits)
                  Text(l10n.offlineMapTooLarge),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _choosing = false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed:
                          area?.fitsLimits == true &&
                              _offline.online &&
                              !_offline.busy
                          ? () => _download(area!)
                          : null,
                      child: Text(l10n.mapSaveOffline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

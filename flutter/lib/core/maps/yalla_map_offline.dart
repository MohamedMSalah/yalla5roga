import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/maps/yalla_map_offline_file.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';
import 'package:yalla_5roga/core/maps/yalla_offline_images.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';

enum OfflineMapDetail {
  standard(12),
  detailed(14);

  const OfflineMapDetail(this.maxZoom);
  static const minZoom = 3;
  final int maxZoom;
}

typedef OfflineMapEntry = ({
  ml.OfflineRegion region,
  ml.OfflineRegionStatus status,
  String key,
  bool complete,
  int photoBytes,
});

class OfflineMapArea {
  const OfflineMapArea(this.bounds, this.detail);
  final ml.LatLngBounds bounds;
  final OfflineMapDetail detail;

  bool get valid =>
      bounds.southwest.latitude < bounds.northeast.latitude &&
      bounds.southwest.longitude < bounds.northeast.longitude;

  String get bbox => [
    bounds.southwest.longitude,
    bounds.southwest.latitude,
    bounds.northeast.longitude,
    bounds.northeast.latitude,
  ].map((value) => value.toStringAsFixed(6)).join(',');

  double get squareKm {
    const radians = math.pi / 180;
    return 6371.0088 *
        6371.0088 *
        (bounds.northeast.longitude - bounds.southwest.longitude) *
        radians *
        (math.sin(bounds.northeast.latitude * radians) -
            math.sin(bounds.southwest.latitude * radians));
  }

  int get tileCount {
    var count = 0;
    for (var z = OfflineMapDetail.minZoom; z <= detail.maxZoom; z++) {
      final n = 1 << z;
      int x(double lng) => ((lng + 180) / 360 * n).floor().clamp(0, n - 1);
      int y(double lat) {
        final phi = lat.clamp(-85.051129, 85.051129) * math.pi / 180;
        return ((1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) /
                2 *
                n)
            .floor()
            .clamp(0, n - 1);
      }

      count +=
          (x(bounds.northeast.longitude) - x(bounds.southwest.longitude) + 1) *
          (y(bounds.southwest.latitude) - y(bounds.northeast.latitude) + 1);
    }
    return count;
  }

  int get estimatedTileBytes => tileCount * 18 * 1024 + 768 * 1024;

  bool get fitsLimits =>
      valid &&
      tileCount <= YallaMapOffline.tileLimit &&
      estimatedTileBytes <= YallaMapOffline.maxBytes;
}

class YallaMapOffline extends ChangeNotifier {
  static final instance = YallaMapOffline();
  static const tileLimit = 2500;
  static const maxBytes = 45 * 1024 * 1024;
  static const maxPacks = 6;
  static const userAgent = 'Yalla5roga/1.0 (com.example.yalla_5roga)';
  static const _owner = 'yalla5roga';
  static bool get native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static bool get supported => native && YallaMapStyle.offlineAllowed;

  final _images = YallaOfflineImages.instance;
  final _styles = <String, String>{};
  NetworkInfoImpl? _network;
  StreamSubscription<bool>? _connection;
  Future<void>? _configuration;
  List<OfflineMapEntry> entries = const [];
  bool online = true, failed = false, downloadingPhotos = false;
  double? progress;
  String? activeKey;
  int? _activeId;
  bool _stop = false;
  bool _cancel = false;
  bool _working = false;
  bool get busy => _working;
  int get photoBytes => _images.storageBytes;
  int get activePhotoCount => activeKey == null ? 0 : _images.count(activeKey!);

  Future<void> initialize(
    SharedPreferences prefs,
    NetworkInfoImpl network,
  ) async {
    if (!native) return;
    _network = network;
    online = await network.isConnected;
    _connection ??= network.changes.listen((value) {
      online = value;
      if (!online && activeKey != null) unawaited(pause());
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(_setNativeOffline(!value));
      }
      notifyListeners();
    });
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _setNativeOffline(!online);
    }
    if (supported) {
      await _images.initialize(prefs);
      for (final dark in [false, true]) {
        for (final language in ['ar', 'en']) {
          final style = YallaMapStyle.resolve(dark: dark, language: language);
          if (style.startsWith('{')) {
            final digest = sha256.convert(utf8.encode(style)).toString();
            _styles[style] = await persistMapStyle(
              style,
              digest.substring(0, 16),
            );
          }
        }
      }
    }
  }

  Future<void> _setNativeOffline(bool offline) async {
    try {
      await ml.setOffline(offline);
    } on PlatformException {
      // The native library still observes the platform's network availability.
    } on MissingPluginException {
      // Availability differs across native bindings.
    }
  }

  Future<void> _configure() =>
      _configuration ??= _setLimits().onError((Object error, StackTrace stack) {
        _configuration = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _setLimits() async {
    await ml.setHttpHeaders({'User-Agent': userAgent});
    await ml.setOfflineTileCountLimit(maxPacks * tileLimit);
    await ml.setOfflineMaxConcurrentRequests(
      maxRequests: 4,
      maxRequestsPerHost: 4,
    );
  }

  String renderStyle(String style) {
    final uri = _styles[style];
    return uri == null ? style : Uri.parse(uri).toFilePath();
  }

  Future<void> refresh() async {
    if (!supported || _working) return;
    try {
      entries = await _readEntries();
      failed = false;
    } catch (_) {
      failed = true;
    }
    notifyListeners();
  }

  Future<List<OfflineMapEntry>> _readEntries() async {
    final result = <String, OfflineMapEntry>{};
    final regions = await ml.getListOfRegions();
    for (final region in regions.where((r) => r.metadata['owner'] == _owner)) {
      final status = await ml.getOfflineRegionStatus(region.id);
      final key = region.metadata['key'] as String? ?? 'legacy-${region.id}';
      final entry = (
        region: region,
        status: status,
        key: key,
        complete: status.isComplete && _images.finished(key),
        photoBytes: _images.bytes(key),
      );
      final previous = result[key];
      if (previous == null ||
          (!previous.status.isComplete && status.isComplete) ||
          (previous.status.isComplete == status.isComplete &&
              region.id > previous.region.id)) {
        result[key] = entry;
      }
    }
    return result.values.toList(growable: false);
  }

  Future<void> download(
    OfflineMapArea area,
    String style,
    OfflinePlaceCatalog catalog,
  ) async {
    if (!area.fitsLimits || !supported || busy || !online) return;
    final styleUrl = _styles[style] ?? (style.startsWith('{') ? null : style);
    if (styleUrl == null) {
      failed = true;
      notifyListeners();
      return;
    }
    final key = sha256
        .convert(utf8.encode('$style|${area.bbox}|${area.detail.name}'))
        .toString();
    await _run(
      key,
      ml.OfflineRegionDefinition(
        bounds: area.bounds,
        mapStyleUrl: styleUrl,
        minZoom: OfflineMapDetail.minZoom.toDouble(),
        maxZoom: area.detail.maxZoom.toDouble(),
      ),
      catalog,
    );
  }

  Future<void> retry(OfflineMapEntry entry, OfflinePlaceCatalog catalog) =>
      _run(entry.key, entry.region.definition, catalog);

  Future<void> _run(
    String key,
    ml.OfflineRegionDefinition definition,
    OfflinePlaceCatalog catalog,
  ) async {
    if (busy || !online || !supported) return;
    _working = true;
    activeKey = key;
    _stop = _cancel = failed = downloadingPhotos = false;
    progress = null;
    notifyListeners();

    try {
      if (!_images.available) {
        throw StateError('Offline image storage unavailable');
      }
      await _configure();
      entries = await _readEntries();
      final existing = entries.where((entry) => entry.key == key).firstOrNull;
      if (existing?.complete == true || _stop) return;
      if (existing == null && entries.length >= maxPacks) {
        throw StateError('Offline region limit exceeded');
      }
      _activeId = existing?.region.id;
      if (existing?.status.isComplete != true) {
        var nativeFailed = false;
        var nativeOversized = false;
        void onEvent(ml.DownloadRegionStatus event) {
          if (event is ml.Error) nativeFailed = true;
          if (event is ml.InProgress &&
              (event.completedResourceSize > maxBytes ||
                  event.requiredResourceCount > tileLimit)) {
            nativeOversized = true;
          }
        }

        var resumed = false;
        if (_activeId case final id?) {
          try {
            await ml.resumeOfflineRegionDownload(id);
            resumed = true;
          } on PlatformException {
            // The Android binding loses native progress observers on restart.
          }
        }
        if (!resumed && !_stop) {
          final oldId = _activeId;
          final region = await ml.downloadOfflineRegion(
            definition,
            metadata: {'owner': _owner, 'key': key},
            onEvent: onEvent,
          );
          _activeId = region.id;
          if (oldId != null) await ml.deleteOfflineRegion(oldId);
        }
        var lastProgress = 0;
        var lastActivity = DateTime.now();
        while (!_stop && !nativeFailed && !nativeOversized) {
          if (!await _connected()) {
            _stop = true;
            break;
          }
          final status = await ml.getOfflineRegionStatus(_activeId!);
          if (status.completedResourceSize > maxBytes ||
              status.requiredResourceCount > tileLimit) {
            nativeOversized = true;
            break;
          }
          if (status.isComplete) break;
          if (status.completedResourceCount > lastProgress) {
            lastActivity = DateTime.now();
            lastProgress = status.completedResourceCount;
          }
          if (DateTime.now().difference(lastActivity) >
              const Duration(minutes: 2)) {
            nativeFailed = true;
            break;
          }
          progress = (status.downloadProgress / 100).clamp(0, 1) * .85;
          notifyListeners();
          await Future<void>.delayed(const Duration(milliseconds: 750));
        }
        if (nativeOversized) {
          _cancel = true;
          throw StateError('Tile provider limit exceeded');
        }
        if (nativeFailed && !_stop) throw StateError('Tile download stopped');
      }
      if (_stop) return;

      downloadingPhotos = true;
      progress = null;
      notifyListeners();
      final area = OfflineMapArea(definition.bounds, OfflineMapDetail.standard);
      await for (final page in catalog.placesForOfflineRegion(area.bbox)) {
        for (final place in page) {
          final references = {
            place.coverImageUrl,
            for (final photo in place.images) photo.imageUrl,
          };
          for (final reference in references) {
            if (_stop || !online) {
              _stop = true;
              return;
            }
            await _images.pin(key, reference);
          }
        }
        notifyListeners();
      }
      if (!_stop) await _images.markFinished(key);
    } catch (_) {
      failed = !_stop;
    } finally {
      final id = _activeId;
      if (id != null && (_stop || failed)) await _pauseNative(id);
      if (_cancel) {
        try {
          await _deleteKey(key);
        } catch (_) {
          failed = true;
        }
      }
      try {
        await _images.flush();
        entries = await _readEntries();
      } catch (_) {
        failed = true;
      }
      _activeId = null;
      activeKey = null;
      downloadingPhotos = _working = false;
      notifyListeners();
    }
  }

  Future<bool> _connected() async {
    online = await _network?.isConnected ?? false;
    return online;
  }

  Future<void> _pauseNative(int id) async {
    try {
      await ml.pauseOfflineRegionDownload(id);
    } on PlatformException {
      // A completed or automatically removed pack no longer needs pausing.
    } on MissingPluginException {
      // A stopped native engine no longer needs pausing.
    }
  }

  Future<void> pause() async {
    if (activeKey == null) return;
    _stop = true;
    if (_activeId case final id?) await _pauseNative(id);
  }

  Future<void> cancel() async {
    if (activeKey == null) return;
    _cancel = true;
    await pause();
  }

  Future<void> delete(OfflineMapEntry entry) async {
    if (busy) return;
    _working = true;
    failed = false;
    notifyListeners();
    try {
      await _deleteKey(entry.key);
      entries = await _readEntries();
    } catch (_) {
      failed = true;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> _deleteKey(String key) async {
    for (final region in await ml.getListOfRegions()) {
      if (region.metadata['owner'] == _owner &&
          (region.metadata['key'] ?? 'legacy-${region.id}') == key) {
        await ml.deleteOfflineRegion(region.id);
      }
    }
    await _images.remove(key);
  }

  @override
  void dispose() {
    _connection?.cancel();
    unawaited(pause());
    super.dispose();
  }
}

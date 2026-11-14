import 'dart:async';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/yalla_map_offline_file.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';

/// Explicit native offline packs; ambient caches alone are not offline coverage.
class YallaMapOffline extends ChangeNotifier {
  static final instance = YallaMapOffline();
  static const tileLimit = 2500;
  static const maxBytes = 45 * 1024 * 1024;
  static const userAgent = 'Yalla5roga/1.0 (com.example.yalla_5roga)';
  bool busy = false, failed = false, complete = false;
  double progress = 0;
  int? _active;
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      YallaMapStyle.offlineAllowed;
  static Future<void> configure() async {
    if (!supported) return;
    await ml.setHttpHeaders({'User-Agent': userAgent});
    await ml.setOfflineTileCountLimit(tileLimit);
    await ml.setOfflineMaxConcurrentRequests(
      maxRequests: 4,
      maxRequestsPerHost: 4,
    );
  }

  Future<void> save(ml.LatLngBounds bounds, String style) async {
    if (!supported || busy) return;
    busy = true;
    failed = false;
    complete = false;
    progress = 0;
    notifyListeners();
    final done = Completer<bool>();
    try {
      if (_tileCount(bounds, 14) > tileLimit ||
          bounds.southwest.longitude >= bounds.northeast.longitude) {
        throw StateError('Area too large');
      }
      await configure();
      final variant = sha256
          .convert(utf8.encode(style))
          .toString()
          .substring(0, 16);
      final regions = await ml.getListOfRegions();
      for (final region in regions.where(
        (r) => r.metadata['owner'] == 'yalla5roga',
      )) {
        if (region.metadata['variant'] == variant &&
            _contains(region.definition.bounds, bounds)) {
          if ((await ml.getOfflineRegionStatus(region.id)).isComplete) {
            complete = true;
            progress = 1;
            return;
          }
        }
      }
      // Keep one bounded region; replace only our own packs.
      for (final region in regions.where(
        (r) => r.metadata['owner'] == 'yalla5roga',
      )) {
        await ml.deleteOfflineRegion(region.id);
      }
      final styleUrl = style.trimLeft().startsWith('{')
          ? await persistMapStyle(style, variant)
          : style;
      var oversized = false;
      final region = await ml.downloadOfflineRegion(
        ml.OfflineRegionDefinition(
          bounds: bounds,
          mapStyleUrl: styleUrl,
          minZoom: 0,
          maxZoom: 14,
        ),
        metadata: {'owner': 'yalla5roga', 'variant': variant},
        onEvent: (event) {
          if (event is ml.InProgress) {
            progress = (event.progress / 100).clamp(0, 1);
            oversized =
                event.completedResourceSize > maxBytes ||
                event.requiredResourceCount > tileLimit;
            if (oversized && !done.isCompleted) {
              done.complete(false);
            }
          } else if (event is ml.Success && !done.isCompleted) {
            done.complete(true);
          } else if (event is ml.Error && !done.isCompleted) {
            done.complete(false);
          }
          notifyListeners();
        },
      );
      _active = region.id;
      if (oversized) throw StateError('Pack limit exceeded');
      if (!await done.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => false,
      )) {
        throw StateError('Download failed or exceeded limits');
      }
      complete = true;
      progress = 1;
    } catch (_) {
      failed = true;
      if (_active case final id?) {
        try {
          await ml.pauseOfflineRegionDownload(id);
          await ml.deleteOfflineRegion(id);
        } catch (_) {
          /* Native pack may already be removed. */
        }
      }
    } finally {
      _active = null;
      busy = false;
      notifyListeners();
    }
  }

  static bool _contains(ml.LatLngBounds a, ml.LatLngBounds b) =>
      a.southwest.latitude <= b.southwest.latitude &&
      a.southwest.longitude <= b.southwest.longitude &&
      a.northeast.latitude >= b.northeast.latitude &&
      a.northeast.longitude >= b.northeast.longitude;
  static int _tileCount(ml.LatLngBounds b, int maxZoom) {
    var total = 0;
    for (var z = 0; z <= maxZoom; z++) {
      final n = math.pow(2, z).toDouble();
      int x(double lng) => ((lng + 180) / 360 * n).floor();
      int y(double lat) {
        final r = lat.clamp(-85.051129, 85.051129) * math.pi / 180;
        return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n)
            .floor();
      }

      total +=
          (x(b.northeast.longitude) - x(b.southwest.longitude) + 1).abs() *
          (y(b.southwest.latitude) - y(b.northeast.latitude) + 1).abs();
    }
    return total;
  }
}

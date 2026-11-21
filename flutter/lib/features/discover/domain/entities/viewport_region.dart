import 'dart:math' as math;

/// A non-wrapping geographic rectangle. Wrapped viewports produce two boxes.
class ViewportRegion {
  const ViewportRegion(this.west, this.south, this.east, this.north);
  final double west, south, east, north;
  String get key => '$west,$south,$east,$north';

  static List<ViewportRegion> buffered(String bounds, {double padding = .2}) {
    final [w, s, e, n] = bounds.split(',').map(double.parse).toList();
    final width = e > w ? e - w : e - w + 360;
    final bottom = math.max(-90.0, s - (n - s) * padding);
    final top = math.min(90.0, n + (n - s) * padding);
    final span = width * (1 + 2 * padding);
    if (span >= 360) return [ViewportRegion(-180, bottom, 180, top)];
    final left = (w - width * padding + 180) % 360 - 180;
    final right = left + span;
    if (right <= 180) return [ViewportRegion(left, bottom, right, top)];
    return [
      ViewportRegion(left, bottom, 180, top),
      ViewportRegion(-180, bottom, right - 360, top),
    ];
  }

  Iterable<ViewportRegion> subtract(ViewportRegion other) sync* {
    final l = math.max(west, other.west), r = math.min(east, other.east);
    final b = math.max(south, other.south), t = math.min(north, other.north);
    if (l >= r || b >= t) {
      yield this;
      return;
    }
    if (south < b) yield ViewportRegion(west, south, east, b);
    if (north > t) yield ViewportRegion(west, t, east, north);
    if (west < l) yield ViewportRegion(west, b, l, t);
    if (east > r) yield ViewportRegion(r, b, east, t);
  }
}

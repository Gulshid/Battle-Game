import 'package:game_core/src/constants.dart';
import 'package:game_core/src/trig.dart';

/// Static tile collision map. Integer-only so client and server agree exactly.
class CollisionGrid {
  CollisionGrid({
    required this.width,
    required this.height,
    required List<bool> solid,
  })  : assert(solid.length == width * height, 'solid must be width*height'),
        _solid = List<bool>.unmodifiable(solid);

  /// Builds a grid from ASCII rows. '#' is a wall, anything else is floor.
  factory CollisionGrid.fromRows(List<String> rows) {
    final height = rows.length;
    final width = rows.first.length;
    final solid = <bool>[];
    for (final row in rows) {
      assert(row.length == width, 'all rows must have the same length');
      for (var x = 0; x < width; x++) {
        solid.add(row[x] == '#');
      }
    }
    return CollisionGrid(width: width, height: height, solid: solid);
  }

  final int width;
  final int height;
  final List<bool> _solid;

  /// Tiles outside the map count as solid.
  bool solidAt(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= width || ty >= height) return true;
    return _solid[ty * width + tx];
  }

  /// True if a circle (fixed-point centre and radius) overlaps any wall tile.
  /// Touching exactly (distance == radius) is not a hit.
  bool circleHits(int cx, int cy, int radius) {
    final x0 = (cx - radius) >> kTileShift;
    final x1 = (cx + radius) >> kTileShift;
    final y0 = (cy - radius) >> kTileShift;
    final y1 = (cy + radius) >> kTileShift;
    final r2 = radius * radius;
    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        if (!solidAt(tx, ty)) continue;
        final minX = tx << kTileShift;
        final minY = ty << kTileShift;
        final nx =
            cx < minX ? minX : (cx > minX + kTileSize ? minX + kTileSize : cx);
        final ny =
            cy < minY ? minY : (cy > minY + kTileSize ? minY + kTileSize : cy);
        final dx = cx - nx;
        final dy = cy - ny;
        if (dx * dx + dy * dy < r2) return true;
      }
    }
    return false;
  }

  /// True if no wall tile lies on the straight line between two fixed-point
  /// points (sampled every 8 px). Used by bots and aim assist.
  bool lineClear(int x0, int y0, int x1, int y1) {
    final dx = x1 - x0;
    final dy = y1 - y0;
    final len = isqrt(dx * dx + dy * dy);
    final steps = len ~/ (kTileSize ~/ 4) + 1;
    for (var i = 0; i <= steps; i++) {
      final x = x0 + (dx * i) ~/ steps;
      final y = y0 + (dy * i) ~/ steps;
      if (solidAt(x >> kTileShift, y >> kTileShift)) return false;
    }
    return true;
  }
}

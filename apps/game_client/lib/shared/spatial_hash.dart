class SpatialHash<T> {
  SpatialHash(this.cell);
  final int cell;
  final Map<int, List<T>> _cells = {};

  int _key(int cx, int cy) => (cx & 0xFFFF) | ((cy & 0xFFFF) << 16);

  void clear() {
    for (final l in _cells.values) {
      l.clear();
    }
  }

  void insert(T item, int x, int y, int radius) {
    final x0 = (x - radius) ~/ cell;
    final x1 = (x + radius) ~/ cell;
    final y0 = (y - radius) ~/ cell;
    final y1 = (y + radius) ~/ cell;
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        (_cells[_key(cx, cy)] ??= <T>[]).add(item);
      }
    }
  }

  Iterable<T> query(int x, int y, int radius) sync* {
    final seen = <T>{};
    for (var cy = (y - radius) ~/ cell; cy <= (y + radius) ~/ cell; cy++) {
      for (var cx = (x - radius) ~/ cell; cx <= (x + radius) ~/ cell; cx++) {
        for (final it in _cells[_key(cx, cy)] ?? <T>[]) {
          if (seen.add(it)) yield it;
        }
      }
    }
  }
}

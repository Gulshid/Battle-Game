import 'package:game_core/game_core.dart';

/// Test arena, 24x16 tiles (768x512 px). '#' wall, 'S' spawn, '.' floor.
/// Layout is rotationally symmetric so no spawn has an advantage.
const List<String> kArenaRows = [
  '########################',
  '#......................#',
  '#.S........S.........S.#',
  '#......................#',
  '#.....##........##.....#',
  '#.....##........##.....#',
  '#......................#',
  '#..........##........S.#',
  '#.S........##..........#',
  '#......................#',
  '#.....##........##.....#',
  '#.....##........##.....#',
  '#......................#',
  '#.S.........S........S.#',
  '#......................#',
  '########################',
];

/// Training arena, 28x18 tiles (896x576 px). Rotationally symmetric.
const List<String> kTrainingRows = [
  '############################',
  '#..........................#',
  '#.S........................#',
  '#.........S................#',
  '#..........................#',
  '#.....##...................#',
  '#..S..##...................#',
  '#..........................#',
  '#............##............#',
  '#............##............#',
  '#..........................#',
  '#...................##..S..#',
  '#...................##.....#',
  '#..........................#',
  '#................S.........#',
  '#........................S.#',
  '#..........................#',
  '############################',
];

typedef SpawnPoint = ({int x, int y});

class ArenaMap {
  ArenaMap({required this.grid, required this.spawns});

  /// Parses ASCII rows. Spawn positions are tile centres in fixed-point.
  factory ArenaMap.parse(List<String> rows) {
    final spawns = <SpawnPoint>[];
    for (var ty = 0; ty < rows.length; ty++) {
      for (var tx = 0; tx < rows[ty].length; tx++) {
        if (rows[ty][tx] == 'S') {
          final x = tx * kTileSize + kTileSize ~/ 2;
          final y = ty * kTileSize + kTileSize ~/ 2;
          spawns.add((x: x, y: y));
        }
      }
    }
    return ArenaMap(
      grid: CollisionGrid.fromRows(rows),
      spawns: spawns,
    );
  }

  final CollisionGrid grid;
  final List<SpawnPoint> spawns;
}

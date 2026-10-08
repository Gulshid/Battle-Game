import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

// 5x5 tiles of 32 px = 160 px room. Walls on the border.
final _grid = CollisionGrid.fromRows([
  '#####',
  '#...#',
  '#...#',
  '#...#',
  '#####',
]);
final _sim = Simulation(grid: _grid);

WorldState _start() => const WorldState(
      tick: 0,
      players: {1: PlayerState(id: 1, x: 80 * kFixedOne, y: 80 * kFixedOne)},
    );

WorldState _run(WorldState s, int ticks, int mx, int my) {
  var w = s;
  for (var i = 0; i < ticks; i++) {
    w = _sim.step(w, {
      1: InputCommand(tick: i, seq: i, moveX: mx, moveY: my),
    });
  }
  return w;
}

void main() {
  test('player stops exactly at the wall', () {
    final p = _run(_start(), 100, 127, 0).players[1]!;
    expect(p.x, 128 * kFixedOne - kPlayerRadius);
    expect(p.y, 80 * kFixedOne);
  });

  test('player slides along a wall when moving diagonally', () {
    final p = _run(_start(), 10, 127, 127).players[1]!;
    expect(p.x, 128 * kFixedOne - kPlayerRadius);
    expect(p.y, greaterThan(80 * kFixedOne));
  });

  test('player never ends up inside a wall', () {
    var w = _start();
    for (var i = 0; i < 400; i++) {
      final mx = (i * 37) % 255 - 127;
      final my = (i * 91) % 255 - 127;
      w = _sim.step(w, {
        1: InputCommand(tick: i, seq: i, moveX: mx, moveY: my),
      });
      final p = w.players[1]!;
      expect(
        _grid.circleHits(p.x, p.y, kPlayerRadius),
        isFalse,
        reason: 'tick $i',
      );
    }
  });

  test('collision is deterministic', () {
    final a = _run(_start(), 200, 100, -60).players[1]!;
    final b = _run(_start(), 200, 100, -60).players[1]!;
    expect((a.x, a.y), (b.x, b.y));
  });

  test('tiles outside the map are solid', () {
    expect(_grid.solidAt(-1, 0), isTrue);
    expect(_grid.solidAt(5, 5), isTrue);
    expect(_grid.solidAt(2, 2), isFalse);
  });
}

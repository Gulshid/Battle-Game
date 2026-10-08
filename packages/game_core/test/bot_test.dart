import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'support/test_config.dart';

/// Runs bots against each other and returns the final state and all events.
({WorldState state, List<GameEvent> events}) _fight(
  int ticks, {
  int seed = 3,
  Simulation? simulation,
}) {
  final s = simulation ?? sim;
  var w = world([(1, 0, 200, 200), (2, 1, 500, 200), (3, 2, 350, 350)]);
  final bots = [
    for (final id in [1, 2, 3])
      BotBrain(
        playerId: id,
        config: testConfig,
        grid: s.grid,
        seed: seed,
      ),
  ];
  final events = <GameEvent>[];
  for (var t = 0; t < ticks; t++) {
    final inputs = {for (final b in bots) b.playerId: b.think(w, t)};
    w = s.step(w, inputs);
    events.addAll(w.events);
  }
  return (state: w, events: events);
}

void main() {
  test('bots find each other and deal damage', () {
    final r = _fight(30 * 30);
    final dealt = r.events.whereType<DamageEvent>().length;
    expect(dealt, greaterThan(5));
  });

  test('bot matches are deterministic for a given seed', () {
    expect(hashState(_fight(600).state), hashState(_fight(600).state));
  });

  test('different seeds behave differently', () {
    expect(
      hashState(_fight(600, seed: 1).state),
      isNot(hashState(_fight(600, seed: 2).state)),
    );
  });

  test('bots respect walls (never inside one)', () {
    final grid = CollisionGrid.fromRows([
      '##############',
      '#............#',
      '#....##......#',
      '#....##......#',
      '#............#',
      '#............#',
      '##############',
    ]);
    final s = Simulation(grid: grid, config: testConfig);
    var w = WorldState(
      tick: 0,
      players: {
        1: s.createPlayer(id: 1, classId: 0, x: 80 * px, y: 80 * px),
        2: s.createPlayer(id: 2, classId: 1, x: 350 * px, y: 150 * px),
      },
    );
    final bots = [
      BotBrain(playerId: 1, config: testConfig, grid: grid),
      BotBrain(playerId: 2, config: testConfig, grid: grid),
    ];
    for (var t = 0; t < 900; t++) {
      w = s.step(w, {for (final b in bots) b.playerId: b.think(w, t)});
      for (final p in w.players.values) {
        expect(grid.circleHits(p.x, p.y, kPlayerRadius), isFalse);
      }
    }
  });

  test('a lone bot idles', () {
    final w = world([(1, 0, 200, 200)]);
    final c = BotBrain(playerId: 1, config: testConfig).think(w, 0);
    expect((c.moveX, c.moveY, c.buttons), (0, 0, 0));
  });
}

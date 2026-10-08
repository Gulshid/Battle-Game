import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// Full-stack check with the real data and the real arena: three bots play a
/// free-for-all for 90 simulated seconds.
class _Match {
  _Match() {
    arena = ArenaMap.parse(kArenaRows);
    config = loadGameConfig();
    sim = Simulation(grid: arena.grid, config: config, spawns: arena.spawns);
    final players = <int, PlayerState>{};
    for (var i = 0; i < 3; i++) {
      final sp = arena.spawns[i * 2];
      players[i + 1] = sim.createPlayer(
        id: i + 1,
        classId: i,
        x: sp.x,
        y: sp.y,
      );
    }
    state = WorldState(tick: 0, players: players, rng: 0xBEEF);
    bots = [
      for (var i = 1; i <= 3; i++)
        BotBrain(playerId: i, config: config, grid: arena.grid, seed: 9),
    ];
  }

  late final ArenaMap arena;
  late final GameConfig config;
  late final Simulation sim;
  late WorldState state;
  late final List<BotBrain> bots;

  Map<int, InputCommand> step() {
    final inputs = {
      for (final b in bots) b.playerId: b.think(state, state.tick),
    };
    state = sim.step(state, inputs);
    return inputs;
  }
}

void main() {
  test('3-bot free-for-all: damage happens and nobody enters a wall', () {
    final m = _Match();
    var damage = 0;
    var kills = 0;
    for (var t = 0; t < 90 * kSimHz; t++) {
      m.step();
      damage += m.state.events.whereType<DamageEvent>().length;
      kills += m.state.events.whereType<KillEvent>().length;
      for (final p in m.state.players.values) {
        if (p.alive) {
          expect(
            m.arena.grid.circleHits(p.x, p.y, kPlayerRadius),
            isFalse,
            reason: 'player ${p.id} in a wall at tick ${m.state.tick}',
          );
        }
      }
    }
    expect(damage, greaterThan(20));
    // Not asserting kills (bots are not tuned yet) but make it visible.
    // ignore: avoid_print
    print('bot match: $damage hits, $kills kills');
  });

  test('a recorded bot match replays to the same hash', () {
    final m = _Match();
    final rec = ReplayRecorder(initial: m.state, dataVersion: kDataVersion);
    for (var t = 0; t < 40 * kSimHz; t++) {
      final inputs = m.step();
      rec.record(inputs, m.state);
    }
    final replay = rec.finish();
    final result = ReplayPlayer.play(m.sim, replay);
    expect(result.finalHash, hashState(m.state));
    // And through the file format.
    final again = ReplayPlayer.play(m.sim, Replay.fromBytes(replay.toBytes()));
    expect(again.finalHash, replay.finalHash);
  });
}

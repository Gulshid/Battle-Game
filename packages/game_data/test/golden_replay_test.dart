import 'dart:io';
import 'dart:typed_data';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// Golden replay: a recorded match that must keep reproducing the same state
/// hashes. If it fails, the game rules changed. If that was intended, delete
/// test/golden/arena_ffa.replay and run the tests once to record a new one,
/// then commit it. If it was NOT intended, you just caught a regression.
const _path = 'test/golden/arena_ffa.replay';

Simulation _sim() {
  final arena = ArenaMap.parse(kArenaRows);
  return Simulation(
    grid: arena.grid,
    config: loadGameConfig(),
    spawns: arena.spawns,
  );
}

Replay _recordWithBots() {
  final arena = ArenaMap.parse(kArenaRows);
  final config = loadGameConfig();
  final sim = _sim();
  var s = WorldState(
    tick: 0,
    players: {
      for (var i = 0; i < 4; i++)
        i + 1: sim.createPlayer(
          id: i + 1,
          classId: i % 3,
          x: arena.spawns[i * 2].x,
          y: arena.spawns[i * 2].y,
        ),
    },
    rng: 0x600D,
  );
  final bots = [
    for (var i = 1; i <= 4; i++)
      BotBrain(playerId: i, config: config, grid: arena.grid, seed: 5),
  ];
  final rec = ReplayRecorder(initial: s, dataVersion: kDataVersion);
  for (var t = 0; t < 60 * kSimHz; t++) {
    final inputs = {for (final b in bots) b.playerId: b.think(s, s.tick)};
    s = sim.step(s, inputs);
    rec.record(inputs, s);
  }
  return rec.finish();
}

void main() {
  test('golden replay reproduces its recorded hashes', () {
    final file = File(_path);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsBytesSync(_recordWithBots().toBytes());
      // ignore: avoid_print
      print('Recorded a new golden replay at $_path. Commit it.');
      return;
    }
    final replay = Replay.fromBytes(Uint8List.fromList(file.readAsBytesSync()));
    expect(replay.dataVersion, kDataVersion, reason: 'data version changed');
    final result = ReplayPlayer.play(_sim(), replay);
    expect(result.finalHash, replay.finalHash);
    expect(result.finalState.tick, 60 * kSimHz);
  });

  test('recording the same bot match twice gives identical files', () {
    expect(_recordWithBots().toBytes(), _recordWithBots().toBytes());
  });
}

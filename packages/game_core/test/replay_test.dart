import 'dart:typed_data';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'support/test_config.dart';

Replay _record({int ticks = 240}) {
  final rng = Rng(77);
  var w = world([(1, 0, 200, 200), (2, 1, 260, 200), (3, 2, 230, 260)]);
  final rec = ReplayRecorder(initial: w, dataVersion: 1);
  for (var t = 0; t < ticks; t++) {
    final inputs = {
      for (final id in [1, 2, 3])
        id: cmd(
          // Hold each control for a while so the compression is exercised.
          moveX: ((t ~/ 20 + id) % 3 - 1) * 127,
          moveY: ((t ~/ 30 + id) % 3 - 1) * 127,
          buttons: rng.chance(30) ? rng.nextInt(16) : 0,
          aim: (t ~/ 10 * 17 + id * 40) & 255,
        ),
    };
    w = sim.step(w, inputs);
    rec.record(inputs, w);
  }
  return rec.finish();
}

void main() {
  test('replaying twice gives the identical state hash', () {
    final r = _record();
    final a = ReplayPlayer.play(sim, r);
    final b = ReplayPlayer.play(sim, r);
    expect(a.finalHash, b.finalHash);
    expect(a.finalHash, r.finalHash);
    expect(a.finalState.tick, 240);
  });

  test('checkpoints are recorded every interval', () {
    final r = _record();
    expect(r.checkpoints.keys.toList()..sort(), [
      30, 60, 90, 120, 150, 180, 210, 240,
    ]);
  });

  test('replay survives serialisation', () {
    final r = _record();
    final bytes = r.toBytes();
    final back = Replay.fromBytes(bytes);
    expect(back.frames.length, r.frames.length);
    expect(back.finalHash, r.finalHash);
    expect(ReplayPlayer.play(sim, back).finalHash, r.finalHash);
    expect(back.toBytes(), bytes);
  });

  test('input compression keeps the file small', () {
    final r = _record();
    final perFrame = r.toBytes().length / r.frames.length;
    expect(perFrame, lessThan(15)); // uncompressed: 16 bytes
  });

  test('a tampered input is detected as a desync', () {
    final back = Replay.fromBytes(_record().toBytes());
    back.frames[10][1] = cmd(moveX: -127, moveY: 127, buttons: 15);
    expect(
      () => ReplayPlayer.play(sim, back),
      throwsA(isA<ReplayDesync>()),
    );
  });

  test('a different ruleset is detected as a desync', () {
    final r = _record();
    // Same inputs, different rules (every class is half as fast).
    final slow = GameConfig(
      classes: [
        for (final c in testConfig.classes)
          ClassDef(
            id: c.id,
            name: c.name,
            maxHp: c.maxHp,
            armorPct: c.armorPct,
            moveSpeed: c.moveSpeed ~/ 2,
            accel: c.accel,
            friction: c.friction,
            abilities: c.abilities,
            dashCooldownTicks: c.dashCooldownTicks,
            dashTicks: c.dashTicks,
            dashSpeed: c.dashSpeed,
            dashIframeTicks: c.dashIframeTicks,
          ),
      ],
    );
    expect(
      () => ReplayPlayer.play(Simulation(config: slow), r),
      throwsA(isA<ReplayDesync>()),
    );
  });

  test('garbage is not a replay', () {
    expect(
      () => Replay.fromBytes(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsFormatException,
    );
  });
}

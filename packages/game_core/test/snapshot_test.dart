import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'support/test_config.dart';

const _codec = SnapshotCodec();

WorldState _chaos(int ticks, {void Function(WorldState)? onTick}) {
  final rng = Rng(11);
  return run(
    world([(1, 0, 200, 200), (2, 1, 250, 200), (3, 2, 225, 250)]),
    ticks,
    (t) => {
      for (final id in [1, 2, 3])
        id: cmd(
          moveX: rng.range(-127, 127),
          moveY: rng.range(-127, 127),
          buttons: rng.nextInt(16),
          aim: rng.nextInt(256),
        ),
    },
    onTick: onTick,
  );
}

void main() {
  test('full snapshot round trips exactly on every tick of a fight', () {
    _chaos(300, onTick: (s) {
      final bytes = _codec.encode(s);
      final back = _codec.decode(bytes);
      expect(hashState(back), hashState(s), reason: 'tick ${s.tick}');
      expect(_codec.encode(back), bytes);
    });
  });

  test('every field survives, including extreme values', () {
    final p = PlayerState(
      id: 9,
      x: 123456,
      y: 7,
      team: 3,
      classId: 2,
      vx: -2000,
      vy: 2047,
      kbx: -5,
      kby: 6,
      facing: 255,
      hp: 100000,
      alive: false,
      respawnTick: 99999,
      invulnTicks: 4,
      cooldowns: [1, 200, 300, 4000],
      castSlot: 2,
      castLeft: 3,
      castAim: 77,
      channelLeft: 41,
      dashLeft: 2,
      dashAim: 200,
      iframeTicks: 5,
      statusTicks: [1, 2, 3, 4, 5],
      statusMag: [0, 40, 3, 25, 20],
      burnSource: 7,
      kills: 12,
      deaths: 3,
    );
    final s = WorldState(
      tick: 1000000,
      players: {9: p},
      projectiles: [
        Projectile(
          id: 4,
          owner: 9,
          team: 3,
          classId: 1,
          slot: 3,
          x: 1000,
          y: -20,
          vx: -192,
          vy: 100,
          life: 12,
        ),
      ],
      rng: 0xDEADBEEF,
      nextProjectileId: 5,
    );
    final back = _codec.decode(_codec.encode(s));
    final q = back.players[9]!;
    expect(q.hp, 100000);
    expect(q.vx, -2000);
    expect(q.statusMag, [0, 40, 3, 25, 20]);
    expect(q.cooldowns, [1, 200, 300, 4000]);
    expect((q.castSlot, q.burnSource, q.team), (2, 7, 3));
    expect(back.projectiles.single.y, -20);
    expect(back.rng, 0xDEADBEEF);
    expect((back.tick, back.nextProjectileId), (1000000, 5));
    expect(hashState(back), hashState(s));
  });

  test('values outside the format are rejected, not silently clipped', () {
    final s = world([(1, 0, 200, 200)]);
    s.players[1]!.x = 1 << 21;
    expect(() => _codec.encode(s), throwsRangeError);
  });

  test('corrupt data throws a FormatException', () {
    final bytes = _codec.encode(world([(1, 0, 1, 1)]));
    bytes[0] = 99; // wrong version
    expect(() => _codec.decode(bytes), throwsFormatException);
  });

  test('a snapshot of 8 players is small', () {
    final s = world([
      for (var i = 1; i <= 8; i++) (i, i % 3, 100 + i * 20, 200),
    ]);
    final bytes = _codec.encode(s);
    // Budget from the roadmap: < 10 KB/s down at 15 snapshots/s = 680 B each.
    expect(bytes.length, lessThan(680));
  });

  group('delta', () {
    test('applying a delta rebuilds the newer state', () {
      WorldState? prev;
      _chaos(200, onTick: (s) {
        final base = prev;
        prev = s;
        if (base == null) return;
        final delta = _codec.encodeDelta(base, s);
        final rebuilt = _codec.applyDelta(base, delta);
        expect(hashState(rebuilt), hashState(s), reason: 'tick ${s.tick}');
      });
    });

    test('unchanged entities cost nothing', () {
      final a = world([(1, 0, 200, 200), (2, 0, 400, 200), (3, 0, 600, 200)]);
      final b = sim.step(a, {1: cmd(moveX: 127)}); // only player 1 moves
      final full = _codec.encode(b).length;
      final delta = _codec.encodeDelta(a, b);
      expect(delta.length, lessThan(full));
      final rebuilt = _codec.applyDelta(a, delta);
      expect(hashState(rebuilt), hashState(b));
    });

    test('players joining and leaving are carried', () {
      final a = world([(1, 0, 200, 200), (2, 0, 400, 200)]);
      final b = sim.withPlayer(
        sim.withoutPlayer(a, 1),
        sim.createPlayer(id: 5, classId: 1, x: 100 * px, y: 100 * px),
      );
      final rebuilt = _codec.applyDelta(a, _codec.encodeDelta(a, b));
      expect(rebuilt.players.keys.toList()..sort(), [2, 5]);
      expect(hashState(rebuilt), hashState(b));
    });

    test('a delta only applies to the state it was made from', () {
      final a = world([(1, 0, 200, 200)]);
      final b = sim.step(a, {1: cmd(moveX: 127)});
      final c = sim.step(b, {1: cmd(moveX: 127)});
      final delta = _codec.encodeDelta(a, b);
      expect(() => _codec.applyDelta(c, delta), throwsStateError);
    });
  });
}

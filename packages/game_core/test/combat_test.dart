import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'support/test_config.dart';

Map<int, InputCommand> _none(int _) => const <int, InputCommand>{};

void main() {
  group('melee', () {
    test('slash hits an enemy in front, applies armor and knockback', () {
      final w = run(
        world([(1, 0, 200, 200), (2, 0, 230, 200)]),
        3,
        (_) => {1: cmd(buttons: btn(kBtnAttack))},
      );
      final p2 = w.players[2]!;
      // 14 raw damage, 10% armor -> 12.
      expect(p2.hp, 140 - 12);
      expect(p2.kbx, 32);
      expect(w.events.whereType<DamageEvent>().single.amount, 12);
    });

    test('slash misses an enemy behind the caster', () {
      final w = run(
        world([(1, 0, 200, 200), (2, 0, 170, 200)]),
        5,
        (_) => {1: cmd(buttons: btn(kBtnAttack))},
      );
      expect(w.players[2]!.hp, 140);
    });

    test('slash misses an enemy that is out of reach', () {
      final w = run(
        world([(1, 0, 200, 200), (2, 0, 270, 200)]),
        5,
        (_) => {1: cmd(buttons: btn(kBtnAttack))},
      );
      expect(w.players[2]!.hp, 140);
    });

    test('cooldown limits the attack rate', () {
      final start = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      Map<int, InputCommand> hold(int _) =>
          {1: cmd(buttons: btn(kBtnAttack))};
      expect(run(start, 17, hold).players[2]!.hp, 140 - 12);
      expect(run(start, 18, hold).players[2]!.hp, 140 - 24);
    });

    test('teammates are never hit', () {
      final s = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      final s2 = sim.withPlayer(
        s,
        sim.createPlayer(id: 2, classId: 0, x: 230 * px, y: 200 * px, team: 1),
      );
      final w = run(s2, 6, (_) => {1: cmd(buttons: btn(kBtnAttack))});
      expect(w.players[2]!.hp, 140);
    });
  });

  group('projectiles', () {
    test('arrow travels and hits', () {
      final start = world([(1, 1, 200, 200), (2, 0, 320, 200)]);
      Map<int, InputCommand> fire(int _) => {1: cmd(buttons: btn(kBtnAttack))};
      expect(run(start, 4, fire).projectiles.length, 1);
      final w = run(start, 12, fire);
      expect(w.players[2]!.hp, 140 - 10); // 12 raw, 10% armor
      expect(w.projectiles, isEmpty);
    });

    test('triple shot fans out', () {
      final w = run(
        world([(1, 1, 200, 200)]),
        4,
        (_) => {1: cmd(buttons: btn(kBtnAbility1))},
      );
      final vy = w.projectiles.map((p) => p.vy).toList();
      expect(vy.length, 3);
      expect(vy[0], lessThan(0));
      expect(vy[1], 0);
      expect(vy[2], greaterThan(0));
    });

    test('walls stop projectiles', () {
      final grid = CollisionGrid.fromRows([
        '#########',
        '#...#...#',
        '#...#...#',
        '#...#...#',
        '#########',
      ]);
      final s = Simulation(grid: grid, config: testConfig);
      final w = run(
        world([(1, 1, 80, 80), (2, 0, 208, 80)]),
        40,
        (_) => {1: cmd(buttons: btn(kBtnAttack))},
        simulation: s,
      );
      expect(w.players[2]!.hp, 140);
    });

    test('dash i-frames let a projectile pass through', () {
      final w = run(
        world([(1, 1, 200, 200), (2, 0, 320, 200)]),
        20,
        (t) => {
          1: cmd(buttons: btn(kBtnAttack)),
          if (t == 6) 2: cmd(moveY: 127, buttons: btn(kBtnDash)),
        },
      );
      expect(w.players[2]!.hp, 140);
    });
  });

  group('dash', () {
    test('dash covers 60 px with i-frames and a cooldown', () {
      final start = world([(1, 0, 200, 200)]);
      final one = run(start, 1, (_) => {1: cmd(buttons: btn(kBtnDash))});
      final p = one.players[1]!;
      expect(p.dashLeft, 4);
      expect(p.iframeTicks, 5);
      expect(p.cooldowns[kDashSlot], 75);
      expect(one.events.whereType<DashEvent>().length, 1);

      final five = run(start, 5, (_) => {1: cmd(buttons: btn(kBtnDash))});
      expect(five.players[1]!.x, 200 * px + 5 * 192);
      expect(five.players[1]!.dashLeft, 0);
    });
  });

  group('damage pipeline', () {
    test('shield absorbs before HP', () {
      final w = run(
        world([(1, 0, 200, 200), (2, 0, 230, 200)]),
        3,
        (_) => {
          1: cmd(buttons: btn(kBtnAttack)),
          2: cmd(buttons: btn(kBtnAbility2)),
        },
      );
      final p2 = w.players[2]!;
      expect(p2.hp, 140);
      expect(p2.statusMag[EffectType.shield.index], 40 - 12);
      expect(p2.statusMag[EffectType.haste.index], 20);
      final dmg = w.events.whereType<DamageEvent>().single;
      expect((dmg.amount, dmg.absorbed), (0, 12));
    });

    test('kill credits the attacker and respawns the victim', () {
      final spawns = <SpawnPos>[
        (x: 100 * px, y: 100 * px),
        (x: 300 * px, y: 300 * px),
      ];
      final s = Simulation(config: testConfig, spawns: spawns);
      final start = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      start.players[2]!.hp = 10;
      Map<int, InputCommand> hold(int _) =>
          {1: cmd(buttons: btn(kBtnAttack))};

      final dead = run(start, 3, hold, simulation: s);
      expect(dead.players[2]!.alive, isFalse);
      expect(dead.players[1]!.kills, 1);
      expect(dead.players[2]!.deaths, 1);
      final kill = dead.events.whereType<KillEvent>().single;
      expect((kill.killerId, kill.victimId), (1, 2));

      final back = run(start, 63, hold, simulation: s);
      final p2 = back.players[2]!;
      expect(p2.alive, isTrue);
      expect(p2.hp, 140);
      expect(p2.invulnTicks, 20);
      expect(spawns.map((e) => (e.x, e.y)), contains((p2.x, p2.y)));
      expect(back.events.whereType<RespawnEvent>().length, 1);
    });

    test('two players can kill each other on the same tick', () {
      final start = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      start.players[1]!.hp = 5;
      start.players[2]!.hp = 5;
      final w = run(
        start,
        3,
        (_) => {
          1: cmd(buttons: btn(kBtnAttack)),
          2: cmd(buttons: btn(kBtnAttack), aim: 128),
        },
      );
      expect(w.players[1]!.alive, isFalse);
      expect(w.players[2]!.alive, isFalse);
      expect(w.players[1]!.kills, 1);
      expect(w.players[2]!.kills, 1);
    });

    test('spawn protection blocks damage', () {
      final start = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      start.players[2]!.invulnTicks = 50;
      final w = run(
        start,
        5,
        (_) => {1: cmd(buttons: btn(kBtnAttack))},
      );
      expect(w.players[2]!.hp, 140);
    });
  });

  group('status effects', () {
    test('stun blocks movement, slow limits speed afterwards', () {
      final start = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      Map<int, InputCommand> inputs(int _) => {
            1: cmd(buttons: btn(kBtnAbility1)),
            2: cmd(moveX: 127),
          };
      final stunned = run(start, 12, inputs).players[2]!;
      expect(stunned.hasEffect(EffectType.stun), isTrue);
      expect(stunned.vx, 0);

      final later = run(start, 40, inputs).players[2]!;
      expect(later.hasEffect(EffectType.stun), isFalse);
      expect(later.hasEffect(EffectType.slow), isTrue);
      expect(later.vx, greaterThan(0));
      // 88 top speed, 40% slow -> 52.
      expect(later.vx, lessThanOrEqualTo(52));
    });

    test('re-applying keeps the longer duration and stronger magnitude', () {
      // A hit with a weaker, longer slow (shockwave: 40% for 60 ticks)
      // lands on a target that already has a stronger, shorter one.
      final s2 = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      s2.players[2]!
        ..statusTicks[EffectType.slow.index] = 10
        ..statusMag[EffectType.slow.index] = 50;
      final out = run(
        s2,
        6,
        (_) => {1: cmd(buttons: btn(kBtnAbility1))},
      ).players[2]!;
      expect(out.statusMag[EffectType.slow.index], 50);
      expect(out.statusTicks[EffectType.slow.index], greaterThan(30));
    });

    test('burn ticks 4 times and credits the caster', () {
      final w = run(
        world([(1, 2, 200, 200), (2, 0, 300, 200)]),
        70,
        (t) => {if (t == 0) 1: cmd(buttons: btn(kBtnAttack))},
        onTick: null,
      );
      // 16 raw -> 14, then 4 burn ticks of 3 raw -> 2 each.
      expect(w.players[2]!.hp, 140 - 14 - 4 * 2);
      expect(w.players[2]!.hasEffect(EffectType.burn), isFalse);
    });

    test('burn damage is flagged as over time', () {
      var dots = 0;
      run(
        world([(1, 2, 200, 200), (2, 0, 300, 200)]),
        70,
        (t) => {if (t == 0) 1: cmd(buttons: btn(kBtnAttack))},
        onTick: (s) {
          dots += s.events
              .whereType<DamageEvent>()
              .where((e) => e.overTime && e.attackerId == 1)
              .length;
        },
      );
      expect(dots, 4);
    });
  });

  group('channel', () {
    test('holding the key pulses 5 times', () {
      final w = run(
        world([(1, 2, 200, 200), (2, 0, 240, 200)]),
        70,
        (_) => {1: cmd(buttons: btn(kBtnAbility2))},
      );
      expect(w.players[2]!.hp, 140 - 5 * 5);
    });

    test('releasing the key cancels the channel', () {
      final w = run(
        world([(1, 2, 200, 200), (2, 0, 240, 200)]),
        70,
        (t) => {if (t < 20) 1: cmd(buttons: btn(kBtnAbility2))},
      );
      expect(w.players[2]!.hp, 140 - 5);
    });

    test('channelling slows movement', () {
      final w = run(
        world([(1, 2, 200, 200)]),
        20,
        (_) => {1: cmd(moveX: 127, buttons: btn(kBtnAbility2))},
      );
      // 40% of 90 = 36 per tick top speed while casting.
      expect(w.players[1]!.vx, lessThanOrEqualTo(36));
    });
  });

  group('rules of the simulation', () {
    test('oversized input cannot make a player faster', () {
      final w = run(
        world([(1, 0, 200, 200)]),
        30,
        (_) => {1: cmd(moveX: 1000, moveY: 0)},
      );
      expect(w.players[1]!.vx, lessThanOrEqualTo(88));
    });

    test('step never mutates the state it is given', () {
      final start = world([(1, 0, 200, 200), (2, 0, 230, 200)]);
      final before = hashState(start);
      sim.step(start, {1: cmd(moveX: 127, buttons: btn(kBtnAttack))});
      expect(hashState(start), before);
    });

    test('same inputs always give the same state hash', () {
      int play() {
        final rng = Rng(42);
        final w = run(
          world([(1, 0, 200, 200), (2, 1, 260, 200), (3, 2, 230, 260)]),
          300,
          (t) => {
            for (final id in [1, 2, 3])
              id: cmd(
                moveX: rng.range(-127, 127),
                moveY: rng.range(-127, 127),
                buttons: rng.nextInt(16),
                aim: rng.nextInt(256),
              ),
          },
        );
        return hashState(w);
      }

      expect(play(), play());
    });

    test('hp stays inside its bounds in a chaotic fight', () {
      final rng = Rng(7);
      run(
        world([(1, 0, 200, 200), (2, 1, 240, 200), (3, 2, 220, 240)]),
        400,
        (t) => {
          for (final id in [1, 2, 3])
            id: cmd(
              moveX: rng.range(-127, 127),
              moveY: rng.range(-127, 127),
              buttons: rng.nextInt(16),
              aim: rng.nextInt(256),
            ),
        },
        onTick: (s) {
          for (final p in s.players.values) {
            final max = testConfig.classOf(p.classId).maxHp;
            expect(p.hp, inInclusiveRange(0, max));
            if (!p.alive) expect(p.hp, 0);
          }
        },
      );
    });

    test('empty input map is fine (everyone idles)', () {
      final w = run(world([(1, 0, 200, 200)]), 10, _none);
      expect(w.tick, 10);
      expect(w.players[1]!.x, 200 * px);
    });
  });
}

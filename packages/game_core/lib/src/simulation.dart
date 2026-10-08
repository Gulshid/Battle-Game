import 'package:game_core/src/collision_grid.dart';
import 'package:game_core/src/constants.dart';
import 'package:game_core/src/defs.dart';
import 'package:game_core/src/events.dart';
import 'package:game_core/src/input_command.dart';
import 'package:game_core/src/rng.dart';
import 'package:game_core/src/state.dart';
import 'package:game_core/src/trig.dart';

typedef SpawnPos = ({int x, int y});

/// The whole game ruleset as one pure function:
/// `step(state, inputs) -> next state`.
///
/// Per-tick system order (never reorder without bumping the replay version):
///  1. timers: respawn, cooldowns, spawn protection, statuses, burn
///  2. input: dash / ability start, then movement (accel, friction, knockback)
///  3. casts: windup, resolve melee / aoe / projectile spawn, channel pulses
///  4. projectiles: move, hit walls and players
///  5. hits: every hit collected in 3 and 4 is applied through the damage
///     pipeline (armor -> shield -> HP -> knockback -> effects)
///
/// Hits are collected first and applied last, so two players who kill each
/// other in the same tick both land their hit (a trade) instead of the lower
/// id winning.
class Simulation {
  const Simulation({
    this.grid,
    this.config = GameConfig.fallback,
    this.spawns = const <SpawnPos>[],
  });

  /// Static map collision. Null means an open plane (used in unit tests).
  final CollisionGrid? grid;
  final GameConfig config;

  /// Respawn points (fixed-point).
  final List<SpawnPos> spawns;

  /// A full-health player of [classId] at ([x], [y]) in fixed-point.
  PlayerState createPlayer({
    required int id,
    required int classId,
    required int x,
    required int y,
    int? team,
  }) {
    final cls = config.classOf(classId);
    return PlayerState(
      id: id,
      x: x,
      y: y,
      team: team,
      classId: classId,
      hp: cls.maxHp,
    );
  }

  /// Copy of [s] with [p] added (or replaced).
  WorldState withPlayer(WorldState s, PlayerState p) {
    final w = s.copy();
    w.players[p.id] = p;
    return w;
  }

  /// Copy of [s] without player [id].
  WorldState withoutPlayer(WorldState s, int id) {
    final w = s.copy();
    w.players.remove(id);
    return w;
  }

  /// Pure function: same state + same inputs => same next state.
  WorldState step(WorldState s, Map<int, InputCommand> inputs) =>
      _Step(this, s.copy(), inputs).run();
}

class _Hit {
  const _Hit({
    required this.attacker,
    required this.victim,
    required this.damage,
    this.def,
    this.dirX = 0,
    this.dirY = 0,
    this.overTime = false,
  });

  final int attacker;
  final int victim;
  final int damage;
  final AbilityDef? def;

  /// Direction attacker -> victim, scaled by [kTrigScale].
  final int dirX;
  final int dirY;
  final bool overTime;
}

class _Step {
  _Step(this.sim, this.w, this.inputs)
      : now = w.tick + 1,
        rng = Rng(w.rng),
        ids = w.players.keys.toList()..sort();

  final Simulation sim;
  final WorldState w;
  final Map<int, InputCommand> inputs;

  /// Tick number of the state this step produces.
  final int now;
  final Rng rng;
  final List<int> ids;
  final List<_Hit> hits = <_Hit>[];

  GameConfig get cfg => sim.config;
  CollisionGrid? get grid => sim.grid;
  List<GameEvent> get events => w.events;

  WorldState run() {
    for (final id in ids) {
      _updateTimers(w.players[id]!);
    }
    for (final id in ids) {
      final p = w.players[id]!;
      if (p.alive) _actAndMove(p, inputs[id] ?? InputCommand.idle);
    }
    for (final id in ids) {
      final p = w.players[id]!;
      if (p.alive) _updateCast(p);
    }
    _updateProjectiles();
    for (final h in hits) {
      _applyHit(h);
    }
    w
      ..tick = now
      ..rng = rng.state;
    return w;
  }

  // ------------------------------------------------------------ 1. timers

  void _updateTimers(PlayerState p) {
    if (!p.alive) {
      if (now >= p.respawnTick) _respawn(p);
      return;
    }
    for (var i = 0; i < kSlotCount; i++) {
      if (p.cooldowns[i] > 0) p.cooldowns[i]--;
    }
    if (p.invulnTicks > 0) p.invulnTicks--;
    if (p.iframeTicks > 0) p.iframeTicks--;
    for (var e = 0; e < kEffectCount; e++) {
      if (p.statusTicks[e] <= 0) continue;
      if (e == EffectType.burn.index &&
          p.statusTicks[e] % kBurnIntervalTicks == 0) {
        hits.add(
          _Hit(
            attacker: p.burnSource,
            victim: p.id,
            damage: p.statusMag[e],
            overTime: true,
          ),
        );
      }
      p.statusTicks[e]--;
      if (p.statusTicks[e] == 0) p.statusMag[e] = 0;
    }
  }

  void _respawn(PlayerState p) {
    if (sim.spawns.isNotEmpty) {
      final sp = _pickSpawn(p.id);
      p
        ..x = sp.x
        ..y = sp.y;
    }
    final cls = cfg.classOf(p.classId);
    p
      ..hp = cls.maxHp
      ..alive = true
      ..vx = 0
      ..vy = 0
      ..kbx = 0
      ..kby = 0
      ..castSlot = -1
      ..castLeft = 0
      ..channelLeft = 0
      ..dashLeft = 0
      ..iframeTicks = 0
      ..burnSource = -1
      ..invulnTicks = cfg.spawnInvulnTicks;
    for (var i = 0; i < kSlotCount; i++) {
      p.cooldowns[i] = 0;
    }
    for (var e = 0; e < kEffectCount; e++) {
      p.statusTicks[e] = 0;
      p.statusMag[e] = 0;
    }
    events.add(RespawnEvent(now, playerId: p.id, x: p.x, y: p.y));
  }

  /// One of the two spawns farthest from every living player.
  SpawnPos _pickSpawn(int selfId) {
    final sp = sim.spawns;
    var best = 0;
    var second = -1;
    var bestScore = -1;
    var secondScore = -1;
    for (var i = 0; i < sp.length; i++) {
      var score = 1 << 40;
      for (final id in ids) {
        final o = w.players[id]!;
        if (id == selfId || !o.alive) continue;
        final dx = o.x - sp[i].x;
        final dy = o.y - sp[i].y;
        final d2 = dx * dx + dy * dy;
        if (d2 < score) score = d2;
      }
      if (score > bestScore) {
        second = best;
        secondScore = bestScore;
        best = i;
        bestScore = score;
      } else if (score > secondScore) {
        second = i;
        secondScore = score;
      }
    }
    final pickSecond = second >= 0 && sp.length > 1 && rng.nextInt(2) == 1;
    return sp[pickSecond ? second : best];
  }

  // ------------------------------------------------- 2. input and movement

  static bool _held(int buttons, int bit) => (buttons >> bit) & 1 == 1;

  void _actAndMove(PlayerState p, InputCommand c) {
    final cls = cfg.classOf(p.classId);
    final stunned = p.hasEffect(EffectType.stun);
    var mx = stunned ? 0 : c.moveX;
    var my = stunned ? 0 : c.moveY;
    final lenSq = mx * mx + my * my;
    if (lenSq > 127 * 127) {
      final len = isqrt(lenSq);
      mx = (mx * 127) ~/ len;
      my = (my * 127) ~/ len;
    }
    final btn = stunned ? 0 : c.buttons;
    final aim = c.aimAngle & 255;

    // Releasing the key (or being stunned) ends a channel.
    if (p.castSlot >= 0 &&
        p.channelLeft > 0 &&
        !_held(btn, p.castSlot)) {
      _cancelCast(p);
    }

    // Dash.
    if (cls.dashTicks > 0 &&
        _held(btn, kBtnDash) &&
        p.dashLeft == 0 &&
        p.castSlot < 0 &&
        p.cooldowns[kDashSlot] == 0) {
      final moving = mx != 0 || my != 0;
      p
        ..dashAim = moving ? angleOf(mx, my) : p.facing
        ..dashLeft = cls.dashTicks
        ..cooldowns[kDashSlot] = cls.dashCooldownTicks;
      if (cls.dashIframeTicks > p.iframeTicks) {
        p.iframeTicks = cls.dashIframeTicks;
      }
      events.add(DashEvent(now, playerId: p.id, x: p.x, y: p.y));
    }

    // Abilities: ability2 has priority over ability1 over the attack.
    if (p.dashLeft == 0 && p.castSlot < 0) {
      for (var slot = cls.abilities.length - 1; slot >= 0; slot--) {
        if (_held(btn, slot) && p.cooldowns[slot] == 0) {
          final def = cls.abilities[slot];
          p
            ..castSlot = slot
            ..castLeft = def.castTicks < 1 ? 1 : def.castTicks
            ..castAim = aim
            ..cooldowns[slot] = def.cooldownTicks;
          break;
        }
      }
    }

    if (mx != 0 || my != 0 || (btn & 7) != 0) p.facing = aim;

    // Speed modifiers.
    var pct = 100 + p.statusMag[EffectType.haste.index];
    pct -= p.statusMag[EffectType.slow.index];
    if (pct < kMinSpeedPct) pct = kMinSpeedPct;
    if (p.castSlot >= 0) {
      pct = (pct * cls.abilities[p.castSlot].castMovePct) ~/ 100;
    }

    var dashEnded = false;
    if (p.dashLeft > 0) {
      p
        ..vx = (cosOf(p.dashAim) * cls.dashSpeed) ~/ kTrigScale
        ..vy = (sinOf(p.dashAim) * cls.dashSpeed) ~/ kTrigScale
        ..dashLeft -= 1;
      dashEnded = p.dashLeft == 0;
    } else {
      final maxSpeed = (cls.moveSpeed * pct) ~/ 100;
      final tx = (mx * maxSpeed) ~/ 127;
      final ty = (my * maxSpeed) ~/ 127;
      final rate = (mx != 0 || my != 0) ? cls.accel : cls.friction;
      _approach(p, tx, ty, rate);
    }

    _moveBody(p);

    if (dashEnded) {
      // Leave the dash at running speed instead of stopping dead.
      p
        ..vx = (cosOf(p.dashAim) * cls.moveSpeed) ~/ kTrigScale
        ..vy = (sinOf(p.dashAim) * cls.moveSpeed) ~/ kTrigScale;
    }
  }

  /// Moves the velocity towards the target by at most [rate] per tick.
  static void _approach(PlayerState p, int tx, int ty, int rate) {
    final dx = tx - p.vx;
    final dy = ty - p.vy;
    final d2 = dx * dx + dy * dy;
    if (d2 <= rate * rate) {
      p
        ..vx = tx
        ..vy = ty;
    } else {
      final len = isqrt(d2);
      p
        ..vx += (dx * rate) ~/ len
        ..vy += (dy * rate) ~/ len;
    }
  }

  void _moveBody(PlayerState p) {
    final dx = p.vx + p.kbx;
    final dy = p.vy + p.kby;
    var nx = p.x + dx;
    var ny = p.y + dy;
    final g = grid;
    if (g != null) {
      // Axis-separated movement so players slide along walls.
      final oldY = p.y;
      nx = _moveAxis(p.x, dx, (v) => g.circleHits(v, oldY, kPlayerRadius));
      final newX = nx;
      ny = _moveAxis(p.y, dy, (v) => g.circleHits(newX, v, kPlayerRadius));
    }
    if (nx != p.x + dx) {
      p
        ..vx = 0
        ..kbx = 0;
    }
    if (ny != p.y + dy) {
      p
        ..vy = 0
        ..kby = 0;
    }
    p
      ..x = nx
      ..y = ny
      ..kbx = _decay(p.kbx)
      ..kby = _decay(p.kby);
  }

  static int _decay(int k) {
    final v = (k * kKnockbackDecayNum) ~/ 256;
    return v.abs() < kKnockbackStop ? 0 : v;
  }

  /// Moves [pos] by [delta] but stops exactly at the wall (integer binary
  /// search, deterministic). [hits] tells whether a candidate position
  /// overlaps a wall.
  static int _moveAxis(int pos, int delta, bool Function(int) hits) {
    if (delta == 0) return pos;
    if (!hits(pos + delta)) return pos + delta;
    final sign = delta < 0 ? -1 : 1;
    var lo = 0; // known free
    var hi = delta.abs(); // known blocked
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (hits(pos + sign * mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return pos + sign * lo;
  }

  // ---------------------------------------------------------- 3. casting

  void _cancelCast(PlayerState p) {
    p
      ..castSlot = -1
      ..castLeft = 0
      ..channelLeft = 0;
  }

  void _updateCast(PlayerState p) {
    if (p.castSlot < 0) return;
    final def = cfg.classOf(p.classId).abilities[p.castSlot];

    if (p.channelLeft > 0) {
      p.channelLeft--;
      final elapsed = def.channelTicks - p.channelLeft;
      if (def.pulseEveryTicks > 0 && elapsed % def.pulseEveryTicks == 0) {
        _emitCast(p, def);
        _areaHit(p, def);
      }
      if (p.channelLeft == 0) p.castSlot = -1;
      return;
    }

    if (p.castLeft > 0) p.castLeft--;
    if (p.castLeft > 0) return;

    // Windup finished: the ability takes effect now.
    switch (def.kind) {
      case AbilityKind.melee:
      case AbilityKind.aoe:
        _emitCast(p, def);
        _areaHit(p, def);
      case AbilityKind.projectile:
        _emitCast(p, def);
        _spawnProjectiles(p, def);
      case AbilityKind.self:
        _emitCast(p, def);
      case AbilityKind.channel:
        break; // pulses start next tick
    }
    for (final e in def.selfEffects) {
      _applyEffect(p, e, p.id);
    }
    if (def.kind == AbilityKind.channel && def.channelTicks > 0) {
      p.channelLeft = def.channelTicks;
    } else {
      p.castSlot = -1;
    }
  }

  void _emitCast(PlayerState p, AbilityDef def) {
    events.add(
      CastEvent(
        now,
        playerId: p.id,
        slot: p.castSlot,
        kind: def.kind,
        x: p.x,
        y: p.y,
        aim: p.castAim,
        range: def.range,
        arcHalf: def.arcHalf,
        offset: def.offset,
      ),
    );
  }

  /// Collects hits on every enemy inside the ability's arc / circle.
  void _areaHit(PlayerState p, AbilityDef def) {
    if (def.damage <= 0 && def.effects.isEmpty) return;
    final aim = p.castAim;
    final ca = cosOf(aim);
    final sa = sinOf(aim);
    final cx = p.x + (ca * def.offset) ~/ kTrigScale;
    final cy = p.y + (sa * def.offset) ~/ kTrigScale;
    final reach = def.range + kPlayerRadius;
    for (final id in ids) {
      final o = w.players[id]!;
      if (id == p.id || !o.alive || o.team == p.team || o.untargetable) {
        continue;
      }
      final dx = o.x - cx;
      final dy = o.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 > reach * reach) continue;
      final len = isqrt(d2);
      if (def.arcHalf < 128 && len > 0) {
        final dot = dx * ca + dy * sa;
        if (dot < cosOf(def.arcHalf) * len) continue;
      }
      hits.add(
        _Hit(
          attacker: p.id,
          victim: o.id,
          damage: def.damage,
          def: def,
          dirX: len == 0 ? ca : (dx * kTrigScale) ~/ len,
          dirY: len == 0 ? sa : (dy * kTrigScale) ~/ len,
        ),
      );
    }
  }

  void _spawnProjectiles(PlayerState p, AbilityDef def) {
    final n = def.projCount < 1 ? 1 : def.projCount;
    for (var i = 0; i < n; i++) {
      final off = n == 1
          ? 0
          : -def.projSpreadHalf + (2 * def.projSpreadHalf * i) ~/ (n - 1);
      final a = (p.castAim + off) & 255;
      final ca = cosOf(a);
      final sa = sinOf(a);
      final startDist = kPlayerRadius + def.projRadius;
      w.projectiles.add(
        Projectile(
          id: w.nextProjectileId++,
          owner: p.id,
          team: p.team,
          classId: p.classId,
          slot: p.castSlot,
          x: p.x + (ca * startDist) ~/ kTrigScale,
          y: p.y + (sa * startDist) ~/ kTrigScale,
          vx: (ca * def.projSpeed) ~/ kTrigScale,
          vy: (sa * def.projSpeed) ~/ kTrigScale,
          life: def.projLifeTicks,
        ),
      );
    }
  }

  // -------------------------------------------------------- 4. projectiles

  void _updateProjectiles() {
    final alive = <Projectile>[];
    final g = grid;
    for (final pr in w.projectiles) {
      final def = cfg.classOf(pr.classId).abilities[pr.slot];
      pr
        ..x += pr.vx
        ..y += pr.vy
        ..life -= 1;
      if (g != null && g.circleHits(pr.x, pr.y, def.projRadius)) {
        events.add(ImpactEvent(now, x: pr.x, y: pr.y));
        continue;
      }
      final reach = def.projRadius + kPlayerRadius;
      var victim = -1;
      for (final id in ids) {
        final o = w.players[id]!;
        if (!o.alive || o.team == pr.team || o.untargetable) continue;
        final dx = o.x - pr.x;
        final dy = o.y - pr.y;
        if (dx * dx + dy * dy <= reach * reach) {
          victim = id;
          break;
        }
      }
      if (victim >= 0) {
        final speed = isqrt(pr.vx * pr.vx + pr.vy * pr.vy);
        hits.add(
          _Hit(
            attacker: pr.owner,
            victim: victim,
            damage: def.damage,
            def: def,
            dirX: speed == 0 ? 0 : (pr.vx * kTrigScale) ~/ speed,
            dirY: speed == 0 ? 0 : (pr.vy * kTrigScale) ~/ speed,
          ),
        );
        events.add(ImpactEvent(now, x: pr.x, y: pr.y));
        continue;
      }
      if (pr.life <= 0) {
        events.add(ImpactEvent(now, x: pr.x, y: pr.y));
        continue;
      }
      alive.add(pr);
    }
    w.projectiles = alive;
  }

  // ------------------------------------------------------ 5. damage pipeline

  void _applyHit(_Hit h) {
    final v = w.players[h.victim];
    if (v == null || !v.alive || v.untargetable) return;
    final attacker = w.players[h.attacker];
    final cls = cfg.classOf(v.classId);

    if (h.damage > 0) {
      // 1. armor
      var dmg = (h.damage * (100 - cls.armorPct)) ~/ 100;
      if (dmg < 1) dmg = 1;
      // 2. shield
      var absorbed = 0;
      final si = EffectType.shield.index;
      if (v.statusTicks[si] > 0) {
        absorbed = dmg < v.statusMag[si] ? dmg : v.statusMag[si];
        v.statusMag[si] -= absorbed;
        dmg -= absorbed;
        if (v.statusMag[si] == 0) v.statusTicks[si] = 0;
      }
      // 3. hp
      v.hp -= dmg;
      events.add(
        DamageEvent(
          now,
          victimId: v.id,
          attackerId: h.attacker,
          amount: dmg,
          absorbed: absorbed,
          x: v.x,
          y: v.y,
          overTime: h.overTime,
        ),
      );
      if (v.hp <= 0) _kill(v, attacker);
    }

    final def = h.def;
    if (v.alive && def != null) {
      if (def.knockback > 0) {
        v
          ..kbx = (h.dirX * def.knockback) ~/ kTrigScale
          ..kby = (h.dirY * def.knockback) ~/ kTrigScale;
      }
      for (final e in def.effects) {
        _applyEffect(v, e, h.attacker);
      }
    }
  }

  void _kill(PlayerState v, PlayerState? killer) {
    v
      ..hp = 0
      ..alive = false
      ..respawnTick = now + cfg.respawnTicks
      ..deaths += 1
      ..vx = 0
      ..vy = 0
      ..kbx = 0
      ..kby = 0
      ..dashLeft = 0
      ..iframeTicks = 0;
    _cancelCast(v);
    if (killer != null && killer.id != v.id && killer.team != v.team) {
      killer.kills += 1;
    }
    events.add(
      KillEvent(
        now,
        victimId: v.id,
        killerId: killer?.id ?? -1,
        x: v.x,
        y: v.y,
      ),
    );
  }

  void _applyEffect(PlayerState v, EffectDef e, int source) {
    final i = e.type.index;
    if (e.durationTicks > v.statusTicks[i]) v.statusTicks[i] = e.durationTicks;
    if (e.magnitude > v.statusMag[i]) v.statusMag[i] = e.magnitude;
    if (e.type == EffectType.burn) v.burnSource = source;
    if (e.type == EffectType.stun) _cancelCast(v);
  }
}

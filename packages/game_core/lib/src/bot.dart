import 'package:game_core/src/collision_grid.dart';
import 'package:game_core/src/constants.dart';
import 'package:game_core/src/defs.dart';
import 'package:game_core/src/input_command.dart';
import 'package:game_core/src/rng.dart';
import 'package:game_core/src/state.dart';
import 'package:game_core/src/trig.dart';

/// How good a bot is. Used later for matchmaking backfill tiers.
class BotDifficulty {
  const BotDifficulty({
    required this.thinkTicks,
    required this.aimErrorUnits,
    required this.abilityChancePct,
  });

  /// Bots only re-decide their strategy every this many ticks (reaction time).
  final int thinkTicks;

  /// Random aim error in byte angles (+-).
  final int aimErrorUnits;

  /// Chance per decision to use a ready special ability.
  final int abilityChancePct;

  static const easy = BotDifficulty(
    thinkTicks: 12,
    aimErrorUnits: 10,
    abilityChancePct: 25,
  );
  static const normal = BotDifficulty(
    thinkTicks: 6,
    aimErrorUnits: 5,
    abilityChancePct: 50,
  );
  static const hard = BotDifficulty(
    thinkTicks: 3,
    aimErrorUnits: 2,
    abilityChancePct: 80,
  );
}

enum BotMode { idle, chase, strafe, kite, flee }

/// Finite state machine that turns a [WorldState] into an [InputCommand].
///
/// A bot keeps its own memory and its own seeded [Rng], and it is NOT part of
/// the simulation: its output is just input data. That is why replays record
/// inputs and never need to re-run the bots.
class BotBrain {
  BotBrain({
    required this.playerId,
    required this.config,
    this.grid,
    this.difficulty = BotDifficulty.normal,
    int seed = 1,
  }) : _rng = Rng(seed * 7919 + playerId * 104729 + 1);

  final int playerId;
  final GameConfig config;
  final CollisionGrid? grid;
  final BotDifficulty difficulty;
  final Rng _rng;

  BotMode mode = BotMode.idle;
  int _nextThink = 0;
  int _strafeDir = 1;
  int _aimError = 0;
  int _moveX = 0;
  int _moveY = 0;
  int _buttons = 0;

  InputCommand think(WorldState s, int seq) {
    final me = s.players[playerId];
    if (me == null || !me.alive) {
      mode = BotMode.idle;
      return InputCommand(tick: s.tick, seq: seq);
    }
    final cls = config.classOf(me.classId);
    final target = _nearestEnemy(s, me);
    if (target == null || cls.abilities.isEmpty) {
      mode = BotMode.idle;
      return InputCommand(tick: s.tick, seq: seq, aimAngle: me.facing);
    }

    final dx = target.x - me.x;
    final dy = target.y - me.y;
    final dist = isqrt(dx * dx + dy * dy);
    final g = grid;
    final visible = g == null || g.lineClear(me.x, me.y, target.x, target.y);

    if (s.tick >= _nextThink) {
      _nextThink = s.tick + difficulty.thinkTicks;
      _decide(s, me, cls, target, dist, visible);
    }

    // Channels need the key held for as long as they run.
    var buttons = _buttons;
    if (me.castSlot >= 0 && me.channelLeft > 0) buttons |= 1 << me.castSlot;
    _buttons = 0; // presses are one-shot; cooldowns gate repeats

    final aim = (angleOf(dx, dy) + _aimError) & 255;
    return InputCommand(
      tick: s.tick,
      seq: seq,
      moveX: _moveX,
      moveY: _moveY,
      buttons: buttons,
      aimAngle: aim,
    );
  }

  PlayerState? _nearestEnemy(WorldState s, PlayerState me) {
    PlayerState? best;
    var bestD2 = 0;
    for (final id in s.sortedPlayerIds) {
      final o = s.players[id]!;
      if (id == me.id || !o.alive || o.team == me.team) continue;
      final dx = o.x - me.x;
      final dy = o.y - me.y;
      final d2 = dx * dx + dy * dy;
      if (best == null || d2 < bestD2) {
        best = o;
        bestD2 = d2;
      }
    }
    return best;
  }

  void _decide(
    WorldState s,
    PlayerState me,
    ClassDef cls,
    PlayerState target,
    int dist,
    bool visible,
  ) {
    final attack = cls.abilities[0];
    final reach = attack.reach;
    final melee = attack.kind == AbilityKind.melee;
    final desiredMax = melee ? (reach * 3) ~/ 4 : (reach * 7) ~/ 10;
    final desiredMin = melee ? 0 : (reach * 4) ~/ 10;
    final hpPct = (me.hp * 100) ~/ cls.maxHp;

    if (hpPct < 25 && dist < reach * 2) {
      mode = BotMode.flee;
    } else if (!visible || dist > desiredMax) {
      mode = BotMode.chase;
    } else if (dist < desiredMin) {
      mode = BotMode.kite;
    } else {
      mode = BotMode.strafe;
      if (_rng.chance(25)) _strafeDir = -_strafeDir;
    }

    final dx = target.x - me.x;
    final dy = target.y - me.y;
    var ux = 0;
    var uy = 0;
    switch (mode) {
      case BotMode.chase:
        ux = dx;
        uy = dy;
      case BotMode.kite:
      case BotMode.flee:
        ux = -dx;
        uy = -dy;
      case BotMode.strafe:
        ux = -dy * _strafeDir;
        uy = dx * _strafeDir;
      case BotMode.idle:
        break;
    }
    final len = isqrt(ux * ux + uy * uy);
    _moveX = len == 0 ? 0 : (ux * 127) ~/ len;
    _moveY = len == 0 ? 0 : (uy * 127) ~/ len;

    _aimError = difficulty.aimErrorUnits == 0
        ? 0
        : _rng.range(-difficulty.aimErrorUnits, difficulty.aimErrorUnits);

    var buttons = 0;
    // Attack whenever it can land.
    if (visible && dist <= (reach * 9) ~/ 10 && me.cooldowns[0] == 0) {
      buttons |= 1 << kBtnAttack;
    }
    // Specials.
    for (var slot = 1; slot < cls.abilities.length; slot++) {
      final def = cls.abilities[slot];
      if (me.cooldowns[slot] > 0 || !_rng.chance(difficulty.abilityChancePct)) {
        continue;
      }
      final useful = switch (def.kind) {
        AbilityKind.self => hpPct < 70 || dist < 150 * kFixedOne,
        _ => visible && dist <= def.reach,
      };
      if (useful) buttons |= 1 << slot;
    }
    // Escape or close the gap with the dash.
    if (me.cooldowns[kDashSlot] == 0 && cls.dashTicks > 0) {
      if (mode == BotMode.flee && dist < 120 * kFixedOne) {
        buttons |= 1 << kBtnDash;
      } else if (mode == BotMode.chase && dist > 260 * kFixedOne) {
        buttons |= 1 << kBtnDash;
      }
    }
    _buttons = buttons;
  }
}

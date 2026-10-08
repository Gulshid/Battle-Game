import 'package:game_core/src/constants.dart';
import 'package:game_core/src/defs.dart';
import 'package:game_core/src/events.dart';

/// Mutable data holder. Only [Simulation.step] mutates states, and it always
/// works on a fresh copy, so any state you receive from `step` is safe to
/// keep and treat as immutable (client history, server rewind buffer).
class PlayerState {
  PlayerState({
    required this.id,
    required this.x,
    required this.y,
    int? team,
    this.classId = 0,
    this.vx = 0,
    this.vy = 0,
    this.kbx = 0,
    this.kby = 0,
    this.facing = 0,
    this.hp = 100,
    this.alive = true,
    this.respawnTick = 0,
    this.invulnTicks = 0,
    List<int>? cooldowns,
    this.castSlot = -1,
    this.castLeft = 0,
    this.castAim = 0,
    this.channelLeft = 0,
    this.dashLeft = 0,
    this.dashAim = 0,
    this.iframeTicks = 0,
    List<int>? statusTicks,
    List<int>? statusMag,
    this.burnSource = -1,
    this.kills = 0,
    this.deaths = 0,
  })  : team = team ?? id,
        cooldowns = cooldowns ?? List<int>.filled(kSlotCount, 0),
        statusTicks = statusTicks ?? List<int>.filled(kEffectCount, 0),
        statusMag = statusMag ?? List<int>.filled(kEffectCount, 0);

  final int id;
  final int team;
  int classId;

  int x; // fixed-point (1/16 px)
  int y;
  int vx; // self-propelled velocity, fixed-point per tick
  int vy;
  int kbx; // knockback velocity (decays)
  int kby;
  int facing; // 0..255

  int hp;
  bool alive;

  /// Absolute tick at which a dead player comes back.
  int respawnTick;

  /// Spawn protection, counts down.
  int invulnTicks;

  /// Ticks left per slot (see [kSlotCount]).
  final List<int> cooldowns;

  /// Slot being cast or channelled, -1 when idle.
  int castSlot;
  int castLeft; // windup ticks left
  int castAim; // aim locked when the cast started
  int channelLeft;

  int dashLeft;
  int dashAim;

  /// Dash i-frames (and any other temporary untargetability).
  int iframeTicks;

  /// Ticks left / magnitude per [EffectType]. Invariant: ticks == 0 means
  /// magnitude == 0.
  final List<int> statusTicks;
  final List<int> statusMag;

  /// Who applied the current burn (for kill credit), -1 if none.
  int burnSource;

  int kills;
  int deaths;

  bool hasEffect(EffectType t) => statusTicks[t.index] > 0;

  bool get untargetable => iframeTicks > 0 || invulnTicks > 0;

  PlayerState copy() => PlayerState(
        id: id,
        x: x,
        y: y,
        team: team,
        classId: classId,
        vx: vx,
        vy: vy,
        kbx: kbx,
        kby: kby,
        facing: facing,
        hp: hp,
        alive: alive,
        respawnTick: respawnTick,
        invulnTicks: invulnTicks,
        cooldowns: List<int>.of(cooldowns),
        castSlot: castSlot,
        castLeft: castLeft,
        castAim: castAim,
        channelLeft: channelLeft,
        dashLeft: dashLeft,
        dashAim: dashAim,
        iframeTicks: iframeTicks,
        statusTicks: List<int>.of(statusTicks),
        statusMag: List<int>.of(statusMag),
        burnSource: burnSource,
        kills: kills,
        deaths: deaths,
      );
}

class Projectile {
  Projectile({
    required this.id,
    required this.owner,
    required this.team,
    required this.classId,
    required this.slot,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
  });

  final int id;
  final int owner;
  final int team;

  /// Class and slot of the ability that fired it (damage/effects live there).
  final int classId;
  final int slot;

  int x;
  int y;
  final int vx;
  final int vy;
  int life; // ticks left

  Projectile copy() => Projectile(
        id: id,
        owner: owner,
        team: team,
        classId: classId,
        slot: slot,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        life: life,
      );
}

class WorldState {
  WorldState({
    required this.tick,
    required this.players,
    List<Projectile>? projectiles,
    this.rng = 1,
    this.nextProjectileId = 1,
    List<GameEvent>? events,
  })  : projectiles = projectiles ?? <Projectile>[],
        events = events ?? <GameEvent>[];

  int tick;
  final Map<int, PlayerState> players;

  /// Always sorted by id (ids are handed out in increasing order).
  List<Projectile> projectiles;

  /// State of the world-owned [Rng].
  int rng;
  int nextProjectileId;

  /// Events produced by the step that created this state. Output only: they
  /// are not part of the snapshot or of the state hash.
  final List<GameEvent> events;

  List<int> get sortedPlayerIds => players.keys.toList()..sort();

  WorldState copy() => WorldState(
        tick: tick,
        players: <int, PlayerState>{
          for (final e in players.entries) e.key: e.value.copy(),
        },
        projectiles: <Projectile>[for (final p in projectiles) p.copy()],
        rng: rng,
        nextProjectileId: nextProjectileId,
      );
}

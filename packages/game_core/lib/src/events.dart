import 'package:game_core/src/defs.dart';

/// Things that happened during one simulation step. The renderer, audio and
/// HUD react to these; the simulation never reads them back.
sealed class GameEvent {
  const GameEvent(this.tick);

  /// The tick of the state this event belongs to.
  final int tick;
}

/// An ability took effect (melee swing, AoE blast, projectile launch, pulse).
final class CastEvent extends GameEvent {
  const CastEvent(
    super.tick, {
    required this.playerId,
    required this.slot,
    required this.kind,
    required this.x,
    required this.y,
    required this.aim,
    required this.range,
    required this.arcHalf,
    required this.offset,
  });

  final int playerId;
  final int slot;
  final AbilityKind kind;

  /// Caster position (fixed-point).
  final int x;
  final int y;
  final int aim;
  final int range;
  final int arcHalf;
  final int offset;
}

final class DashEvent extends GameEvent {
  const DashEvent(
    super.tick, {
    required this.playerId,
    required this.x,
    required this.y,
  });

  final int playerId;
  final int x;
  final int y;
}

final class DamageEvent extends GameEvent {
  const DamageEvent(
    super.tick, {
    required this.victimId,
    required this.attackerId,
    required this.amount,
    required this.absorbed,
    required this.x,
    required this.y,
    required this.overTime,
  });

  final int victimId;
  final int attackerId;

  /// HP actually removed (after armor and shield).
  final int amount;

  /// Damage soaked up by a shield.
  final int absorbed;
  final int x;
  final int y;

  /// True for burn ticks.
  final bool overTime;
}

final class KillEvent extends GameEvent {
  const KillEvent(
    super.tick, {
    required this.victimId,
    required this.killerId,
    required this.x,
    required this.y,
  });

  final int victimId;
  final int killerId;
  final int x;
  final int y;
}

/// A projectile hit a wall, a player, or ran out of life.
final class ImpactEvent extends GameEvent {
  const ImpactEvent(super.tick, {required this.x, required this.y});

  final int x;
  final int y;
}

final class RespawnEvent extends GameEvent {
  const RespawnEvent(
    super.tick, {
    required this.playerId,
    required this.x,
    required this.y,
  });

  final int playerId;
  final int x;
  final int y;
}

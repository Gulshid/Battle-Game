import 'package:game_core/src/constants.dart';

/// Status effects. The enum index is the slot inside [PlayerState].
///
/// Stacking rule (one rule for all five): re-applying an effect keeps the
/// LONGER duration and the STRONGER magnitude. There is never more than one
/// instance per type.
enum EffectType {
  /// Cannot move on purpose, cast or dash. Cancels a cast in progress.
  stun,

  /// Magnitude = percent speed reduction.
  slow,

  /// Magnitude = damage every [kBurnIntervalTicks].
  burn,

  /// Magnitude = remaining damage it can absorb.
  shield,

  /// Magnitude = percent speed increase.
  haste,
}

const int kEffectCount = 5;

enum AbilityKind {
  /// Arc in front of the caster, instant on cast completion.
  melee,

  /// Spawns one or more projectiles.
  projectile,

  /// Circle at [AbilityDef.offset] in front of the caster.
  aoe,

  /// Hold the button: repeated circle pulses around the caster.
  channel,

  /// Only applies [AbilityDef.selfEffects].
  self,
}

class EffectDef {
  const EffectDef({
    required this.type,
    required this.durationTicks,
    this.magnitude = 0,
  });

  final EffectType type;
  final int durationTicks;
  final int magnitude;
}

/// All values are already converted to ticks and fixed-point (game_data does
/// the conversion from milliseconds and pixels when it loads the JSON).
class AbilityDef {
  const AbilityDef({
    required this.id,
    required this.kind,
    required this.cooldownTicks,
    this.castTicks = 0,
    this.damage = 0,
    this.range = 0,
    this.arcHalf = 128,
    this.offset = 0,
    this.projSpeed = 0,
    this.projRadius = 0,
    this.projLifeTicks = 0,
    this.projCount = 1,
    this.projSpreadHalf = 0,
    this.knockback = 0,
    this.channelTicks = 0,
    this.pulseEveryTicks = 0,
    this.castMovePct = 100,
    this.effects = const <EffectDef>[],
    this.selfEffects = const <EffectDef>[],
  });

  final String id;
  final AbilityKind kind;
  final int cooldownTicks;

  /// Windup before the effect happens. 0 or 1 means "this tick".
  final int castTicks;
  final int damage;

  /// Melee reach / AoE radius / channel radius (fixed-point).
  final int range;

  /// Half of the arc width in byte angles. 128 = full circle.
  final int arcHalf;

  /// AoE centre distance in front of the caster (fixed-point).
  final int offset;

  final int projSpeed; // fixed-point per tick
  final int projRadius;
  final int projLifeTicks;
  final int projCount;
  final int projSpreadHalf; // byte angles, outer shots deviate by this much

  /// Initial knockback speed (fixed-point per tick, decays by ~0.8/tick).
  final int knockback;

  final int channelTicks;
  final int pulseEveryTicks;

  /// Percent of normal speed while casting / channelling.
  final int castMovePct;

  /// Applied to enemies that are hit.
  final List<EffectDef> effects;

  /// Applied to the caster when the ability is used.
  final List<EffectDef> selfEffects;

  /// Maximum useful distance, used by bots and UI.
  int get reach => kind == AbilityKind.projectile
      ? projSpeed * projLifeTicks
      : range + offset;
}

class ClassDef {
  const ClassDef({
    required this.id,
    required this.name,
    required this.maxHp,
    required this.armorPct,
    required this.moveSpeed,
    required this.accel,
    required this.friction,
    required this.abilities,
    required this.dashCooldownTicks,
    required this.dashTicks,
    required this.dashSpeed,
    required this.dashIframeTicks,
  });

  final int id;
  final String name;
  final int maxHp;

  /// Percent damage reduction, 0..90.
  final int armorPct;

  /// Top speed in fixed-point per tick.
  final int moveSpeed;

  /// Speed gained per tick while an input is held / lost while it is not.
  final int accel;
  final int friction;

  /// Up to three abilities: attack, ability1, ability2.
  final List<AbilityDef> abilities;

  final int dashCooldownTicks;
  final int dashTicks; // 0 = class cannot dash
  final int dashSpeed; // fixed-point per tick
  final int dashIframeTicks;
}

class GameConfig {
  const GameConfig({
    required this.classes,
    this.respawnTicks = 3 * kSimHz,
    this.spawnInvulnTicks = 45,
  });

  /// A single plain class with no abilities. Used by movement-only tests.
  static const GameConfig fallback = GameConfig(
    classes: <ClassDef>[
      ClassDef(
        id: 0,
        name: 'Test',
        maxHp: 100,
        armorPct: 0,
        moveSpeed: kMoveSpeedPerTick,
        accel: 32,
        friction: 48,
        abilities: <AbilityDef>[],
        dashCooldownTicks: 0,
        dashTicks: 0,
        dashSpeed: 0,
        dashIframeTicks: 0,
      ),
    ],
  );

  final List<ClassDef> classes;
  final int respawnTicks;
  final int spawnInvulnTicks;

  ClassDef classOf(int id) => classes[id];
}

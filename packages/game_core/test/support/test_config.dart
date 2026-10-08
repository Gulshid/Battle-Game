import 'package:game_core/game_core.dart';

const int px = kFixedOne;

const AbilityDef slash = AbilityDef(
  id: 'slash',
  kind: AbilityKind.melee,
  cooldownTicks: 15,
  castTicks: 3,
  damage: 14,
  range: 40 * px,
  arcHalf: 36,
  knockback: 32,
);

const AbilityDef shockwave = AbilityDef(
  id: 'shockwave',
  kind: AbilityKind.aoe,
  cooldownTicks: 120,
  castTicks: 6,
  damage: 18,
  range: 70 * px,
  knockback: 64,
  effects: <EffectDef>[
    EffectDef(type: EffectType.slow, durationTicks: 60, magnitude: 40),
    EffectDef(type: EffectType.stun, durationTicks: 20),
  ],
);

const AbilityDef bulwark = AbilityDef(
  id: 'bulwark',
  kind: AbilityKind.self,
  cooldownTicks: 300,
  selfEffects: <EffectDef>[
    EffectDef(type: EffectType.shield, durationTicks: 90, magnitude: 40),
    EffectDef(type: EffectType.haste, durationTicks: 90, magnitude: 20),
  ],
);

const AbilityDef arrow = AbilityDef(
  id: 'arrow',
  kind: AbilityKind.projectile,
  cooldownTicks: 18,
  castTicks: 4,
  damage: 12,
  projSpeed: 192,
  projRadius: 5 * px,
  projLifeTicks: 30,
);

const AbilityDef triple = AbilityDef(
  id: 'triple',
  kind: AbilityKind.projectile,
  cooldownTicks: 150,
  castTicks: 4,
  damage: 8,
  projSpeed: 192,
  projRadius: 5 * px,
  projLifeTicks: 30,
  projCount: 3,
  projSpreadHalf: 12,
);

const AbilityDef fireball = AbilityDef(
  id: 'fireball',
  kind: AbilityKind.projectile,
  cooldownTicks: 24,
  castTicks: 4,
  damage: 16,
  projSpeed: 144,
  projRadius: 7 * px,
  projLifeTicks: 36,
  effects: <EffectDef>[
    EffectDef(type: EffectType.burn, durationTicks: 60, magnitude: 3),
  ],
);

const AbilityDef storm = AbilityDef(
  id: 'storm',
  kind: AbilityKind.channel,
  cooldownTicks: 360,
  castTicks: 3,
  damage: 6,
  range: 60 * px,
  channelTicks: 60,
  pulseEveryTicks: 12,
  castMovePct: 40,
);

const ClassDef fighter = ClassDef(
  id: 0,
  name: 'Fighter',
  maxHp: 140,
  armorPct: 10,
  moveSpeed: 88,
  accel: 29,
  friction: 44,
  abilities: <AbilityDef>[slash, shockwave, bulwark],
  dashCooldownTicks: 75,
  dashTicks: 5,
  dashSpeed: 192,
  dashIframeTicks: 5,
);

const ClassDef shooter = ClassDef(
  id: 1,
  name: 'Shooter',
  maxHp: 90,
  armorPct: 0,
  moveSpeed: 99,
  accel: 33,
  friction: 50,
  abilities: <AbilityDef>[arrow, triple, bulwark],
  dashCooldownTicks: 60,
  dashTicks: 6,
  dashSpeed: 160,
  dashIframeTicks: 3,
);

const ClassDef caster = ClassDef(
  id: 2,
  name: 'Caster',
  maxHp: 80,
  armorPct: 0,
  moveSpeed: 90,
  accel: 30,
  friction: 45,
  abilities: <AbilityDef>[fireball, shockwave, storm],
  dashCooldownTicks: 90,
  dashTicks: 4,
  dashSpeed: 256,
  dashIframeTicks: 4,
);

const GameConfig testConfig = GameConfig(
  classes: <ClassDef>[fighter, shooter, caster],
  respawnTicks: 60,
  spawnInvulnTicks: 20,
);

const Simulation sim = Simulation(config: testConfig);

/// World with the given players on an open plane. [at] values are pixels.
WorldState world(List<(int id, int classId, int xPx, int yPx)> players) {
  final map = <int, PlayerState>{};
  for (final p in players) {
    map[p.$1] = sim.createPlayer(
      id: p.$1,
      classId: p.$2,
      x: p.$3 * px,
      y: p.$4 * px,
    );
  }
  return WorldState(tick: 0, players: map);
}

InputCommand cmd({
  int moveX = 0,
  int moveY = 0,
  int buttons = 0,
  int aim = 0,
}) =>
    InputCommand(
      tick: 0,
      seq: 0,
      moveX: moveX,
      moveY: moveY,
      buttons: buttons,
      aimAngle: aim,
    );

/// Runs [ticks] steps. [inputs] gives each player's command for a tick.
WorldState run(
  WorldState start,
  int ticks,
  Map<int, InputCommand> Function(int tick) inputs, {
  Simulation? simulation,
  void Function(WorldState)? onTick,
}) {
  final s = simulation ?? sim;
  var w = start;
  for (var i = 0; i < ticks; i++) {
    w = s.step(w, inputs(i));
    onTick?.call(w);
  }
  return w;
}

int btn(int bit) => 1 << bit;

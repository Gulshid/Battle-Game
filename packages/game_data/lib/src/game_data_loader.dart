import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_data/src/generated/game_data_json.dart';

/// Bump when abilities or classes change in a way old replays cannot survive.
/// It is stored in every replay header.
const int kDataVersion = 1;

/// Thrown when the JSON game data is malformed or breaks a rule.
class GameDataException implements Exception {
  GameDataException(this.message);

  final String message;

  @override
  String toString() => 'GameDataException: $message';
}

/// Loads the bundled game data (data/*.json via scripts/gen_game_data.dart).
GameConfig loadGameConfig() => parseGameConfig(
      abilitiesJson: kAbilitiesJson,
      classesJson: kClassesJson,
    );

/// Converts designer units (ms, px, px/s, degrees) to simulation units.
GameConfig parseGameConfig({
  required String abilitiesJson,
  required String classesJson,
}) {
  final abilitiesRaw = _obj(jsonDecode(abilitiesJson), 'abilities.json');
  final abilities = <String, AbilityDef>{
    for (final e in abilitiesRaw.entries)
      e.key: _parseAbility(e.key, _obj(e.value, 'ability ${e.key}')),
  };

  final root = _obj(jsonDecode(classesJson), 'classes.json');
  final settings = _obj(root['settings'], 'settings');
  final classList = _list(root['classes'], 'classes');
  final classes = <ClassDef>[];
  for (var i = 0; i < classList.length; i++) {
    final c = _parseClass(_obj(classList[i], 'class #$i'), abilities);
    if (c.id != i) {
      throw GameDataException('class "${c.name}": id must be $i (its index)');
    }
    if (c.id > 15) throw GameDataException('class ids must be <= 15');
    classes.add(c);
  }
  if (classes.isEmpty) throw GameDataException('no classes defined');

  return GameConfig(
    classes: classes,
    respawnTicks: _ticks(settings, 'respawn_ms', 'settings', min: 1),
    spawnInvulnTicks: _ticks(settings, 'spawn_invuln_ms', 'settings'),
  );
}

// ---------------------------------------------------------------- parsing

AbilityDef _parseAbility(String id, Map<String, Object?> m) {
  final ctx = 'ability "$id"';
  final kindName = _str(m, 'kind', ctx);
  final kind = AbilityKind.values.asNameMap()[kindName];
  if (kind == null) throw GameDataException('$ctx: unknown kind "$kindName"');

  final damage = _int(m, 'damage', ctx, def: 0);
  final range = _fixed(m, 'range_px', ctx);
  final arcDeg = _num(m, 'arc_deg', ctx, def: 360, max: 360);
  final arcHalf = ((arcDeg / 2) * kAngleSteps / 360).round().clamp(0, 128);
  final speed = _speed(m, 'proj_speed_pxs', ctx);
  final radius = _fixed(m, 'proj_radius_px', ctx);
  final life = _ticks(m, 'proj_life_ms', ctx);
  final channel = _ticks(m, 'channel_ms', ctx);
  final pulse = _ticks(m, 'pulse_ms', ctx);
  final spreadDeg = _num(m, 'proj_spread_deg', ctx, def: 0, max: 90);

  switch (kind) {
    case AbilityKind.melee:
    case AbilityKind.aoe:
      if (range <= 0) throw GameDataException('$ctx: range_px must be > 0');
    case AbilityKind.projectile:
      if (speed <= 0 || radius <= 0 || life <= 0) {
        throw GameDataException(
          '$ctx: projectile needs proj_speed_pxs, proj_radius_px, '
          'proj_life_ms',
        );
      }
    case AbilityKind.channel:
      if (range <= 0 || channel <= 0 || pulse <= 0) {
        throw GameDataException(
          '$ctx: channel needs range_px, channel_ms, pulse_ms',
        );
      }
    case AbilityKind.self:
      break;
  }

  return AbilityDef(
    id: id,
    kind: kind,
    cooldownTicks: _ticks(m, 'cooldown_ms', ctx, min: 1),
    castTicks: _ticks(m, 'cast_ms', ctx),
    damage: damage,
    range: range,
    arcHalf: arcHalf,
    offset: _fixed(m, 'offset_px', ctx),
    projSpeed: speed,
    projRadius: radius,
    projLifeTicks: life,
    projCount: _int(m, 'proj_count', ctx, def: 1, min: 1, max: 9),
    projSpreadHalf: (spreadDeg * kAngleSteps / 360).round(),
    knockback: (_num(m, 'knockback_px', ctx, def: 0) * kFixedOne / 5).round(),
    channelTicks: channel,
    pulseEveryTicks: pulse,
    castMovePct: _int(m, 'cast_move_pct', ctx, def: 100, max: 100),
    effects: _effects(m['effects'], '$ctx effects'),
    selfEffects: _effects(m['self_effects'], '$ctx self_effects'),
  );
}

ClassDef _parseClass(Map<String, Object?> m, Map<String, AbilityDef> all) {
  final name = _str(m, 'name', 'class');
  final ctx = 'class "$name"';
  final ids = _list(m['abilities'], '$ctx abilities');
  if (ids.length > 3) throw GameDataException('$ctx: at most 3 abilities');
  final abilities = <AbilityDef>[];
  for (final raw in ids) {
    final a = all[raw];
    if (a == null) throw GameDataException('$ctx: unknown ability "$raw"');
    abilities.add(a);
  }

  final speed = _speed(m, 'move_speed_pxs', ctx);
  int rate(String key) {
    final t = _ticks(m, key, ctx, min: 1);
    final r = speed ~/ t;
    return r < 1 ? 1 : r;
  }

  var dashCd = 0;
  var dashTicks = 0;
  var dashSpeed = 0;
  var dashIframes = 0;
  final dashRaw = m['dash'];
  if (dashRaw != null) {
    final d = _obj(dashRaw, '$ctx dash');
    dashCd = _ticks(d, 'cooldown_ms', '$ctx dash', min: 1);
    dashTicks = _ticks(d, 'duration_ms', '$ctx dash', min: 1);
    dashIframes = _ticks(d, 'iframe_ms', '$ctx dash');
    final dist = _fixed(d, 'distance_px', '$ctx dash');
    dashSpeed = dist ~/ dashTicks;
    if (dashSpeed > kTileSize) {
      throw GameDataException('$ctx dash: too fast (would skip walls)');
    }
  }

  return ClassDef(
    id: _int(m, 'id', ctx),
    name: name,
    maxHp: _int(m, 'max_hp', ctx, min: 1),
    armorPct: _int(m, 'armor_pct', ctx, def: 0, max: 90),
    moveSpeed: speed,
    accel: rate('accel_ms'),
    friction: rate('friction_ms'),
    abilities: abilities,
    dashCooldownTicks: dashCd,
    dashTicks: dashTicks,
    dashSpeed: dashSpeed,
    dashIframeTicks: dashIframes,
  );
}

List<EffectDef> _effects(Object? raw, String ctx) {
  if (raw == null) return const <EffectDef>[];
  final out = <EffectDef>[];
  for (final item in _list(raw, ctx)) {
    final m = _obj(item, ctx);
    final typeName = _str(m, 'type', ctx);
    final type = EffectType.values.asNameMap()[typeName];
    if (type == null) throw GameDataException('$ctx: unknown type "$typeName"');
    out.add(
      EffectDef(
        type: type,
        durationTicks: _ticks(m, 'duration_ms', ctx, min: 1),
        magnitude: _int(m, 'magnitude', ctx, def: 0, max: 1000),
      ),
    );
  }
  return out;
}

// ------------------------------------------------------------- primitives

Map<String, Object?> _obj(Object? v, String ctx) {
  if (v is Map<String, Object?>) return v;
  throw GameDataException('$ctx: expected an object');
}

List<Object?> _list(Object? v, String ctx) {
  if (v is List<Object?>) return v;
  throw GameDataException('$ctx: expected a list');
}

String _str(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is String) return v;
  throw GameDataException('$ctx.$key: expected a string');
}

num _num(
  Map<String, Object?> m,
  String key,
  String ctx, {
  num? def,
  num min = 0,
  num? max,
}) {
  final v = m[key];
  if (v == null) {
    if (def != null) return def;
    throw GameDataException('$ctx.$key: required');
  }
  if (v is! num) throw GameDataException('$ctx.$key: expected a number');
  if (v < min || (max != null && v > max)) {
    throw GameDataException('$ctx.$key: $v is out of range');
  }
  return v;
}

int _int(
  Map<String, Object?> m,
  String key,
  String ctx, {
  int? def,
  int min = 0,
  int? max,
}) =>
    _num(m, key, ctx, def: def, min: min, max: max).round();

/// Milliseconds -> ticks, rounded up. Missing key means 0.
int _ticks(Map<String, Object?> m, String key, String ctx, {int min = 0}) {
  final ms = _num(m, key, ctx, def: 0).round();
  final t = (ms * kSimHz + 999) ~/ 1000;
  if (t < min) throw GameDataException('$ctx.$key: too short ($ms ms)');
  return t;
}

/// Pixels -> fixed-point. Missing key means 0.
int _fixed(Map<String, Object?> m, String key, String ctx) =>
    (_num(m, key, ctx, def: 0) * kFixedOne).round();

/// Pixels per second -> fixed-point per tick. Missing key means 0.
int _speed(Map<String, Object?> m, String key, String ctx) {
  final v = (_num(m, key, ctx, def: 0) * kFixedOne / kSimHz).round();
  if (v > kTileSize) {
    throw GameDataException('$ctx.$key: too fast (would skip walls)');
  }
  return v;
}

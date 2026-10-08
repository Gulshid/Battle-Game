// GENERATED CODE - DO NOT EDIT.
// Source: packages/game_data/data/*.json
// Regenerate: dart run scripts/gen_game_data.dart
// ignore_for_file: lines_longer_than_80_chars

const String kAbilitiesJson = r'''
{
  "warrior_slash": {
    "kind": "melee",
    "cooldown_ms": 500,
    "cast_ms": 100,
    "damage": 14,
    "range_px": 40,
    "arc_deg": 100,
    "knockback_px": 10,
    "cast_move_pct": 60
  },
  "warrior_shockwave": {
    "kind": "aoe",
    "cooldown_ms": 6000,
    "cast_ms": 300,
    "damage": 18,
    "range_px": 70,
    "knockback_px": 40,
    "cast_move_pct": 30,
    "effects": [
      { "type": "slow", "duration_ms": 2000, "magnitude": 40 }
    ]
  },
  "warrior_bulwark": {
    "kind": "self",
    "cooldown_ms": 10000,
    "cast_ms": 0,
    "self_effects": [
      { "type": "shield", "duration_ms": 3000, "magnitude": 40 },
      { "type": "haste", "duration_ms": 3000, "magnitude": 20 }
    ]
  },
  "archer_arrow": {
    "kind": "projectile",
    "cooldown_ms": 600,
    "cast_ms": 150,
    "damage": 12,
    "proj_speed_pxs": 390,
    "proj_radius_px": 5,
    "proj_life_ms": 900,
    "cast_move_pct": 70
  },
  "archer_triple_shot": {
    "kind": "projectile",
    "cooldown_ms": 5000,
    "cast_ms": 250,
    "damage": 8,
    "proj_speed_pxs": 390,
    "proj_radius_px": 5,
    "proj_life_ms": 800,
    "proj_count": 3,
    "proj_spread_deg": 17,
    "cast_move_pct": 50
  },
  "archer_hindering_shot": {
    "kind": "projectile",
    "cooldown_ms": 7000,
    "cast_ms": 200,
    "damage": 6,
    "proj_speed_pxs": 330,
    "proj_radius_px": 6,
    "proj_life_ms": 1000,
    "cast_move_pct": 60,
    "effects": [
      { "type": "slow", "duration_ms": 2000, "magnitude": 60 }
    ]
  },
  "mage_fireball": {
    "kind": "projectile",
    "cooldown_ms": 800,
    "cast_ms": 250,
    "damage": 16,
    "proj_speed_pxs": 270,
    "proj_radius_px": 7,
    "proj_life_ms": 1200,
    "cast_move_pct": 50,
    "effects": [
      { "type": "burn", "duration_ms": 2000, "magnitude": 3 }
    ]
  },
  "mage_frost_nova": {
    "kind": "aoe",
    "cooldown_ms": 8000,
    "cast_ms": 300,
    "damage": 10,
    "range_px": 80,
    "knockback_px": 20,
    "cast_move_pct": 30,
    "effects": [
      { "type": "slow", "duration_ms": 2500, "magnitude": 50 }
    ]
  },
  "mage_arcane_storm": {
    "kind": "channel",
    "cooldown_ms": 12000,
    "cast_ms": 200,
    "damage": 6,
    "range_px": 60,
    "channel_ms": 2000,
    "pulse_ms": 400,
    "cast_move_pct": 40
  }
}
''';

const String kClassesJson = r'''
{
  "settings": {
    "respawn_ms": 3000,
    "spawn_invuln_ms": 1500
  },
  "classes": [
    {
      "id": 0,
      "name": "Warrior",
      "max_hp": 140,
      "armor_pct": 10,
      "move_speed_pxs": 165,
      "accel_ms": 100,
      "friction_ms": 70,
      "abilities": ["warrior_slash", "warrior_shockwave", "warrior_bulwark"],
      "dash": { "cooldown_ms": 2500, "duration_ms": 150, "distance_px": 60, "iframe_ms": 150 }
    },
    {
      "id": 1,
      "name": "Archer",
      "max_hp": 90,
      "armor_pct": 0,
      "move_speed_pxs": 185,
      "accel_ms": 90,
      "friction_ms": 60,
      "abilities": ["archer_arrow", "archer_triple_shot", "archer_hindering_shot"],
      "dash": { "cooldown_ms": 2000, "duration_ms": 200, "distance_px": 70, "iframe_ms": 100 }
    },
    {
      "id": 2,
      "name": "Mage",
      "max_hp": 80,
      "armor_pct": 0,
      "move_speed_pxs": 170,
      "accel_ms": 100,
      "friction_ms": 70,
      "abilities": ["mage_fireball", "mage_frost_nova", "mage_arcane_storm"],
      "dash": { "cooldown_ms": 3000, "duration_ms": 120, "distance_px": 64, "iframe_ms": 120 }
    },
    {
      "id": 3,
      "name": "Dummy",
      "max_hp": 100000,
      "armor_pct": 0,
      "move_speed_pxs": 0,
      "accel_ms": 100,
      "friction_ms": 100,
      "abilities": []
    }
  ]
}
''';

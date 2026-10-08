import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:game_data/src/generated/game_data_json.dart';
import 'package:test/test.dart';

const _okAbility = '''
{ "hit": { "kind": "melee", "cooldown_ms": 500, "range_px": 40 } }''';

String _classes(String abilityId) => '''
{
  "settings": { "respawn_ms": 3000, "spawn_invuln_ms": 1000 },
  "classes": [
    { "id": 0, "name": "T", "max_hp": 100, "move_speed_pxs": 150,
      "accel_ms": 100, "friction_ms": 100, "abilities": ["$abilityId"] }
  ]
}''';

GameConfig _parse(String abilities, [String? classes]) => parseGameConfig(
      abilitiesJson: abilities,
      classesJson: classes ?? _classes('hit'),
    );

void main() {
  group('bundled data', () {
    final config = loadGameConfig();

    test('has Warrior, Archer, Mage and a Dummy', () {
      expect(
        config.classes.map((c) => c.name),
        ['Warrior', 'Archer', 'Mage', 'Dummy'],
      );
      for (var i = 0; i < config.classes.length; i++) {
        expect(config.classes[i].id, i);
      }
    });

    test('every playable class has attack + 2 abilities and a dash', () {
      for (final c in config.classes.take(3)) {
        expect(c.abilities.length, 3, reason: c.name);
        expect(c.dashTicks, greaterThan(0), reason: c.name);
      }
    });

    test('unit conversion: ms -> ticks, px -> fixed point', () {
      final slash = config.classes[0].abilities[0];
      expect(slash.cooldownTicks, 15); // 500 ms at 30 Hz
      expect(slash.castTicks, 3); // 100 ms rounds up
      expect(slash.range, 40 * kFixedOne);
      expect(slash.arcHalf, 36); // 100 degrees total
      final arrow = config.classes[1].abilities[0];
      expect(arrow.projSpeed, 208); // 390 px/s = 13 px/tick
      expect(arrow.projLifeTicks, 27);
      expect(config.respawnTicks, 90);
      expect(config.spawnInvulnTicks, 45);
    });

    test('triple shot spread is about 17 degrees', () {
      final t = config.classes[1].abilities[1];
      expect(t.projCount, 3);
      expect(t.projSpreadHalf, 12);
    });

    test('everything fits the snapshot format limits', () {
      for (final c in config.classes) {
        expect(c.moveSpeed, lessThan(2047));
        expect(c.dashSpeed, lessThan(2047));
        for (final a in c.abilities) {
          expect(a.projSpeed, lessThan(2047), reason: a.id);
          expect(a.projSpeed, lessThanOrEqualTo(kTileSize), reason: a.id);
        }
      }
    });

    test('embedded JSON is in sync with data/*.json', () {
      Object? read(String f) => jsonDecode(File('data/$f').readAsStringSync());
      expect(jsonDecode(kAbilitiesJson), read('abilities.json'));
      expect(jsonDecode(kClassesJson), read('classes.json'));
    }, skip: Directory('data').existsSync() ? false : 'run from package root');
  });

  group('validation', () {
    test('accepts a minimal valid file', () {
      expect(_parse(_okAbility).classes.single.abilities.single.id, 'hit');
    });

    test('rejects an unknown kind', () {
      expect(
        () => _parse('{ "hit": { "kind": "laser", "cooldown_ms": 500 } }'),
        throwsA(isA<GameDataException>()),
      );
    });

    test('rejects a melee ability without a range', () {
      expect(
        () => _parse('{ "hit": { "kind": "melee", "cooldown_ms": 500 } }'),
        throwsA(isA<GameDataException>()),
      );
    });

    test('rejects a projectile that is too fast', () {
      expect(
        () => _parse('''
{ "hit": { "kind": "projectile", "cooldown_ms": 500, "proj_speed_pxs": 2000,
  "proj_radius_px": 5, "proj_life_ms": 500 } }'''),
        throwsA(isA<GameDataException>()),
      );
    });

    test('rejects an unknown ability reference', () {
      expect(
        () => _parse(_okAbility, _classes('nope')),
        throwsA(isA<GameDataException>()),
      );
    });

    test('rejects unknown effect types and bad numbers', () {
      expect(
        () => _parse('''
{ "hit": { "kind": "melee", "cooldown_ms": 500, "range_px": 40,
  "effects": [ { "type": "freeze", "duration_ms": 100 } ] } }'''),
        throwsA(isA<GameDataException>()),
      );
      expect(
        () => _parse('{ "hit": { "kind": "melee", "cooldown_ms": -5 } }'),
        throwsA(isA<GameDataException>()),
      );
    });

    test('class ids must equal their index', () {
      final bad = _classes('hit').replaceFirst('"id": 0', '"id": 2');
      expect(() => _parse(_okAbility, bad), throwsA(isA<GameDataException>()));
    });
  });
}

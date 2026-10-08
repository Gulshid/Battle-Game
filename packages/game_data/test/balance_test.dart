import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// Phase 00 formulas: hits_to_kill = ceil(hp / dmg), TTK = (hits - 1) * cd.
/// This is a cheap guard-rail: it fails when a tuning change makes basic
/// attacks absurdly fast or slow. The real balance work is playtesting.
double _ttkSeconds(ClassDef attacker, ClassDef victim) {
  final a = attacker.abilities.first;
  var dmg = (a.damage * (100 - victim.armorPct)) ~/ 100;
  if (dmg < 1) dmg = 1;
  final hits = (victim.maxHp + dmg - 1) ~/ dmg;
  return (hits - 1) * a.cooldownTicks / kSimHz;
}

void main() {
  final config = loadGameConfig();
  final playable = config.classes.take(3).toList();

  for (final a in playable) {
    for (final v in playable) {
      test('${a.name} basic-attacks ${v.name} in a sane time', () {
        final ttk = _ttkSeconds(a, v);
        expect(ttk, inInclusiveRange(1.0, 9.0));
      });
    }
  }

  test('glass cannons die faster than tanks', () {
    final warrior = config.classes[0];
    final mage = config.classes[2];
    expect(_ttkSeconds(warrior, mage), lessThan(_ttkSeconds(mage, warrior)));
  });

  test('every special has a longer cooldown than the basic attack', () {
    for (final c in playable) {
      for (final special in c.abilities.skip(1)) {
        expect(
          special.cooldownTicks,
          greaterThan(c.abilities.first.cooldownTicks),
          reason: '${c.name} ${special.id}',
        );
      }
    }
  });
}

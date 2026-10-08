import 'package:flutter_test/flutter_test.dart';
import 'package:game_client/features/match/input/touch_input.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:game_core/game_core.dart';

LocalMatch _make(MatchMode mode, {TouchInput? touch}) => LocalMatch(
      mode: mode,
      localClass: 0,
      input: touch ?? TouchInput(),
    );

void _play(LocalMatch m, double seconds, {double fps = 60}) {
  final frames = (seconds * fps).round();
  for (var i = 0; i < frames; i++) {
    m.advance(1 / fps);
  }
}

void main() {
  test('arena has the local player and three bots', () {
    final m = _make(MatchMode.arena);
    expect(m.curr.players.length, 4);
    expect(m.bots.length, 3);
    expect(m.curr.players[LocalMatch.localId]!.classId, 0);
  });

  test('training arena starts with only the player', () {
    final m = _make(MatchMode.training);
    expect(m.curr.players.length, 1);
    expect(m.bots, isEmpty);
  });

  test('simulation does not depend on render fps', () {
    final ticks = <int>[];
    for (final fps in [30.0, 60.0, 120.0]) {
      final m = _make(MatchMode.arena);
      _play(m, 5, fps: fps);
      ticks.add(m.curr.tick);
    }
    expect((ticks[0] - ticks[1]).abs(), lessThanOrEqualTo(1));
    expect((ticks[1] - ticks[2]).abs(), lessThanOrEqualTo(1));
  });

  test('a played bot match replays to identical hashes', () {
    final m = _make(MatchMode.arena);
    _play(m, 20);
    final check = m.verifyReplay();
    expect(check.ok, isTrue, reason: check.message);
    expect(check.tick, m.curr.tick);
  });

  test('different frame rates still produce a valid, replayable match', () {
    for (final fps in [30.0, 144.0]) {
      final m = _make(MatchMode.arena);
      _play(m, 10, fps: fps);
      expect(m.curr.tick, greaterThan(250));
      expect(m.verifyReplay().ok, isTrue);
    }
  });

  test('training dummies can be added and removed', () {
    final m = _make(MatchMode.training);
    m.spawnDummy();
    expect(m.curr.players.keys.toList()..sort(), [1, 100]);
    _play(m, 2);
    expect(m.verifyReplay().ok, isTrue); // recording restarted at the edit
    m.clearDummies();
    expect(m.curr.players.length, 1);
  });

  test('aim assist turns an attack toward a nearby enemy', () {
    final touch = TouchInput();
    final m = _make(MatchMode.training, touch: touch);
    final me = m.curr.players[LocalMatch.localId]!;
    final dummy = m.sim.createPlayer(
      id: 100,
      classId: m.dummyClassId,
      x: me.x + 100 * kFixedOne,
      y: me.y + 30 * kFixedOne,
    );
    m.curr = m.sim.withPlayer(m.curr, dummy);
    m.prev = m.curr;

    touch.press(kBtnAttack);
    m.advance(1 / kSimHz + 0.0001);

    final expected = angleOf(100 * kFixedOne, 30 * kFixedOne);
    expect(m.curr.players[LocalMatch.localId]!.castAim, expected);
  });

  test('damage dealt by the player feeds the DPS meter', () {
    final touch = TouchInput();
    final m = _make(MatchMode.training, touch: touch);
    final me = m.curr.players[LocalMatch.localId]!;
    m.curr = m.sim.withPlayer(
      m.curr,
      m.sim.createPlayer(
        id: 100,
        classId: m.dummyClassId,
        x: me.x + 30 * kFixedOne,
        y: me.y,
      ),
    );
    m.prev = m.curr;
    touch.setHeld(kBtnAttack, down: true);
    _play(m, 2);
    expect(m.dps.total, greaterThan(0));
    expect(m.dps.dps(m.curr.tick), greaterThan(0));
  });
}

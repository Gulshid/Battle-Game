import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

WorldState run(double fps, double seconds) {
  const sim = Simulation();
  var s = WorldState(
    tick: 0,
    players: {1: PlayerState(id: 1, x: 0, y: 0)},
  );
  final ts = FixedTimestep(stepSeconds: kSimDt);
  final frames = (seconds * fps).round();
  for (var i = 0; i < frames; i++) {
    ts.advance(1 / fps, (t) {
      s = sim.step(s, {1: InputCommand(tick: t, seq: t, moveX: 127)});
    });
  }
  return s;
}

void main() {
  test('same distance at 30, 60 and 120 fps (within one tick)', () {
    final a = run(30, 5).players[1]!.x;
    final b = run(60, 5).players[1]!.x;
    final c = run(120, 5).players[1]!.x;
    expect((a - b).abs(), lessThanOrEqualTo(kMoveSpeedPerTick));
    expect((b - c).abs(), lessThanOrEqualTo(kMoveSpeedPerTick));
  });

  test('determinism: identical inputs give identical state', () {
    expect(run(60, 3).players[1]!.x, run(60, 3).players[1]!.x);
  });

  test('big frame spike is clamped (no spiral of death)', () {
    final ts = FixedTimestep(stepSeconds: kSimDt);
    final n = ts.advance(5, (_) {});
    expect(n, lessThanOrEqualTo(8));
  });

  test('diagonal input is not faster than straight', () {
    const sim = Simulation();
    final s0 = WorldState(
      tick: 0,
      players: {1: PlayerState(id: 1, x: 0, y: 0)},
    );
    final s1 = sim.step(
      s0,
      {1: const InputCommand(tick: 0, seq: 0, moveX: 127, moveY: 127)},
    );
    final p = s1.players[1]!;
    expect(p.x, lessThan(kMoveSpeedPerTick));
    expect(p.x, p.y);
  });

  test('player accelerates instead of starting at full speed', () {
    const sim = Simulation();
    var s = WorldState(
      tick: 0,
      players: {1: PlayerState(id: 1, x: 0, y: 0)},
    );
    final speeds = <int>[];
    for (var i = 0; i < 6; i++) {
      s = sim.step(s, {1: const InputCommand(tick: 0, seq: 0, moveX: 127)});
      speeds.add(s.players[1]!.vx);
    }
    expect(speeds.first, lessThan(speeds.last));
    expect(speeds.last, kMoveSpeedPerTick);
  });
}

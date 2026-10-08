import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  group('trig', () {
    test('axis directions are exact', () {
      expect(cosOf(0), kTrigScale);
      expect(sinOf(64), kTrigScale);
      expect(cosOf(128), -kTrigScale);
      expect(sinOf(192), -kTrigScale);
      expect(cosOf(64), 0);
    });

    test('angles wrap', () {
      expect(cosOf(256), cosOf(0));
      expect(sinOf(-64), sinOf(192));
    });

    test('angleOf inverts the tables to within one step', () {
      for (var a = 0; a < kAngleSteps; a++) {
        final back = angleOf(cosOf(a), sinOf(a));
        expect(angleDiff(back, a), lessThanOrEqualTo(1), reason: 'angle $a');
      }
    });

    test('angleOf on the axes', () {
      expect(angleOf(5, 0), 0);
      expect(angleOf(0, 7), 64);
      expect(angleOf(-9, 0), 128);
      expect(angleOf(0, -2), 192);
      expect(angleOf(0, 0), 0);
    });

    test('angleDiff is the shortest way round', () {
      expect(angleDiff(10, 250), 16);
      expect(angleDiff(0, 128), 128);
      expect(angleDiff(200, 200), 0);
    });
  });

  group('isqrt', () {
    test('is the exact floor square root', () {
      for (var n = 0; n < 5000; n++) {
        final r = isqrt(n);
        expect(r * r <= n, isTrue, reason: 'n=$n');
        expect((r + 1) * (r + 1) > n, isTrue, reason: 'n=$n');
      }
    });

    test('handles big values and negatives', () {
      expect(isqrt(1 << 40), 1 << 20);
      expect(isqrt((1 << 40) - 1), (1 << 20) - 1);
      expect(isqrt(-5), 0);
    });
  });

  group('Rng', () {
    test('same seed, same sequence', () {
      final a = Rng(123);
      final b = Rng(123);
      for (var i = 0; i < 100; i++) {
        expect(a.nextU32(), b.nextU32());
      }
    });

    test('state never becomes zero, even from seed 0', () {
      final r = Rng(0);
      expect(r.state, isNot(0));
      for (var i = 0; i < 1000; i++) {
        expect(r.nextU32(), isNot(0));
      }
    });

    test('nextInt and range stay in bounds', () {
      final r = Rng(5);
      for (var i = 0; i < 1000; i++) {
        expect(r.nextInt(10), inInclusiveRange(0, 9));
        expect(r.range(-3, 3), inInclusiveRange(-3, 3));
      }
      expect(r.nextInt(1), 0);
    });

    test('roughly uniform', () {
      final r = Rng(99);
      final counts = List<int>.filled(4, 0);
      for (var i = 0; i < 4000; i++) {
        counts[r.nextInt(4)]++;
      }
      for (final c in counts) {
        expect(c, inInclusiveRange(800, 1200));
      }
    });
  });

  group('DpsMeter', () {
    test('averages damage over the window and forgets old hits', () {
      final m = DpsMeter(windowTicks: 60);
      m.onEvents(
        const [
          DamageEvent(
            10,
            victimId: 2,
            attackerId: 1,
            amount: 20,
            absorbed: 10,
            x: 0,
            y: 0,
            overTime: false,
          ),
          DamageEvent(
            12,
            victimId: 2,
            attackerId: 9, // someone else
            amount: 99,
            absorbed: 0,
            x: 0,
            y: 0,
            overTime: false,
          ),
        ],
        attackerId: 1,
      );
      expect(m.total, 30);
      expect(m.dps(30), closeTo(30 * kSimHz / 60, 1e-9));
      expect(m.dps(100), 0);
    });
  });
}

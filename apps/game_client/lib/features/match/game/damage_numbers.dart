import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:game_client/shared/pool.dart';

class _Number {
  String text = '';
  double x = 0;
  double y = 0;
  double age = 0;
  double size = 14;
  Color color = const Color(0xFFFFFFFF);

  void reset() => age = 0;
}

/// Floating damage numbers from a pool (no allocation per hit).
class DamageNumbers extends Component {
  DamageNumbers() : super(priority: 20);

  static const _life = 0.7;

  final Pool<_Number> _pool =
      Pool<_Number>(_Number.new, (n) => n.reset(), prewarm: 24);
  final List<_Number> _active = <_Number>[];

  void spawn(
    double x,
    double y,
    int amount, {
    required Color color,
    bool big = false,
  }) {
    final n = _pool.acquire()
      ..text = '$amount'
      ..x = x + (amount % 7 - 3) * 2.0
      ..y = y - 18
      ..size = big ? 20 : 14
      ..color = color;
    _active.add(n);
  }

  @override
  void update(double dt) {
    for (var i = _active.length - 1; i >= 0; i--) {
      final n = _active[i]..age += dt;
      if (n.age >= _life) {
        _active.removeAt(i);
        _pool.release(n);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (final n in _active) {
      final t = n.age / _life;
      final paint = TextPaint(
        style: TextStyle(
          color: n.color.withValues(alpha: 1 - t * t),
          fontSize: n.size,
          fontWeight: FontWeight.bold,
        ),
      );
      paint.render(
        canvas,
        n.text,
        Vector2(n.x, n.y - 28 * t),
        anchor: Anchor.center,
      );
    }
  }
}

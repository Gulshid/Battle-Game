import 'dart:ui';

import 'package:flame/components.dart';
import 'package:game_client/features/match/game/battle_game.dart';
import 'package:game_client/features/match/render/palette.dart';
import 'package:game_core/game_core.dart';

/// Draws every projectile straight from the simulation state, interpolated
/// between the last two ticks. No per-projectile components to create or pool.
class ProjectileLayer extends Component with HasGameReference<BattleGame> {
  ProjectileLayer() : super(priority: 3);

  final Paint _core = Paint();
  final Paint _glow = Paint();
  final Paint _trail = Paint()
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final m = game.match;
    final t = m.clock.alpha;
    for (final p in m.curr.projectiles) {
      Projectile? before;
      for (final q in m.prev.projectiles) {
        if (q.id == p.id) {
          before = q;
          break;
        }
      }
      final ax = before?.x ?? p.x - p.vx;
      final ay = before?.y ?? p.y - p.vy;
      final x = (ax + (p.x - ax) * t) / kFixedOne;
      final y = (ay + (p.y - ay) * t) / kFixedOne;
      final def = m.config.classOf(p.classId).abilities[p.slot];
      final r = def.projRadius / kFixedOne;
      final c = classAccent(p.classId);

      _trail.color = c.withValues(alpha: 0.5);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - p.vx / kFixedOne * 2, y - p.vy / kFixedOne * 2),
        _trail,
      );
      _glow.color = c.withValues(alpha: 0.3);
      canvas.drawCircle(Offset(x, y), r * 1.8, _glow);
      _core.color = const Color(0xFFFFFFFF);
      canvas.drawCircle(Offset(x, y), r * 0.8, _core);
    }
  }
}

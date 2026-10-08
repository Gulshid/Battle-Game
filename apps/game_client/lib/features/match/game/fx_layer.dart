import 'dart:ui';

import 'package:flame/components.dart';
import 'package:game_client/features/match/game/battle_game.dart';
import 'package:game_client/features/match/render/palette.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:game_client/shared/pool.dart';
import 'package:game_core/game_core.dart';

enum FxKind { ring, arc, spark }

/// One pooled visual effect. Mutable on purpose: reused, never reallocated.
class Fx {
  FxKind kind = FxKind.ring;
  double x = 0;
  double y = 0;
  double radius = 0;
  double angle = 0; // radians
  double halfArc = 0; // radians
  double age = 0;
  double life = 0.2;
  Color color = const Color(0xFFFFFFFF);

  void reset() {
    age = 0;
    life = 0.2;
  }
}

/// Swings, shockwaves, dust, sparks and cast telegraphs. All pooled and drawn
/// in one pass. Purely visual: never feeds back into the simulation.
class FxLayer extends Component with HasGameReference<BattleGame> {
  FxLayer() : super(priority: 5);

  final Pool<Fx> _pool = Pool<Fx>(Fx.new, (f) => f.reset(), prewarm: 48);
  final List<Fx> _active = <Fx>[];
  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  int get activeCount => _active.length;

  Fx _spawn(FxKind kind, double x, double y, Color c, double life) {
    final f = _pool.acquire()
      ..kind = kind
      ..x = x
      ..y = y
      ..color = c
      ..life = life;
    _active.add(f);
    return f;
  }

  void ring(double x, double y, double radius, Color c, {double life = 0.3}) {
    _spawn(FxKind.ring, x, y, c, life).radius = radius;
  }

  void swing(
    double x,
    double y,
    double radius,
    double angle,
    double halfArc,
    Color c,
  ) {
    _spawn(FxKind.arc, x, y, c, 0.16)
      ..radius = radius
      ..angle = angle
      ..halfArc = halfArc;
  }

  void spark(double x, double y, Color c) {
    _spawn(FxKind.spark, x, y, c, 0.18).radius = 9;
  }

  /// Turns a simulation event into effects.
  void onEvent(GameEvent e) {
    switch (e) {
      case CastEvent():
        final px = e.x / kFixedOne;
        final py = e.y / kFixedOne;
        final owner = game.match.curr.players[e.playerId];
        final c = classAccent(owner?.classId ?? 0);
        final aim = angleRad(e.aim);
        switch (e.kind) {
          case AbilityKind.melee:
            swing(
              px,
              py,
              e.range / kFixedOne,
              aim,
              angleRad(e.arcHalf),
              c,
            );
          case AbilityKind.aoe:
          case AbilityKind.channel:
            final cx = px + _cos(e.aim) * e.offset / kFixedOne;
            final cy = py + _sin(e.aim) * e.offset / kFixedOne;
            ring(cx, cy, e.range / kFixedOne, c);
          case AbilityKind.self:
            ring(px, py, 26, const Color(0xFFFFEE58), life: 0.4);
          case AbilityKind.projectile:
            spark(px, py, c);
        }
      case DashEvent():
        ring(e.x / kFixedOne, e.y / kFixedOne, 18, const Color(0xFFFFFFFF),
            life: 0.2);
      case ImpactEvent():
        spark(e.x / kFixedOne, e.y / kFixedOne, const Color(0xFFFFF59D));
      case RespawnEvent():
        ring(e.x / kFixedOne, e.y / kFixedOne, 30, const Color(0xFF69F0AE),
            life: 0.5);
      case KillEvent():
        ring(e.x / kFixedOne, e.y / kFixedOne, 40, const Color(0xFFFF5252),
            life: 0.45);
      case DamageEvent():
        break; // numbers and flashes are handled by the game
    }
  }

  static double _cos(int a) => cosOf(a) / kTrigScale;
  static double _sin(int a) => sinOf(a) / kTrigScale;

  @override
  void update(double dt) {
    for (var i = _active.length - 1; i >= 0; i--) {
      final f = _active[i]..age += dt;
      if (f.age >= f.life) {
        _active.removeAt(i);
        _pool.release(f);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _renderTelegraphs(canvas);
    for (final f in _active) {
      final t = (f.age / f.life).clamp(0.0, 1.0);
      final alpha = 1 - t;
      switch (f.kind) {
        case FxKind.ring:
          _line.color = f.color.withValues(alpha: alpha);
          final r = f.radius * (0.4 + 0.6 * t);
          canvas.drawCircle(Offset(f.x, f.y), r, _line);
        case FxKind.arc:
          _fill.color = f.color.withValues(alpha: 0.5 * alpha);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(f.x, f.y), radius: f.radius),
            f.angle - f.halfArc,
            f.halfArc * 2,
            true,
            _fill,
          );
        case FxKind.spark:
          _fill.color = f.color.withValues(alpha: alpha);
          canvas.drawCircle(Offset(f.x, f.y), f.radius * (1 - 0.5 * t), _fill);
      }
    }
  }

  /// Readable windup: shows where a cast in progress is going to land.
  void _renderTelegraphs(Canvas canvas) {
    final m = game.match;
    for (final p in m.curr.players.values) {
      if (!p.alive || p.castSlot < 0 || p.channelLeft > 0) continue;
      final cls = m.config.classOf(p.classId);
      if (p.castSlot >= cls.abilities.length) continue;
      final def = cls.abilities[p.castSlot];
      final pos = m.renderPos(p.id);
      final aim = angleRad(p.castAim);
      final isLocal = p.id == LocalMatch.localId;
      final base = isLocal ? kLocalRing : kEnemyRing;
      _fill.color = base.withValues(alpha: 0.18);
      _line.color = base.withValues(alpha: 0.5);
      switch (def.kind) {
        case AbilityKind.melee:
          final rect = Rect.fromCircle(
            center: Offset(pos.x, pos.y),
            radius: def.range / kFixedOne,
          );
          final half = angleRad(def.arcHalf);
          canvas
            ..drawArc(rect, aim - half, half * 2, true, _fill)
            ..drawArc(rect, aim - half, half * 2, true, _line);
        case AbilityKind.aoe:
          final off = def.offset / kFixedOne;
          final c = Offset(pos.x + _cos(p.castAim) * off,
              pos.y + _sin(p.castAim) * off);
          canvas
            ..drawCircle(c, def.range / kFixedOne, _fill)
            ..drawCircle(c, def.range / kFixedOne, _line);
        case AbilityKind.projectile:
          final len = def.reach / kFixedOne * 0.6;
          canvas.drawLine(
            Offset(pos.x, pos.y),
            Offset(
              pos.x + _cos(p.castAim) * len,
              pos.y + _sin(p.castAim) * len,
            ),
            _line,
          );
        case AbilityKind.channel:
        case AbilityKind.self:
          canvas.drawCircle(Offset(pos.x, pos.y), 22, _line);
      }
    }
  }
}

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:game_client/features/match/game/battle_game.dart';
import 'package:game_client/features/match/render/anim_controller.dart';
import 'package:game_client/features/match/render/palette.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:game_core/game_core.dart';

/// Reads interpolated position and state from the match; never moves itself.
/// Sprite sheet layout: 32x32 frames, one row per [AnimState].
class PlayerView extends PositionComponent with HasGameReference<BattleGame> {
  PlayerView({required this.id})
      : super(
          size: Vector2.all(2 * kPlayerRadius / kFixedOne),
          anchor: Anchor.center,
        );

  final int id;
  final AnimController _anim = AnimController();
  late final SpriteAnimationGroupComponent<AnimState> _sprite;
  final Paint _shadow = Paint()..color = const Color(0x55000000);

  // Visual-only timers, set by [BattleGame] from simulation events.
  double _flash = 0;
  double _hitStop = 0;
  double _attack = 0;
  AnimState _lastState = AnimState.idle;
  int _filterKey = -1;

  /// White flash + a short animation freeze (hit-stop) when damaged.
  void onHit({required bool heavy}) {
    _flash = 0.1;
    _hitStop = heavy ? 0.1 : 0.067; // 3 to 4 simulation ticks
  }

  /// Freezes this view's animation too (the attacker feels the impact).
  void onLanded() => _hitStop = 0.05;

  void onCast() => _attack = 0.24;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load('warrior.png');
    SpriteAnimation row(int r, int frames, double step, {bool loop = true}) {
      return SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: frames,
          stepTime: step,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, r * 32.0),
          loop: loop,
        ),
      );
    }

    _sprite = SpriteAnimationGroupComponent<AnimState>(
      animations: {
        AnimState.idle: row(0, 2, 0.5),
        AnimState.run: row(1, 4, 0.1),
        AnimState.attack: row(2, 3, 0.08),
        AnimState.hit: row(3, 1, 0.1),
        AnimState.death: row(4, 4, 0.15, loop: false),
      },
      current: AnimState.idle,
      size: Vector2.all(48),
      anchor: Anchor.center,
      position: size / 2 - Vector2(0, 8),
    );
    // Crisp pixel art: no smoothing when scaling up.
    _sprite.paint.filterQuality = FilterQuality.none;
    await add(_sprite);
    await add(_Overlay(this)..priority = 10);
  }

  PlayerState? get state => game.match.curr.players[id];

  @override
  void update(double dt) {
    super.update(dt);
    final m = game.match;
    final b = m.curr.players[id];
    if (b == null) {
      removeFromParent();
      return;
    }
    final a = m.prev.players[id] ?? b;
    position = m.renderPos(id);

    if (_flash > 0) _flash -= dt;
    if (_attack > 0) _attack -= dt;
    final frozen = _hitStop > 0;
    if (frozen) _hitStop -= dt;
    _sprite.playing = !frozen;

    final moving = a.x != b.x || a.y != b.y;
    final next = _anim.resolve(
      moving: moving && b.vx.abs() + b.vy.abs() > 8,
      attacking: _attack > 0 || b.castSlot >= 0,
      hit: _flash > 0,
      dead: !b.alive,
    );
    _anim.update(dt, next);
    if (next != _lastState) {
      // Restart one-shot animations (death) when they begin again.
      _sprite.animationTickers?[next]?.reset();
      _lastState = next;
    }
    _sprite
      ..current = next
      // facing: 0..255 where 0 = right, 128 = left
      ..scale.x = (b.facing > 64 && b.facing < 192) ? -1 : 1;

    // Tint by class, white silhouette while flashing, translucent when
    // spawn-protected or dead.
    final key = _flash > 0 ? 1 : (b.classId + 2);
    if (key != _filterKey) {
      _sprite.paint.colorFilter = _flash > 0
          ? const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcATop)
          : ColorFilter.mode(classTint(b.classId), BlendMode.modulate);
      _filterKey = key;
    }
    _sprite.opacity = !b.alive ? 0.5 : (b.invulnTicks > 0 ? 0.6 : 1);
  }

  @override
  void render(Canvas canvas) {
    // Ground shadow under the feet; children (the sprite) render after this.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + 12),
        width: size.x * 0.9,
        height: size.y * 0.35,
      ),
      _shadow,
    );
  }
}

/// Team ring, health bar and status dots, drawn above the sprite.
class _Overlay extends PositionComponent {
  _Overlay(this.view) : super(size: view.size);

  final PlayerView view;
  final Paint _p = Paint();
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  static const _statusColors = <Color>[
    Color(0xFFFFEB3B), // stun
    Color(0xFF42A5F5), // slow
    Color(0xFFFF7043), // burn
    Color(0xFF26C6DA), // shield
    Color(0xFF66BB6A), // haste
  ];

  @override
  void render(Canvas canvas) {
    final s = view.state;
    if (s == null) return;
    final w = view.size.x;
    final local = s.id == LocalMatch.localId;

    _ring.color = (local ? kLocalRing : kEnemyRing).withValues(alpha: 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, w / 2 + 12),
        width: w * 1.1,
        height: w * 0.45,
      ),
      _ring,
    );
    if (!s.alive) return;

    final maxHp = view.game.match.config.classOf(s.classId).maxHp;
    if (maxHp < 10000) {
      const barW = 36.0;
      final x = (w - barW) / 2;
      const y = -22.0;
      _p.color = const Color(0xAA000000);
      canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, barW + 2, 7), _p);
      final frac = (s.hp / maxHp).clamp(0.0, 1.0);
      _p.color = Color.lerp(
        const Color(0xFFFF5252),
        const Color(0xFF69F0AE),
        frac,
      )!;
      canvas.drawRect(Rect.fromLTWH(x, y, barW * frac, 5), _p);
      final shield = s.statusMag[EffectType.shield.index];
      if (shield > 0) {
        _p.color = const Color(0xFF26C6DA);
        final sw = (shield / maxHp * barW).clamp(0.0, barW);
        canvas.drawRect(Rect.fromLTWH(x, y - 3, sw, 2), _p);
      }
    }

    var dot = 0;
    for (var e = 0; e < kEffectCount; e++) {
      if (s.statusTicks[e] <= 0) continue;
      _p.color = _statusColors[e];
      canvas.drawCircle(Offset(w / 2 - 12 + dot * 8.0, -30), 3, _p);
      dot++;
    }
  }
}

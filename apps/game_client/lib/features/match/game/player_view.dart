import 'dart:ui';

import 'package:flame/components.dart';
import 'package:game_client/features/match/game/battle_game.dart';
import 'package:game_client/features/match/render/anim_controller.dart';
import 'package:game_core/game_core.dart';

/// Reads interpolated position and state from the game; never moves itself.
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
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = game.renderPos(id);
    final a = game.prev.players[id]!;
    final b = game.curr.players[id]!;
    final moving = a.x != b.x || a.y != b.y;
    final state = _anim.resolve(
      moving: moving,
      attacking: false, // combat arrives in Phase 3
      hit: false,
      dead: false,
    );
    _anim.update(dt, state);
    _sprite
      ..current = state
      // facing: 0..255 where 0 = right, 128 = left
      ..scale.x = (b.facing > 64 && b.facing < 192) ? -1 : 1;
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

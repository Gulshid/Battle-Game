import 'dart:ui';

import 'package:flame/components.dart';
import 'package:game_client/features/match/game/battle_game.dart';

/// Reads interpolated position from the game; never moves itself.
class PlayerView extends PositionComponent with HasGameReference<BattleGame> {
  PlayerView({required this.id, required Color color})
      : _paint = Paint()..color = color,
        super(size: Vector2.all(28), anchor: Anchor.center);

  final int id;
  final Paint _paint;

  @override
  void update(double dt) {
    position = game.renderPos(id);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, _paint);
  }
}

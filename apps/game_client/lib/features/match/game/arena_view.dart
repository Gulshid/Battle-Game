import 'dart:ui';

import 'package:flame/components.dart';
import 'package:game_core/game_core.dart';

/// Draws the collision grid. Rendering only; collision lives in game_core.
class ArenaView extends PositionComponent {
  ArenaView(this.grid)
      : super(
          size: Vector2(
            grid.width * kTileSizePx.toDouble(),
            grid.height * kTileSizePx.toDouble(),
          ),
          priority: -10,
        );

  final CollisionGrid grid;
  final Paint _floor = Paint()..color = const Color(0xFF232838);
  final Paint _wall = Paint()..color = const Color(0xFF4A5170);
  final Paint _edge = Paint()
    ..color = const Color(0xFF6B739A)
    ..style = PaintingStyle.stroke;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _floor);
    final t = kTileSizePx.toDouble();
    for (var ty = 0; ty < grid.height; ty++) {
      for (var tx = 0; tx < grid.width; tx++) {
        if (!grid.solidAt(tx, ty)) continue;
        final r = Rect.fromLTWH(tx * t, ty * t, t, t);
        canvas
          ..drawRect(r, _wall)
          ..drawRect(r.deflate(1), _edge);
      }
    }
  }
}

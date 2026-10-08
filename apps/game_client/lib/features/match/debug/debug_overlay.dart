import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:game_client/features/match/debug/frame_metrics.dart';

class DebugOverlay extends TextComponent {
  DebugOverlay(this.metrics, {required this.entityCount, this.extra})
      : super(
          position: Vector2(8, 8),
          priority: 1000,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFF00FF99),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        );

  final FrameMetrics metrics;
  final int Function() entityCount;

  /// Extra lines (state hash, replay check result).
  final String Function()? extra;
  bool visible = true;

  @override
  void update(double dt) {
    text = 'FPS ${metrics.fps.toStringAsFixed(0)}  '
        'worst ${metrics.worstMs.toStringAsFixed(1)} ms\n'
        'sim ${metrics.tickRate} ticks/s  '
        'steps/frame ${metrics.stepsLastFrame}\n'
        'entities ${entityCount()}\n'
        'ping ${metrics.pingMs} ms  '
        'pred.err ${metrics.predictionError.toStringAsFixed(2)}'
        '${extra == null ? '' : '\n${extra!()}'}';
  }

  @override
  void render(Canvas canvas) {
    if (visible) super.render(canvas);
  }
}

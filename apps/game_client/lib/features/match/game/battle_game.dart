import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:game_client/features/match/debug/debug_overlay.dart';
import 'package:game_client/features/match/debug/frame_metrics.dart';
import 'package:game_client/features/match/game/player_view.dart';
import 'package:game_client/features/match/input/input_source.dart';
import 'package:game_client/features/match/input/keyboard_input.dart';
import 'package:game_client/features/match/render/camera_rig.dart';
import 'package:game_core/game_core.dart';

class BattleGame extends FlameGame with KeyboardEvents {
  BattleGame({required this.input, required this.keyboard});

  final InputSource input;
  final KeyboardInput keyboard;

  static const _sim = Simulation();
  static const localId = 1;

  final FixedTimestep _clock = FixedTimestep(stepSeconds: kSimDt);
  final FrameMetrics metrics = FrameMetrics();

  late WorldState prev;
  late WorldState curr;
  int _seq = 0;
  late final CameraRig _rig;
  late final DebugOverlay _debug;

  @override
  Color backgroundColor() => const Color(0xFF1B1F2A);

  @override
  Future<void> onLoad() async {
    curr = prev = const WorldState(
      tick: 0,
      players: {localId: PlayerState(id: localId, x: 0, y: 0)},
    );
    // Next: load a Tiled map with flame_tiled and add it to `world`.
    world.add(PlayerView(id: localId, color: const Color(0xFF4FC3F7)));
    _rig = CameraRig(camera);
    _debug = DebugOverlay(metrics, entityCount: () => world.children.length);
    camera.viewport.add(_debug);
  }

  @override
  void update(double dt) {
    metrics.frame(dt);
    final steps = _clock.advance(dt, (tick) {
      final cmd = input.sample(tick: tick, seq: _seq++);
      prev = curr;
      curr = _sim.step(curr, {localId: cmd});
      metrics.tick();
    });
    metrics.stepsLastFrame = steps;
    super.update(dt);

    final pos = renderPos(localId);
    final a = prev.players[localId]!;
    final b = curr.players[localId]!;
    final dir = Vector2((b.x - a.x).toDouble(), (b.y - a.y).toDouble());
    if (dir.length2 > 0) dir.normalize();
    _rig.update(dt, pos, dir);
  }

  /// Smooth render position in px, interpolated between the last two ticks.
  Vector2 renderPos(int id) {
    final a = prev.players[id]!;
    final b = curr.players[id]!;
    final t = _clock.alpha;
    return Vector2(
      (a.x + (b.x - a.x) * t) / kFixedOne,
      (a.y + (b.y - a.y) * t) / kFixedOne,
    );
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    keyboard.down = Set.of(keysPressed);
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f3) {
      _debug.visible = !_debug.visible;
    }
    return KeyEventResult.handled;
  }
}

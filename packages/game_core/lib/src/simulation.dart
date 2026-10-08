import 'dart:math' as math;

import 'package:game_core/src/constants.dart';
import 'package:game_core/src/input_command.dart';
import 'package:game_core/src/state.dart';

class Simulation {
  const Simulation();

  /// Pure function: same state + same inputs => same next state.
  WorldState step(WorldState s, Map<int, InputCommand> inputs) {
    final next = <int, PlayerState>{};
    // Sorted ids so the result never depends on map ordering.
    final ids = s.players.keys.toList()..sort();
    for (final id in ids) {
      final p = s.players[id]!;
      final c = inputs[id] ?? InputCommand.idle;
      var mx = c.moveX;
      var my = c.moveY;
      final len = math.sqrt((mx * mx + my * my).toDouble());
      if (len > 127) {
        mx = (mx * 127 / len).truncate();
        my = (my * 127 / len).truncate();
      }
      next[id] = p.copyWith(
        x: p.x + (mx * kMoveSpeedPerTick) ~/ 127,
        y: p.y + (my * kMoveSpeedPerTick) ~/ 127,
        facing: (mx != 0 || my != 0) ? c.aimAngle : p.facing,
      );
    }
    return WorldState(tick: s.tick + 1, players: next);
  }
}

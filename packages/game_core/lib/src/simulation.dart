import 'dart:math' as math;

import 'package:game_core/src/collision_grid.dart';
import 'package:game_core/src/constants.dart';
import 'package:game_core/src/input_command.dart';
import 'package:game_core/src/state.dart';

class Simulation {
  const Simulation({this.grid});

  /// Static map collision. Null means an open plane (used in unit tests).
  final CollisionGrid? grid;

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
      final dx = (mx * kMoveSpeedPerTick) ~/ 127;
      final dy = (my * kMoveSpeedPerTick) ~/ 127;
      final g = grid;
      var nx = p.x + dx;
      var ny = p.y + dy;
      if (g != null) {
        // Axis-separated movement so players slide along walls.
        nx = _moveAxis(p.x, dx, (v) => g.circleHits(v, p.y, kPlayerRadius));
        ny = _moveAxis(p.y, dy, (v) => g.circleHits(nx, v, kPlayerRadius));
      }
      next[id] = p.copyWith(
        x: nx,
        y: ny,
        facing: (mx != 0 || my != 0) ? c.aimAngle : p.facing,
      );
    }
    return WorldState(tick: s.tick + 1, players: next);
  }

  /// Moves [pos] by [delta] but stops exactly at the wall (integer binary
  /// search, deterministic). [hits] tells whether a candidate position
  /// overlaps a wall.
  static int _moveAxis(int pos, int delta, bool Function(int) hits) {
    if (delta == 0) return pos;
    if (!hits(pos + delta)) return pos + delta;
    final sign = delta < 0 ? -1 : 1;
    var lo = 0; // known free
    var hi = delta.abs(); // known blocked
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (hits(pos + sign * mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return pos + sign * lo;
  }
}

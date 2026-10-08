import 'package:game_core/src/constants.dart';
import 'package:game_core/src/events.dart';

/// Rolling damage-per-second meter for the training arena.
class DpsMeter {
  DpsMeter({this.windowTicks = 5 * kSimHz});

  final int windowTicks;
  final List<({int tick, int amount})> _samples = <({int tick, int amount})>[];

  /// Total damage recorded since [reset].
  int total = 0;

  void reset() {
    _samples.clear();
    total = 0;
  }

  /// Records damage dealt by [attackerId] from one step's events.
  void onEvents(Iterable<GameEvent> events, {required int attackerId}) {
    for (final e in events) {
      if (e is DamageEvent && e.attackerId == attackerId) {
        final dealt = e.amount + e.absorbed;
        _samples.add((tick: e.tick, amount: dealt));
        total += dealt;
      }
    }
  }

  /// Average damage per second over the last window ending at [nowTick].
  double dps(int nowTick) {
    _samples.removeWhere((s) => s.tick <= nowTick - windowTicks);
    var sum = 0;
    for (final s in _samples) {
      sum += s.amount;
    }
    return sum * kSimHz / windowTicks;
  }
}

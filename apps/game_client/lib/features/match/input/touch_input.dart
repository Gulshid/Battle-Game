import 'dart:math' as math;

import 'package:game_client/features/match/input/input_source.dart';
import 'package:game_core/game_core.dart';

class TouchInput implements InputSource {
  double jx = 0;
  double jy = 0;
  int _latched = 0; // stays set until sampled so quick taps are not lost
  int _held = 0; // buttons currently down (channels need this)
  int aimAngle = 0;

  /// A tap: guaranteed to be seen by at least one tick.
  void press(int bit) => _latched |= 1 << bit;

  void setHeld(int bit, {required bool down}) {
    if (down) {
      _held |= 1 << bit;
    } else {
      _held &= ~(1 << bit);
    }
  }

  @override
  InputCommand sample({required int tick, required int seq}) {
    final b = _latched | _held;
    _latched = 0;
    if (jx != 0 || jy != 0) {
      final turns = math.atan2(jy, jx) / (2 * math.pi);
      aimAngle = (((turns % 1) + 1) % 1 * 256).floor() & 255;
    }
    return InputCommand(
      tick: tick,
      seq: seq,
      aimAngle: aimAngle,
      buttons: b,
      moveX: (jx * 127).round().clamp(-127, 127),
      moveY: (jy * 127).round().clamp(-127, 127),
    );
  }
}

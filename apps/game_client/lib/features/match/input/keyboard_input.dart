import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:game_client/features/match/input/input_source.dart';
import 'package:game_core/game_core.dart';

class KeyboardInput implements InputSource {
  Set<LogicalKeyboardKey> down = {};
  int aimAngle = 0;

  @override
  InputCommand sample({required int tick, required int seq}) {
    int axis(LogicalKeyboardKey neg, LogicalKeyboardKey pos) =>
        (down.contains(pos) ? 127 : 0) - (down.contains(neg) ? 127 : 0);
    var buttons = 0;
    if (down.contains(LogicalKeyboardKey.space)) buttons |= 1;
    if (down.contains(LogicalKeyboardKey.keyQ)) buttons |= 1 << 1;
    if (down.contains(LogicalKeyboardKey.keyE)) buttons |= 1 << 2;
    if (down.contains(LogicalKeyboardKey.shiftLeft)) buttons |= 1 << 3;
    final mx = axis(LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyD);
    final my = axis(LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyS);
    if (mx != 0 || my != 0) {
      // Aim follows movement until mouse aim is added.
      final turns = math.atan2(my.toDouble(), mx.toDouble()) / (2 * math.pi);
      aimAngle = (((turns % 1) + 1) % 1 * 256).floor() & 255;
    }
    return InputCommand(
      tick: tick,
      seq: seq,
      aimAngle: aimAngle,
      buttons: buttons,
      moveX: mx,
      moveY: my,
    );
  }
}

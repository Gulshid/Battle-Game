import 'package:game_client/features/match/input/input_source.dart';
import 'package:game_core/game_core.dart';

class TouchInput implements InputSource {
  double jx = 0;
  double jy = 0;
  int _latched = 0; // stays set until sampled so quick taps are not lost
  int aimAngle = 0;

  void press(int bit) => _latched |= 1 << bit;

  @override
  InputCommand sample({required int tick, required int seq}) {
    final b = _latched;
    _latched = 0;
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

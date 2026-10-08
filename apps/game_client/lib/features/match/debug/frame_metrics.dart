import 'dart:math' as math;

class FrameMetrics {
  final List<double> _frames = [];
  int ticksThisSecond = 0;
  int tickRate = 0;
  int stepsLastFrame = 0;
  double _acc = 0;
  // Reserved for Phase 05-06:
  int pingMs = 0;
  double predictionError = 0;
  int bytesDown = 0;

  void frame(double dt) {
    _frames.add(dt);
    if (_frames.length > 120) _frames.removeAt(0);
    _acc += dt;
    if (_acc >= 1) {
      tickRate = ticksThisSecond;
      ticksThisSecond = 0;
      _acc -= 1;
    }
  }

  void tick() => ticksThisSecond++;

  double get fps => _frames.isEmpty
      ? 0
      : _frames.length / _frames.fold<double>(0, (a, b) => a + b);
  double get worstMs => _frames.isEmpty ? 0 : _frames.reduce(math.max) * 1000;
}

class FixedTimestep {
  FixedTimestep({
    required this.stepSeconds,
    this.maxFrameSeconds = 0.25,
    this.maxStepsPerFrame = 8,
  });

  final double stepSeconds;
  final double maxFrameSeconds;
  final int maxStepsPerFrame;
  double _acc = 0;
  int ticks = 0;

  /// Render interpolation factor in [0, 1).
  double get alpha => _acc / stepSeconds;

  /// Returns how many simulation ticks ran this frame.
  int advance(double frameDt, void Function(int tick) onStep) {
    _acc += frameDt < maxFrameSeconds ? frameDt : maxFrameSeconds;
    var n = 0;
    while (_acc >= stepSeconds && n < maxStepsPerFrame) {
      onStep(ticks++);
      _acc -= stepSeconds;
      n++;
    }
    if (_acc >= stepSeconds) _acc = 0; // hit the cap: drop the backlog
    return n;
  }
}

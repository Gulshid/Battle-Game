/// Deterministic xorshift32 generator. The whole state is one 32-bit integer,
/// so it can live inside [WorldState] and be serialised and hashed.
class Rng {
  Rng(int seed) : state = _fix(seed);

  /// Always in 1..0xFFFFFFFF (xorshift must never reach 0).
  int state;

  static int _fix(int seed) {
    final s = seed & 0xFFFFFFFF;
    return s == 0 ? 0x9E3779B9 : s;
  }

  int nextU32() {
    var x = state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    state = x & 0xFFFFFFFF;
    return state;
  }

  /// Uniform-ish integer in 0..max-1 (returns 0 when max <= 1).
  int nextInt(int max) => max <= 1 ? 0 : nextU32() % max;

  /// Integer in min..max inclusive.
  int range(int min, int max) => min + nextInt(max - min + 1);

  /// True with the given percent probability.
  bool chance(int percent) => nextInt(100) < percent;
}

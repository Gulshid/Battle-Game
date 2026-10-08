enum AnimState { idle, run, attack, hit, death }

class AnimController {
  AnimState state = AnimState.idle;
  double _t = 0;

  /// Animation is derived from simulation state, never the other way around.
  AnimState resolve({
    required bool moving,
    required bool attacking,
    required bool hit,
    required bool dead,
  }) {
    if (dead) return AnimState.death;
    if (hit) return AnimState.hit;
    if (attacking) return AnimState.attack;
    return moving ? AnimState.run : AnimState.idle;
  }

  void update(double dt, AnimState next) {
    if (next != state) {
      state = next;
      _t = 0;
    }
    _t += dt;
  }

  double get time => _t;
}

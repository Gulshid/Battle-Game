import 'dart:math' as math;

import 'package:flame/components.dart';

class CameraRig {
  CameraRig(this.camera);
  final CameraComponent camera;
  final Vector2 _pos = Vector2.zero();
  double _trauma = 0; // 0..1
  double _time = 0;

  static const deadZone = 24.0;
  static const lookAhead = 40.0;
  static const smoothTime = 0.12;

  void snapTo(Vector2 p) => _pos.setFrom(p);

  /// Visual only: never feeds back into the simulation.
  void addShake(double amount) => _trauma = (_trauma + amount).clamp(0, 1);

  void update(double dt, Vector2 target, Vector2 moveDir) {
    _time += dt;
    final desired = target + moveDir * lookAhead;
    final delta = desired - _pos;
    if (delta.length > deadZone) {
      final goal = _pos + delta - delta.normalized() * deadZone;
      final k = 1 - math.exp(-dt / smoothTime); // frame-rate independent
      _pos.add((goal - _pos) * k);
    }
    final shake = _trauma * _trauma * 8.0;
    final off = Vector2(
      math.sin(_time * 91.3) + math.sin(_time * 57.1),
      math.cos(_time * 73.7) + math.cos(_time * 41.9),
    );
    camera.viewfinder.position = _pos + off * shake;
    _trauma = (_trauma - 1.5 * dt).clamp(0, 1);
  }
}

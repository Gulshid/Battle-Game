import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:game_client/features/match/debug/debug_overlay.dart';
import 'package:game_client/features/match/debug/frame_metrics.dart';
import 'package:game_client/features/match/game/arena_view.dart';
import 'package:game_client/features/match/game/damage_numbers.dart';
import 'package:game_client/features/match/game/fx_layer.dart';
import 'package:game_client/features/match/game/player_view.dart';
import 'package:game_client/features/match/game/projectile_layer.dart';
import 'package:game_client/features/match/hud/hud_ticker.dart';
import 'package:game_client/features/match/input/keyboard_input.dart';
import 'package:game_client/features/match/render/camera_rig.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:game_core/game_core.dart';

/// Thin renderer + input collector. All rules live in [LocalMatch] and
/// game_core; this class only reads state and turns events into visuals.
class BattleGame extends FlameGame with KeyboardEvents {
  BattleGame({
    required this.match,
    required this.keyboard,
    required this.ticker,
  });

  final LocalMatch match;
  final KeyboardInput keyboard;
  final HudTicker ticker;

  final FrameMetrics metrics = FrameMetrics();
  final Map<int, PlayerView> _views = <int, PlayerView>{};

  late final CameraRig _rig;
  late final DebugOverlay _debug;
  late final FxLayer _fx;
  late final DamageNumbers _numbers;
  String _replayStatus = 'F4: verify replay';

  @override
  Color backgroundColor() => const Color(0xFF14161F);

  @override
  Future<void> onLoad() async {
    _fx = FxLayer();
    _numbers = DamageNumbers();
    world
      ..add(ArenaView(match.arena.grid))
      ..add(ProjectileLayer())
      ..add(_fx)
      ..add(_numbers);
    _syncViews();

    final me = match.curr.players[LocalMatch.localId]!;
    _rig = CameraRig(camera)
      ..snapTo(Vector2(me.x / kFixedOne, me.y / kFixedOne));
    _debug = DebugOverlay(
      metrics,
      entityCount: () => world.children.length,
      extra: () => 'hash ${match.lastHash.toRadixString(16)}  '
          'tick ${match.curr.tick}\n$_replayStatus',
    );
    camera.viewport.add(_debug);
  }

  @override
  void update(double dt) {
    metrics.frame(dt);
    metrics.stepsLastFrame = match.advance(dt, onTick: metrics.tick);
    _syncViews();
    for (final e in match.drainEvents()) {
      _onEvent(e);
    }
    super.update(dt);

    final me = match.curr.players[LocalMatch.localId];
    if (me != null) {
      final a = match.prev.players[LocalMatch.localId] ?? me;
      final dir = Vector2((me.x - a.x).toDouble(), (me.y - a.y).toDouble());
      if (dir.length2 > 0) dir.normalize();
      _rig.update(dt, match.renderPos(LocalMatch.localId), dir);
    }
    ticker.poke();
  }

  /// Creates a view for every player that appeared (training dummies can be
  /// added at any time) and drops views of players that left.
  void _syncViews() {
    for (final id in match.curr.players.keys) {
      if (_views.containsKey(id)) continue;
      final v = PlayerView(id: id);
      _views[id] = v;
      world.add(v);
    }
    _views.removeWhere((id, v) {
      final gone = !match.curr.players.containsKey(id);
      if (gone) v.removeFromParent();
      return gone;
    });
  }

  // ------------------------------------------------------------- game feel

  void _onEvent(GameEvent e) {
    _fx.onEvent(e);
    switch (e) {
      case DamageEvent():
        _onDamage(e);
      case KillEvent():
        final mine = e.victimId == LocalMatch.localId ||
            e.killerId == LocalMatch.localId;
        if (mine) _rig.addShake(0.6);
      case CastEvent():
        _views[e.playerId]?.onCast();
      case DashEvent():
      case ImpactEvent():
      case RespawnEvent():
        break;
    }
  }

  void _onDamage(DamageEvent e) {
    final amount = e.amount + e.absorbed;
    final heavy = amount >= 15;
    _views[e.victimId]?.onHit(heavy: heavy);
    if (!e.overTime) _views[e.attackerId]?.onLanded();
    _numbers.spawn(
      e.x / kFixedOne,
      e.y / kFixedOne,
      e.amount,
      color: e.absorbed > 0 && e.amount == 0
          ? const Color(0xFF26C6DA)
          : (e.victimId == LocalMatch.localId
              ? const Color(0xFFFF5252)
              : const Color(0xFFFFFFFF)),
      big: heavy,
    );
    if (e.victimId == LocalMatch.localId) {
      _rig.addShake(heavy ? 0.45 : 0.25);
    } else if (e.attackerId == LocalMatch.localId) {
      _rig.addShake(heavy ? 0.3 : 0.15);
    }
  }

  // ------------------------------------------------------------------ keys

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    keyboard.down = Set.of(keysPressed);
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f3) {
        _debug.visible = !_debug.visible;
      } else if (event.logicalKey == LogicalKeyboardKey.f4) {
        final r = match.verifyReplay();
        _replayStatus = r.ok
            ? '${r.message} hash ${r.hash.toRadixString(16)}'
            : 'DESYNC! ${r.message}';
      }
    }
    return KeyEventResult.handled;
  }
}

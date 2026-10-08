import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_client/features/match/game/battle_game.dart';
import 'package:game_client/features/match/hud/hud_ticker.dart';
import 'package:game_client/features/match/hud/match_hud.dart';
import 'package:game_client/features/match/input/composite_input.dart';
import 'package:game_client/features/match/input/keyboard_input.dart';
import 'package:game_client/features/match/input/touch_input.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:go_router/go_router.dart';

/// Widgets host the game and never touch WorldState.
class MatchPage extends StatefulWidget {
  const MatchPage({this.mode = MatchMode.arena, this.classId = 0, super.key});

  final MatchMode mode;
  final int classId;

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final KeyboardInput keyboard = KeyboardInput();
  final TouchInput touch = TouchInput();
  final HudTicker ticker = HudTicker();
  late final LocalMatch match = LocalMatch(
    mode: widget.mode,
    localClass: widget.classId,
    input: CompositeInput([touch, keyboard]),
  );
  late final BattleGame game = BattleGame(
    match: match,
    keyboard: keyboard,
    ticker: ticker,
  );

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
          MatchHud(
            match: match,
            ticker: ticker,
            touch: touch,
            onExit: () => context.go('/'),
          ),
          if (mobile) _VirtualStick(touch: touch),
        ],
      ),
    );
  }
}

/// Simple on-screen joystick feeding TouchInput.
class _VirtualStick extends StatelessWidget {
  const _VirtualStick({required this.touch});
  final TouchInput touch;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 24,
        bottom: 24,
        width: 160,
        height: 160,
        child: GestureDetector(
          onPanUpdate: (d) {
            var x = (d.localPosition.dx - 80) / 80;
            var y = (d.localPosition.dy - 80) / 80;
            final len = math.sqrt(x * x + y * y);
            if (len > 1) {
              x /= len;
              y /= len;
            }
            touch
              ..jx = x
              ..jy = y;
          },
          onPanEnd: (_) => touch
            ..jx = 0
            ..jy = 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
      );
}

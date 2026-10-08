import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_client/features/match/game/battle_game.dart';
import 'package:game_client/features/match/input/composite_input.dart';
import 'package:game_client/features/match/input/keyboard_input.dart';
import 'package:game_client/features/match/input/touch_input.dart';

/// Widgets host the game and never touch WorldState.
class MatchPage extends StatefulWidget {
  const MatchPage({super.key});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final KeyboardInput keyboard = KeyboardInput();
  final TouchInput touch = TouchInput();
  late final BattleGame game = BattleGame(
    input: CompositeInput([touch, keyboard]),
    keyboard: keyboard,
  );

  @override
  Widget build(BuildContext context) {
    final mobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
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
            final len2 = x * x + y * y;
            if (len2 > 1) {
              final inv = 1 / len2;
              x *= inv;
              y *= inv;
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

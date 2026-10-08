import 'package:game_core/game_core.dart';

// Interface on purpose: keyboard, touch and bot inputs implement it.
// ignore: one_member_abstracts
abstract interface class InputSource {
  /// Called once per simulation tick (not per frame).
  InputCommand sample({required int tick, required int seq});
}

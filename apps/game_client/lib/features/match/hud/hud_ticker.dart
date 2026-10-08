import 'package:flutter/foundation.dart';

/// Poked by the game once per simulation tick so Flutter widgets (HUD) can
/// rebuild without owning any game state.
class HudTicker extends ChangeNotifier {
  void poke() => notifyListeners();
}

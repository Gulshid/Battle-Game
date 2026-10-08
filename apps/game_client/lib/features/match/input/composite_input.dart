import 'package:game_client/features/match/input/input_source.dart';
import 'package:game_core/game_core.dart';

/// Picks the first source that reports movement or buttons.
class CompositeInput implements InputSource {
  CompositeInput(this.sources);
  final List<InputSource> sources;

  @override
  InputCommand sample({required int tick, required int seq}) {
    InputCommand? last;
    for (final s in sources) {
      final c = s.sample(tick: tick, seq: seq);
      last = c;
      if (c.moveX != 0 || c.moveY != 0 || c.buttons != 0) return c;
    }
    return last ?? InputCommand(tick: tick, seq: seq);
  }
}

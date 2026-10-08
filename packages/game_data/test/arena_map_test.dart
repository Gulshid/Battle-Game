import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final arena = ArenaMap.parse(kArenaRows);

  test('all rows have the same width', () {
    expect(kArenaRows.map((r) => r.length).toSet().length, 1);
  });

  test('border is solid', () {
    final g = arena.grid;
    for (var x = 0; x < g.width; x++) {
      expect(g.solidAt(x, 0), isTrue);
      expect(g.solidAt(x, g.height - 1), isTrue);
    }
    for (var y = 0; y < g.height; y++) {
      expect(g.solidAt(0, y), isTrue);
      expect(g.solidAt(g.width - 1, y), isTrue);
    }
  });

  test('has 8 spawns, none inside a wall', () {
    expect(arena.spawns.length, 8);
    for (final s in arena.spawns) {
      expect(arena.grid.circleHits(s.x, s.y, kPlayerRadius), isFalse);
    }
  });

  test('layout is rotationally symmetric (fair)', () {
    final g = arena.grid;
    for (var y = 0; y < g.height; y++) {
      for (var x = 0; x < g.width; x++) {
        expect(
          g.solidAt(x, y),
          g.solidAt(g.width - 1 - x, g.height - 1 - y),
          reason: 'tile $x,$y',
        );
      }
    }
  });

  group('training arena', () {
    final training = ArenaMap.parse(kTrainingRows);

    test('is rectangular with a solid border', () {
      expect(kTrainingRows.map((r) => r.length).toSet().length, 1);
      final g = training.grid;
      for (var x = 0; x < g.width; x++) {
        expect(g.solidAt(x, 0), isTrue);
        expect(g.solidAt(x, g.height - 1), isTrue);
      }
    });

    test('has spawns that are free', () {
      expect(training.spawns.length, greaterThanOrEqualTo(4));
      for (final s in training.spawns) {
        expect(training.grid.circleHits(s.x, s.y, kPlayerRadius), isFalse);
      }
    });
  });
}

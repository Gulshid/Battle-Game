class PlayerState {
  const PlayerState({
    required this.id,
    required this.x,
    required this.y,
    this.facing = 0,
  });

  final int id;
  final int x; // fixed-point (1/16 px)
  final int y;
  final int facing; // 0..255

  PlayerState copyWith({int? x, int? y, int? facing}) => PlayerState(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        facing: facing ?? this.facing,
      );
}

class WorldState {
  const WorldState({required this.tick, required this.players});

  final int tick;
  final Map<int, PlayerState> players;
}

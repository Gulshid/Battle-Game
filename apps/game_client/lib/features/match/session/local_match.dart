import 'package:flame/components.dart' show Vector2;
import 'package:game_client/features/match/input/input_source.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

enum MatchMode { arena, training }

typedef KillFeedEntry = ({int tick, int killerId, int victimId});

typedef ReplayCheck = ({bool ok, int tick, int hash, String message});

/// Everything about one offline match that is not drawing: the simulation,
/// the fixed-step clock, bots, input sampling, replay recording and stats.
/// Flame only reads from this object. It has no widgets, so it is unit
/// testable and later gets replaced by a network-backed session (Phase 06).
class LocalMatch {
  LocalMatch({
    required this.mode,
    required this.localClass,
    required this.input,
    this.seed = 0xBA77,
  }) {
    config = loadGameConfig();
    arena = ArenaMap.parse(
      mode == MatchMode.arena ? kArenaRows : kTrainingRows,
    );
    sim = Simulation(
      grid: arena.grid,
      config: config,
      spawns: arena.spawns,
    );

    final players = <int, PlayerState>{};
    final first = arena.spawns.first;
    players[localId] = sim.createPlayer(
      id: localId,
      classId: localClass,
      x: first.x,
      y: first.y,
    );
    if (mode == MatchMode.arena) {
      // Three bots, one of each other class if possible, spread over spawns.
      for (var i = 0; i < 3; i++) {
        final id = localId + 1 + i;
        final sp = arena.spawns[(i * 2 + 2) % arena.spawns.length];
        final cls = (localClass + 1 + i) % _playableClasses;
        players[id] = sim.createPlayer(id: id, classId: cls, x: sp.x, y: sp.y);
        bots[id] = BotBrain(
          playerId: id,
          config: config,
          grid: arena.grid,
          seed: seed,
        );
      }
    }
    curr = prev = WorldState(tick: 0, players: players, rng: seed);
    recorder = ReplayRecorder(initial: curr, dataVersion: kDataVersion);
    lastHash = hashState(curr);
  }

  static const localId = 1;
  static const dummyBaseId = 100;
  static const _playableClasses = 3;
  static const killFeedTicks = 5 * kSimHz;

  final MatchMode mode;
  final int localClass;
  final InputSource input;
  final int seed;

  late final GameConfig config;
  late final ArenaMap arena;
  late final Simulation sim;

  final FixedTimestep clock = FixedTimestep(stepSeconds: kSimDt);
  final Map<int, BotBrain> bots = <int, BotBrain>{};
  final DpsMeter dps = DpsMeter();
  final List<KillFeedEntry> killFeed = <KillFeedEntry>[];

  late WorldState prev;
  late WorldState curr;
  late ReplayRecorder recorder;

  /// Hash of the latest state (refreshed once per second).
  int lastHash = 0;

  /// Make attacks snap to a nearby enemy inside a cone (helps touch input).
  bool aimAssist = true;

  int _seq = 0;
  int _nextDummy = dummyBaseId;
  final List<GameEvent> _events = <GameEvent>[];

  int get dummyClassId => config.classes.length - 1;

  /// Advances the simulation by as many fixed ticks as [dt] allows.
  int advance(double dt, {void Function()? onTick}) =>
      clock.advance(dt, (_) {
        _stepOnce();
        onTick?.call();
      });

  void _stepOnce() {
    final tick = curr.tick;
    var cmd = input.sample(tick: tick, seq: _seq++);
    if (aimAssist) cmd = _assist(cmd);
    final inputs = <int, InputCommand>{localId: cmd};
    for (final b in bots.values) {
      inputs[b.playerId] = b.think(curr, _seq);
    }
    prev = curr;
    curr = sim.step(curr, inputs);
    recorder.record(inputs, curr);
    _events.addAll(curr.events);
    dps.onEvents(curr.events, attackerId: localId);
    for (final e in curr.events) {
      if (e is KillEvent) {
        killFeed.add(
          (tick: curr.tick, killerId: e.killerId, victimId: e.victimId),
        );
      }
    }
    killFeed.removeWhere((k) => curr.tick - k.tick > killFeedTicks);
    if (curr.tick % kSimHz == 0) lastHash = hashState(curr);
  }

  /// Events since the last call (for sounds, particles, camera shake).
  List<GameEvent> drainEvents() {
    final out = List<GameEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// Snaps the aim to the nearest visible enemy inside a 56 degree cone.
  InputCommand _assist(InputCommand c) {
    if ((c.buttons & 7) == 0) return c;
    final me = curr.players[localId];
    if (me == null || !me.alive) return c;
    const maxDist = 450 * kFixedOne;
    var bestD2 = maxDist * maxDist;
    int? bestAngle;
    for (final id in curr.sortedPlayerIds) {
      final o = curr.players[id]!;
      if (id == me.id || !o.alive || o.team == me.team) continue;
      final dx = o.x - me.x;
      final dy = o.y - me.y;
      final d2 = dx * dx + dy * dy;
      if (d2 >= bestD2) continue;
      if (!arena.grid.lineClear(me.x, me.y, o.x, o.y)) continue;
      final a = angleOf(dx, dy);
      if (angleDiff(a, c.aimAngle) <= 40) {
        bestD2 = d2;
        bestAngle = a;
      }
    }
    return bestAngle == null ? c : c.copyWith(aimAngle: bestAngle);
  }

  // --------------------------------------------------------------- training

  /// Adds a stationary dummy at the spawn farthest from the player.
  void spawnDummy() {
    if (mode != MatchMode.training) return;
    final me = curr.players[localId];
    var best = arena.spawns.first;
    var bestD2 = -1;
    for (final sp in arena.spawns) {
      final dx = sp.x - (me?.x ?? 0);
      final dy = sp.y - (me?.y ?? 0);
      final d2 = dx * dx + dy * dy;
      if (d2 > bestD2) {
        bestD2 = d2;
        best = sp;
      }
    }
    final id = _nextDummy++;
    _edit(
      sim.withPlayer(
        curr,
        sim.createPlayer(id: id, classId: dummyClassId, x: best.x, y: best.y),
      ),
    );
  }

  void clearDummies() {
    var s = curr;
    for (final id in curr.sortedPlayerIds) {
      if (id >= dummyBaseId) s = sim.withoutPlayer(s, id);
    }
    if (!identical(s, curr)) _edit(s);
    dps.reset();
  }

  /// A change made outside `step` cannot be replayed, so a new recording
  /// starts from the edited state.
  void _edit(WorldState edited) {
    prev = edited;
    curr = edited;
    recorder = ReplayRecorder(initial: edited, dataVersion: kDataVersion);
  }

  // ----------------------------------------------------------------- replay

  /// Re-simulates everything recorded so far and checks every hash.
  ReplayCheck verifyReplay() {
    final replay = recorder.finish();
    try {
      final r = ReplayPlayer.play(sim, replay);
      return (
        ok: true,
        tick: r.finalState.tick,
        hash: r.finalHash,
        message: 'replay OK (${replay.frames.length} ticks)',
      );
    } on ReplayDesync catch (e) {
      return (ok: false, tick: e.tick, hash: e.actual, message: '$e');
    }
  }

  // ----------------------------------------------------------------- render

  /// True when a player moved so far in one tick that it must be a respawn.
  static const _teleport = 4 * kTileSize;

  /// Smooth position in px, interpolated between the last two ticks.
  Vector2 renderPos(int id) {
    final b = curr.players[id];
    if (b == null) return Vector2.zero();
    final a = prev.players[id] ?? b;
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final jump = dx.abs() > _teleport || dy.abs() > _teleport;
    final t = jump ? 1.0 : clock.alpha;
    return Vector2(
      (a.x + dx * t) / kFixedOne,
      (a.y + dy * t) / kFixedOne,
    );
  }

  String nameOf(int id) {
    if (id == localId) return 'You';
    if (id < 0) return 'World';
    final p = curr.players[id];
    final cls = p == null ? '?' : config.classOf(p.classId).name;
    return id >= dummyBaseId ? 'Dummy' : '$cls bot';
  }
}

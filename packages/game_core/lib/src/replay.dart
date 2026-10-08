import 'dart:typed_data';

import 'package:game_core/src/bit_io.dart';
import 'package:game_core/src/input_command.dart';
import 'package:game_core/src/simulation.dart';
import 'package:game_core/src/snapshot_codec.dart';
import 'package:game_core/src/state.dart';
import 'package:game_core/src/state_hash.dart';

/// Bump when the replay layout changes.
const int kReplayVersion = 1;

const List<int> _magic = <int>[0x42, 0x47, 0x52, 0x50]; // "BGRP"

/// A whole match: the exact starting state plus every tick's inputs.
/// Replaying it through the same ruleset must reproduce every checkpoint hash.
class Replay {
  Replay({
    required this.dataVersion,
    required this.hashInterval,
    required this.initialState,
    required this.frames,
    required this.checkpoints,
    required this.finalHash,
  });

  /// Parses bytes made by [toBytes]. Throws [FormatException] if invalid.
  factory Replay.fromBytes(Uint8List bytes) {
    final r = BitReader(bytes);
    for (final m in _magic) {
      if (r.readUint(8) != m) throw const FormatException('Not a replay file');
    }
    final version = r.readUint(8);
    if (version != kReplayVersion) {
      throw FormatException('Unsupported replay version $version');
    }
    final dataVersion = r.readVarUint();
    final interval = r.readVarUint();
    final initLen = r.readVarUint();
    final initial = Uint8List(initLen);
    for (var i = 0; i < initLen; i++) {
      initial[i] = r.readUint(8);
    }
    final frameCount = r.readVarUint();
    final last = <int, InputCommand>{};
    final frames = <Map<int, InputCommand>>[];
    for (var t = 0; t < frameCount; t++) {
      final n = r.readVarUint();
      final frame = <int, InputCommand>{};
      for (var i = 0; i < n; i++) {
        final id = r.readVarUint();
        final same = r.readBool();
        final InputCommand cmd;
        if (same) {
          final prev = last[id];
          if (prev == null) throw const FormatException('Bad repeat flag');
          cmd = prev.copyWith(tick: t, seq: t);
        } else {
          cmd = InputCommand(
            tick: t,
            seq: t,
            moveX: r.readInt(8),
            moveY: r.readInt(8),
            buttons: r.readUint(8),
            aimAngle: r.readUint(8),
          );
        }
        last[id] = cmd;
        frame[id] = cmd;
      }
      frames.add(frame);
    }
    final cpCount = r.readVarUint();
    final checkpoints = <int, int>{};
    for (var i = 0; i < cpCount; i++) {
      final tick = r.readVarUint();
      checkpoints[tick] = r.readUint(32);
    }
    final finalHash = r.readUint(32);
    return Replay(
      dataVersion: dataVersion,
      hashInterval: interval,
      initialState: initial,
      frames: frames,
      checkpoints: checkpoints,
      finalHash: finalHash,
    );
  }

  /// Version of the game data (abilities, classes) the match was played with.
  final int dataVersion;
  final int hashInterval;

  /// Full snapshot of the state before the first step.
  final Uint8List initialState;

  /// Inputs for step 0, 1, 2, ...
  final List<Map<int, InputCommand>> frames;

  /// State hash after step N, keyed by the resulting tick number.
  final Map<int, int> checkpoints;
  final int finalHash;

  Uint8List toBytes() {
    final w = BitWriter();
    for (final m in _magic) {
      w.writeUint(m, 8);
    }
    w
      ..writeUint(kReplayVersion, 8)
      ..writeVarUint(dataVersion)
      ..writeVarUint(hashInterval)
      ..writeVarUint(initialState.length);
    for (final b in initialState) {
      w.writeUint(b, 8);
    }
    w.writeVarUint(frames.length);
    final last = <int, InputCommand>{};
    for (final frame in frames) {
      final ids = frame.keys.toList()..sort();
      w.writeVarUint(ids.length);
      for (final id in ids) {
        final c = frame[id]!;
        w.writeVarUint(id);
        final prev = last[id];
        final same = prev != null && prev.sameControls(c);
        w.writeBool(value: same);
        if (!same) {
          w
            ..writeInt(c.moveX, 8)
            ..writeInt(c.moveY, 8)
            ..writeUint(c.buttons, 8)
            ..writeUint(c.aimAngle, 8);
        }
        last[id] = c;
      }
    }
    final ticks = checkpoints.keys.toList()..sort();
    w.writeVarUint(ticks.length);
    for (final t in ticks) {
      w
        ..writeVarUint(t)
        ..writeUint(checkpoints[t]!, 32);
    }
    w.writeUint(finalHash, 32);
    return w.toBytes();
  }
}

/// Collects a replay while a match runs. Call [record] once per step.
class ReplayRecorder {
  ReplayRecorder({
    required WorldState initial,
    required this.dataVersion,
    this.hashInterval = 30,
  })  : _initial = const SnapshotCodec().encode(initial),
        _lastState = initial;

  final int dataVersion;
  final int hashInterval;
  final Uint8List _initial;
  final List<Map<int, InputCommand>> _frames = <Map<int, InputCommand>>[];
  final Map<int, int> _checkpoints = <int, int>{};
  WorldState _lastState;

  int get frameCount => _frames.length;

  /// [inputs] are what was passed to `step`, [after] is what it returned.
  void record(Map<int, InputCommand> inputs, WorldState after) {
    _frames.add(Map<int, InputCommand>.of(inputs));
    if (after.tick % hashInterval == 0) {
      _checkpoints[after.tick] = hashState(after);
    }
    _lastState = after;
  }

  Replay finish() => Replay(
        dataVersion: dataVersion,
        hashInterval: hashInterval,
        initialState: _initial,
        frames: List<Map<int, InputCommand>>.of(_frames),
        checkpoints: Map<int, int>.of(_checkpoints),
        finalHash: hashState(_lastState),
      );
}

/// Thrown when a replay does not reproduce its recorded hashes.
class ReplayDesync implements Exception {
  ReplayDesync({
    required this.tick,
    required this.expected,
    required this.actual,
  });

  final int tick;
  final int expected;
  final int actual;

  @override
  String toString() => 'ReplayDesync at tick $tick: expected '
      '${expected.toRadixString(16)}, got ${actual.toRadixString(16)}';
}

class ReplayResult {
  const ReplayResult({required this.finalState, required this.finalHash});

  final WorldState finalState;
  final int finalHash;
}

abstract final class ReplayPlayer {
  /// Re-simulates [replay] and checks every checkpoint plus the final hash.
  /// Throws [ReplayDesync] on the first mismatch.
  static ReplayResult play(
    Simulation sim,
    Replay replay, {
    void Function(WorldState state)? onTick,
  }) {
    var s = const SnapshotCodec().decode(replay.initialState);
    for (final frame in replay.frames) {
      s = sim.step(s, frame);
      onTick?.call(s);
      final expected = replay.checkpoints[s.tick];
      if (expected != null) {
        final actual = hashState(s);
        if (actual != expected) {
          throw ReplayDesync(tick: s.tick, expected: expected, actual: actual);
        }
      }
    }
    final h = hashState(s);
    if (h != replay.finalHash) {
      throw ReplayDesync(tick: s.tick, expected: replay.finalHash, actual: h);
    }
    return ReplayResult(finalState: s, finalHash: h);
  }
}

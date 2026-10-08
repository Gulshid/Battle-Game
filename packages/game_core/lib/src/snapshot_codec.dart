import 'dart:typed_data';

import 'package:game_core/src/bit_io.dart';
import 'package:game_core/src/constants.dart';
import 'package:game_core/src/defs.dart';
import 'package:game_core/src/state.dart';

/// Bump when the byte layout changes. Old replays then fail loudly.
const int kSnapshotVersion = 1;

const int _kindFull = 1;
const int _kindDelta = 2;

/// Binary snapshot format (ADR-005, ADR-012).
///
/// Everything in [WorldState] is serialised exactly. Positions are already
/// integer 1/16 px, so there is no quantisation loss and the encoded bytes are
/// a canonical form of the state (used for hashing and replay).
///
/// Ranges (encode throws [RangeError] if exceeded): positions +-32767 px,
/// velocities +-127 px/tick, class id 0..15, projectile slot 0..3.
class SnapshotCodec {
  const SnapshotCodec();

  /// The complete state.
  Uint8List encode(WorldState s) {
    final w = BitWriter()
      ..writeUint(kSnapshotVersion, 8)
      ..writeUint(_kindFull, 8)
      ..writeVarUint(s.tick)
      ..writeUint(s.rng, 32)
      ..writeVarUint(s.nextProjectileId);
    final ids = s.sortedPlayerIds;
    w.writeVarUint(ids.length);
    for (final id in ids) {
      _writePlayer(w, s.players[id]!);
    }
    w.writeVarUint(s.projectiles.length);
    for (final p in s.projectiles) {
      _writeProjectile(w, p);
    }
    return w.toBytes();
  }

  WorldState decode(Uint8List bytes) {
    final r = BitReader(bytes);
    _readHeader(r, _kindFull);
    final tick = r.readVarUint();
    final rng = r.readUint(32);
    final nextId = r.readVarUint();
    final players = <int, PlayerState>{};
    final pc = r.readVarUint();
    for (var i = 0; i < pc; i++) {
      final p = _readPlayer(r);
      players[p.id] = p;
    }
    final projectiles = <Projectile>[];
    final prc = r.readVarUint();
    for (var i = 0; i < prc; i++) {
      projectiles.add(_readProjectile(r));
    }
    return WorldState(
      tick: tick,
      players: players,
      projectiles: projectiles,
      rng: rng,
      nextProjectileId: nextId,
    );
  }

  /// Only what changed since [base] (an entity that is identical is skipped).
  /// The receiver must hold exactly [base] (same tick) to apply it.
  Uint8List encodeDelta(WorldState base, WorldState cur) {
    final w = BitWriter()
      ..writeUint(kSnapshotVersion, 8)
      ..writeUint(_kindDelta, 8)
      ..writeVarUint(base.tick)
      ..writeVarUint(cur.tick)
      ..writeUint(cur.rng, 32)
      ..writeVarUint(cur.nextProjectileId);

    final removedPlayers = <int>[
      for (final id in base.sortedPlayerIds)
        if (!cur.players.containsKey(id)) id,
    ];
    final changedPlayers = <PlayerState>[
      for (final id in cur.sortedPlayerIds)
        if (!_samePlayer(base.players[id], cur.players[id]!)) cur.players[id]!,
    ];
    w.writeVarUint(removedPlayers.length);
    for (final id in removedPlayers) {
      w.writeVarUint(id);
    }
    w.writeVarUint(changedPlayers.length);
    for (final p in changedPlayers) {
      _writePlayer(w, p);
    }

    final baseProj = <int, Projectile>{
      for (final p in base.projectiles) p.id: p,
    };
    final curIds = <int>{for (final p in cur.projectiles) p.id};
    final removedProj = <int>[
      for (final p in base.projectiles)
        if (!curIds.contains(p.id)) p.id,
    ];
    final changedProj = <Projectile>[
      for (final p in cur.projectiles)
        if (!_sameProjectile(baseProj[p.id], p)) p,
    ];
    w.writeVarUint(removedProj.length);
    for (final id in removedProj) {
      w.writeVarUint(id);
    }
    w.writeVarUint(changedProj.length);
    for (final p in changedProj) {
      _writeProjectile(w, p);
    }
    return w.toBytes();
  }

  /// Rebuilds the newer state from [base] plus a delta made by [encodeDelta].
  /// Throws [StateError] if [base] is not the state the delta was made from.
  WorldState applyDelta(WorldState base, Uint8List bytes) {
    final r = BitReader(bytes);
    _readHeader(r, _kindDelta);
    final baseTick = r.readVarUint();
    if (baseTick != base.tick) {
      throw StateError('Delta is for base tick $baseTick, have ${base.tick}');
    }
    final tick = r.readVarUint();
    final rng = r.readUint(32);
    final nextId = r.readVarUint();

    final out = base.copy();
    final removedPlayers = r.readVarUint();
    for (var i = 0; i < removedPlayers; i++) {
      out.players.remove(r.readVarUint());
    }
    final changedPlayers = r.readVarUint();
    for (var i = 0; i < changedPlayers; i++) {
      final p = _readPlayer(r);
      out.players[p.id] = p;
    }

    final projById = <int, Projectile>{
      for (final p in out.projectiles) p.id: p,
    };
    final removedProj = r.readVarUint();
    for (var i = 0; i < removedProj; i++) {
      projById.remove(r.readVarUint());
    }
    final changedProj = r.readVarUint();
    for (var i = 0; i < changedProj; i++) {
      final p = _readProjectile(r);
      projById[p.id] = p;
    }
    out
      ..tick = tick
      ..rng = rng
      ..nextProjectileId = nextId
      ..projectiles = (projById.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id)));
    return out;
  }

  // ------------------------------------------------------------- entities

  void _readHeader(BitReader r, int expectedKind) {
    final version = r.readUint(8);
    if (version != kSnapshotVersion) {
      throw FormatException('Unsupported snapshot version $version');
    }
    final kind = r.readUint(8);
    if (kind != expectedKind) {
      throw FormatException('Expected snapshot kind $expectedKind, got $kind');
    }
  }

  void _writePlayer(BitWriter w, PlayerState p) {
    w
      ..writeVarUint(p.id)
      ..writeVarUint(p.team)
      ..writeUint(p.classId, 4)
      ..writeInt(p.x, 20)
      ..writeInt(p.y, 20)
      ..writeInt(p.vx, 12)
      ..writeInt(p.vy, 12)
      ..writeInt(p.kbx, 12)
      ..writeInt(p.kby, 12)
      ..writeUint(p.facing, 8)
      ..writeVarUint(p.hp)
      ..writeBool(value: p.alive)
      ..writeVarUint(p.respawnTick)
      ..writeVarUint(p.invulnTicks);
    for (final c in p.cooldowns) {
      w.writeVarUint(c);
    }
    w
      ..writeUint(p.castSlot + 1, 3)
      ..writeVarUint(p.castLeft)
      ..writeUint(p.castAim, 8)
      ..writeVarUint(p.channelLeft)
      ..writeVarUint(p.dashLeft)
      ..writeUint(p.dashAim, 8)
      ..writeVarUint(p.iframeTicks);
    for (var e = 0; e < kEffectCount; e++) {
      w
        ..writeVarUint(p.statusTicks[e])
        ..writeVarUint(p.statusMag[e]);
    }
    w
      ..writeVarUint(p.burnSource + 1)
      ..writeVarUint(p.kills)
      ..writeVarUint(p.deaths);
  }

  PlayerState _readPlayer(BitReader r) {
    final id = r.readVarUint();
    final team = r.readVarUint();
    final classId = r.readUint(4);
    final x = r.readInt(20);
    final y = r.readInt(20);
    final vx = r.readInt(12);
    final vy = r.readInt(12);
    final kbx = r.readInt(12);
    final kby = r.readInt(12);
    final facing = r.readUint(8);
    final hp = r.readVarUint();
    final alive = r.readBool();
    final respawnTick = r.readVarUint();
    final invuln = r.readVarUint();
    final cooldowns = <int>[
      for (var i = 0; i < kSlotCount; i++) r.readVarUint(),
    ];
    final castSlot = r.readUint(3) - 1;
    final castLeft = r.readVarUint();
    final castAim = r.readUint(8);
    final channelLeft = r.readVarUint();
    final dashLeft = r.readVarUint();
    final dashAim = r.readUint(8);
    final iframes = r.readVarUint();
    final sTicks = <int>[];
    final sMag = <int>[];
    for (var e = 0; e < kEffectCount; e++) {
      sTicks.add(r.readVarUint());
      sMag.add(r.readVarUint());
    }
    final burnSource = r.readVarUint() - 1;
    final kills = r.readVarUint();
    final deaths = r.readVarUint();
    return PlayerState(
      id: id,
      x: x,
      y: y,
      team: team,
      classId: classId,
      vx: vx,
      vy: vy,
      kbx: kbx,
      kby: kby,
      facing: facing,
      hp: hp,
      alive: alive,
      respawnTick: respawnTick,
      invulnTicks: invuln,
      cooldowns: cooldowns,
      castSlot: castSlot,
      castLeft: castLeft,
      castAim: castAim,
      channelLeft: channelLeft,
      dashLeft: dashLeft,
      dashAim: dashAim,
      iframeTicks: iframes,
      statusTicks: sTicks,
      statusMag: sMag,
      burnSource: burnSource,
      kills: kills,
      deaths: deaths,
    );
  }

  void _writeProjectile(BitWriter w, Projectile p) {
    w
      ..writeVarUint(p.id)
      ..writeVarUint(p.owner)
      ..writeVarUint(p.team)
      ..writeUint(p.classId, 4)
      ..writeUint(p.slot, 2)
      ..writeInt(p.x, 20)
      ..writeInt(p.y, 20)
      ..writeInt(p.vx, 12)
      ..writeInt(p.vy, 12)
      ..writeVarUint(p.life);
  }

  Projectile _readProjectile(BitReader r) {
    final id = r.readVarUint();
    final owner = r.readVarUint();
    final team = r.readVarUint();
    final classId = r.readUint(4);
    final slot = r.readUint(2);
    final x = r.readInt(20);
    final y = r.readInt(20);
    final vx = r.readInt(12);
    final vy = r.readInt(12);
    final life = r.readVarUint();
    return Projectile(
      id: id,
      owner: owner,
      team: team,
      classId: classId,
      slot: slot,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      life: life,
    );
  }

  // ------------------------------------------------------- change detection

  bool _samePlayer(PlayerState? a, PlayerState b) {
    if (a == null) return false;
    final wa = BitWriter();
    final wb = BitWriter();
    _writePlayer(wa, a);
    _writePlayer(wb, b);
    return _sameBytes(wa.toBytes(), wb.toBytes());
  }

  bool _sameProjectile(Projectile? a, Projectile b) {
    if (a == null) return false;
    final wa = BitWriter();
    final wb = BitWriter();
    _writeProjectile(wa, a);
    _writeProjectile(wb, b);
    return _sameBytes(wa.toBytes(), wb.toBytes());
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

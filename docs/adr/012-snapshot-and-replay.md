# ADR-012: Snapshot, delta, hash and replay format
Status: Accepted
Date: 2026-10-08

## Decision
- `SnapshotCodec` writes the complete `WorldState` with `BitWriter`
  (fixed-width fields where bounded, varints elsewhere). It is lossless:
  positions are already 1/16 px integers.
- The full snapshot bytes are the canonical form of a state. `hashState` is
  FNV-1a 32 over those bytes (written with shifts so it matches on web).
- Deltas are per entity: an unchanged player or projectile is skipped, a
  changed one is sent whole. A delta names its base tick and refuses to apply
  to any other state.
- A replay = initial snapshot + inputs for every tick (repeat flag per player)
  + a state hash every N ticks + the final hash. `ReplayPlayer.play` throws
  `ReplayDesync` at the first mismatching tick.
- `kSnapshotVersion` and `kReplayVersion` guard the layouts.

## Limits (encode throws RangeError instead of clipping)
Positions +-32767 px, velocities +-127 px/tick, class id 0..15, projectile
slot 0..3, input axes -128..127.

## Consequences
- Field-level deltas can come later (Phase 06 bandwidth work) without
  changing the hash or replay format.
- Events (`WorldState.events`) are output only and not serialised here;
  Phase 05 sends them as separate reliable messages.

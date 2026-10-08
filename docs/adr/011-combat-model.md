# ADR-011: Combat model and determinism rules
Status: Accepted
Date: 2026-10-08

## Context
Combat must run identically on the client (prediction) and on the server
(authority), and stay replayable. Floating point, wall-clock time and
`Random()` all break that.

## Decision
- All combat rules live in `game_core` as `Simulation.step`.
- Integer-only maths: fixed-point positions (ADR-003), integer `isqrt`,
  byte angles with a hard-coded sin/cos table (`trig.dart`).
- Randomness only from `Rng` (xorshift32) whose state is stored in `WorldState`.
- Per-tick system order is fixed (see `simulation.dart` header).
- Hits are collected first and applied last, so same-tick kills are trades.
- One stacking rule for all status effects: longer duration, stronger
  magnitude, one instance per type.
- Abilities and classes are JSON (`packages/game_data/data`), in designer units
  (ms, px). They are converted to ticks and fixed-point once, at load time.
- Bots live in `game_core` but are not part of the simulation: they only
  produce `InputCommand`s, which replays record.

## Alternatives considered
- Doubles with tolerance: rejected, cannot be hashed or replayed exactly.
- Physics engine (forge2d): rejected, non-deterministic across platforms.

## Consequences
- Any change to rules changes replay hashes: the golden replay test fails and
  must be re-recorded deliberately. Bump `kDataVersion` for data changes.

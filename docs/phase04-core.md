# Phase 04: Shared deterministic core

## What exists in game_core
- `Simulation.step(state, inputs)`: all rules, integer only.
- `Rng`, `trig.dart` (tables, isqrt, angleOf), `BitWriter/BitReader`.
- `SnapshotCodec`: full + delta snapshots.
- `hashState` for desync detection.
- `ReplayRecorder / Replay / ReplayPlayer`.
- `BotBrain`, `DpsMeter`.

## Client refactor
`LocalMatch` owns sim, clock, bots, input, recorder and stats.
`BattleGame` is a thin renderer: reads `LocalMatch.curr/prev`, turns
`GameEvent`s into effects. `MatchPage` + `MatchHud` are Flutter widgets that
never touch the world directly.

## Golden replay
`packages/game_data/test/golden_replay_test.dart` records
`test/golden/arena_ffa.replay` on its first run. Commit that file. From then
on every test run must reproduce its hashes. If you change rules on purpose,
delete the file, re-run, commit the new one.

## Exit criteria checklist
- [x] Running the same replay twice yields an identical state hash
- [x] Offline game plays through the new core (F4 in game verifies live)
- [ ] 90%+ coverage on game_core: run `dart test --coverage` and check

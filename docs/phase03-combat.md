# Phase 03: Offline combat prototype

## What exists
- 3 classes (Warrior, Archer, Mage) + a training Dummy, all from JSON.
- Movement with acceleration and friction, dash with i-frames, knockback.
- Ability kinds: melee arc, projectile (multi-shot), AoE, channel (hold the
  key, pulses), self buff.
- Status effects: stun, slow, burn, shield, haste.
- Damage pipeline: armor -> shield -> HP -> knockback -> effects, with events.
- Bots (chase, strafe, kite, flee, dash, ability use) with 3 difficulties.
- Game feel: hit-stop (visual), white flash, camera shake, damage numbers,
  swing/ring effects, cast telegraphs, health bars, status dots.
- Training arena with spawnable dummies and a rolling DPS meter.
- Aim assist (56 degree cone) so touch input can hit things.

## Controls
WASD move, Space attack, Q ability 1, E ability 2 (hold for the Mage storm),
Shift dash. On touch: stick + on-screen buttons. F3 debug, F4 verify replay.

## Tuning
Edit `packages/game_data/data/*.json`, then `dart run melos run data`.
Units: ms, px, px/s, degrees. `game_data/test/balance_test.dart` keeps basic
attack time-to-kill between 1 and 9 seconds.

## Not done yet (deliberately)
- Charged attacks (hold to power up). Channelled abilities exist.
- Real combat sprites per class (all use the placeholder warrior sheet,
  tinted by class).
- 10 external playtesters: that one is on you, see below.

## Exit criteria checklist
- [ ] 10 external playtesters confirm combat is fun and readable
- [x] No gameplay logic depends on Flutter widgets or frame rate

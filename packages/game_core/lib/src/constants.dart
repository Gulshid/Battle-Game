/// Single source of truth for the simulation rate (see ADR-002).
const int kSimHz = 30;
const double kSimDt = 1 / kSimHz; // renderer-side use only

/// Fixed-point: 1 unit = 1/16 px.
const int kFixedShift = 4;
const int kFixedOne = 1 << kFixedShift;

/// 180 px/s at 30 Hz = 6 px/tick.
const int kMoveSpeedPerTick = 6 * kFixedOne;

/// Tiles are 32 px (a power of two so tile lookup is a shift, which also
/// floors correctly for negative coordinates).
const int kTileSizePx = 32;
const int kTileShift = 5 + kFixedShift;
const int kTileSize = 1 << kTileShift;

/// Player collision radius: 14 px.
const int kPlayerRadius = 14 * kFixedOne;

// ---------------------------------------------------------------- Phase 03

/// Trig lookup tables are scaled by this (cos 0 == 4096).
const int kTrigScale = 4096;

/// Angles are bytes: 0..255 maps to 0..2*pi. 0 = +x (right), 64 = +y (down).
const int kAngleSteps = 256;

/// Ability slots: 0 attack, 1 ability1, 2 ability2, 3 dash.
const int kSlotCount = 4;
const int kDashSlot = 3;

/// Bit indices inside [InputCommand.buttons].
const int kBtnAttack = 0;
const int kBtnAbility1 = 1;
const int kBtnAbility2 = 2;
const int kBtnDash = 3;

/// Knockback velocity is multiplied by 205/256 (~0.8) every tick, so the
/// total slide distance is about 5x the initial per-tick speed.
const int kKnockbackDecayNum = 205;
const int kKnockbackStop = 8; // below 0.5 px/tick the slide stops

/// Burn deals its damage every 0.5 s.
const int kBurnIntervalTicks = kSimHz ~/ 2;

/// Slow can never reduce speed below this percentage.
const int kMinSpeedPct = 20;

/// Single source of truth for the simulation rate (see ADR-002).
const int kSimHz = 30;
const double kSimDt = 1 / kSimHz; // renderer-side use only

/// Fixed-point: 1 unit = 1/16 px.
const int kFixedShift = 4;
const int kFixedOne = 1 << kFixedShift;

/// 180 px/s at 30 Hz = 6 px/tick.
const int kMoveSpeedPerTick = 6 * kFixedOne;

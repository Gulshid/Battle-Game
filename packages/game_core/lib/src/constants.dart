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

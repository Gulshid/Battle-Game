# Conventions
- Gameplay lives in game_core. Flame components only read state and render.
- Simulation ticks at kSimHz; rendering interpolates with FixedTimestep.alpha.
- Input is sampled once per sim tick into InputCommand.
- Positions are fixed-point ints in game_core; floats only in rendering.
- Pool anything spawned frequently (projectiles, sparks, damage numbers).
- Camera shake is visual only.

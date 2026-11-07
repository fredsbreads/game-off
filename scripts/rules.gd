class_name Rules
extends RefCounted
## Every gameplay number lives here, so the game, the chunk validator and the
## debug bot all agree on exactly the same rules.
##
## Gameplay positions are measured in TILES (floats), not pixels. Multiply by
## TILE to draw. The player's x is the centre of their feet.

const TILE := 64.0
const GROUND_Y := 448.0          # pixel y of the ground surface
const PHYSICS_FPS := 60

# Teleport distances, in tiles.
const SHORT := 3.0
const LONG := 6.0

# Distance (tiles) you run before you can teleport again. Measured in
# distance, not time, so chunk spacing works the same at every speed.
# (1.05 tiles = ~0.18 s at the start speed, ~0.12 s at max.) A kill resets it.
const COOLDOWN_TILES := 1.05

# Landing within this many tiles of an enemy's centre kills it.
const KILL_RADIUS := 0.8
# Running within this many tiles of a live enemy's centre kills you.
const HIT_RADIUS := 0.55

# Hazards (pits, spikes) must be too wide for a short jump but clearable
# with a long one.
const HAZARD_MIN := 4
const HAZARD_MAX := 5
const MIN_HAZARD_GAP := 5       # ground tiles between hazards, unless an enemy is in the gap
const EDGE_PADDING := 2         # plain ground at both ends of every chunk

# Run speed in tiles per second, ramping up with distance.
const SPEED_START := 6.0
const SPEED_MAX := 10.0
const SPEED_RAMP_TILES := 2000.0

# Scoring.
const COMBO_WINDOW := 1.5       # seconds without a kill before the chain breaks
const KILL_POINTS := 100        # multiplied by the chain count

enum Tile { GROUND, PIT, SPIKES }


static func speed_at(distance: float) -> float:
	return lerpf(SPEED_START, SPEED_MAX, clampf(distance / SPEED_RAMP_TILES, 0.0, 1.0))


static func cooldown_frames(speed: float) -> int:
	return ceili(COOLDOWN_TILES / speed * PHYSICS_FPS)


static func is_hazard(tile: int) -> bool:
	return tile != Tile.GROUND

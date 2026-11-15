class_name Rules
extends RefCounted
## Every gameplay number lives here, so the game, the chunk validator and the
## debug bot all agree on exactly the same rules.
##
## Gameplay positions are measured in TILES (floats), not pixels. Multiply by
## TILE to draw. The player's x is the centre of their feet.

const TILE := 64.0
const GROUND_Y := 448.0          # pixel y of the floor surface
const PHYSICS_FPS := 60

# Two rows: you run along the floor, or upside down along the ceiling.
const ROW_GAP := 4.5             # tiles between the floor and ceiling surfaces
const CEILING_Y := GROUND_Y - ROW_GAP * TILE   # pixel y of the ceiling surface
enum Row { FLOOR, CEILING }

# Teleports: forward along your row, straight across to the other row, or
# diagonally (both at once).
const FORWARD := 6.0             # tiles
enum Move { NONE, FORWARD, VERTICAL, DIAGONAL }

# Time before you can teleport again, shared by every teleport. Just enough
# to stop absurdly fast spamming. A kill always resets it.
# Counted in whole frames: 0.16 s rounds up to 10 frames (~0.167 s).
const COOLDOWN_SECONDS := 0.16
# Misses in a row cost more, so mashing gets you killed: the 1st miss gets
# the normal cooldown, the 2nd 0.3 s, the 3rd and later 0.5 s. A kill resets
# the streak, and so does half a second without teleporting.
const MISS_COOLDOWN_SECONDS := [0.16, 0.3, 0.5]
const MISS_STREAK_RESET_SECONDS := 0.5

# Each teleport's landing zone (what the line under its marker shows), the
# same for all three: this many tiles behind and ahead of the landing spot.
# It reaches further ahead so pressing a little early still hits.
# After a miss, an enemy just past the zone can still be unavoidable: it's
# within HIT_RADIUS + one cooldown of running (0.75 + 1.0 = 1.75 tiles) but
# outside the zone (AHEAD + half an enemy = 1.55). That small gap is on
# purpose: it's what makes blind mashing risky.
const KILL_BEHIND := 0.8
const KILL_AHEAD := 1.25
# An enemy is killed if any part of it touches the landing zone, so the zone
# for its centre is wider by half its width (enemies are 0.6 tiles wide).
const ENEMY_HALF_WIDTH := 0.3
# Running within this many tiles of a live enemy's centre kills you: about
# where her body (sprite) touches the enemy's.
const HIT_RADIUS := 0.75

# Run speed in tiles per second. Constant for now.
const RUN_SPEED := 6.0

# Scoring.
const KILL_POINTS := 100        # multiplied by the chain count

enum Tile { GROUND, SPIKES }


static func cooldown_frames() -> int:
	return ceili(COOLDOWN_SECONDS * PHYSICS_FPS)


## Cooldown after the `misses`-th miss in a row (1 = the first).
static func miss_cooldown_frames(misses: int) -> int:
	var i := clampi(misses - 1, 0, MISS_COOLDOWN_SECONDS.size() - 1)
	return ceili(float(MISS_COOLDOWN_SECONDS[i]) * PHYSICS_FPS)


static func miss_streak_reset_frames() -> int:
	return ceili(MISS_STREAK_RESET_SECONDS * PHYSICS_FPS)


## The landing zone a marker's line shows, as [tiles behind the landing
## spot, tiles ahead]. An enemy touching it dies.
static func marker_zone(_move: int) -> Vector2:
	return Vector2(KILL_BEHIND, KILL_AHEAD)


## Kill zone for an enemy's CENTRE, as [tiles behind, tiles ahead]: the
## marker zone plus half an enemy's width each side.
static func kill_zone(move: int) -> Vector2:
	return marker_zone(move) + Vector2(ENEMY_HALF_WIDTH, ENEMY_HALF_WIDTH)


## True if an enemy at enemy_x is killed by `move` landing at landing_x.
static func in_kill_zone(move: int, enemy_x: float, landing_x: float) -> bool:
	var zone := kill_zone(move)
	var d := enemy_x - landing_x
	return d > -zone.x and d < zone.y


static func move_dx(move: int) -> float:
	return FORWARD if move == Move.FORWARD or move == Move.DIAGONAL else 0.0


static func move_flips_row(move: int) -> bool:
	return move == Move.VERTICAL or move == Move.DIAGONAL


static func surface_y(row: int) -> float:
	return GROUND_Y if row == Row.FLOOR else CEILING_Y


## Pixel y of a body's middle (player or enemy) standing/hanging in a row.
static func body_center_y(row: int) -> float:
	return GROUND_Y - TILE * 0.5 if row == Row.FLOOR else CEILING_Y + TILE * 0.5


static func is_hazard(tile: int) -> bool:
	return tile != Tile.GROUND

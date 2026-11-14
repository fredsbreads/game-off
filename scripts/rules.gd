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

# Landing within this many tiles of an enemy's centre kills it.
const KILL_RADIUS := 0.8
# The vertical teleport is more forgiving AHEAD of you only: it kills an
# enemy across from you up to this many tiles ahead (aiming straight across
# is a timing call, and a stacked pair otherwise leaves almost no window).
# Behind you it uses the normal KILL_RADIUS.
const VERTICAL_KILL_AHEAD := 1.2
# Running within this many tiles of a live enemy's centre kills you.
const HIT_RADIUS := 0.55

# Run speed in tiles per second. Constant for now.
const RUN_SPEED := 6.0

# Scoring.
const KILL_POINTS := 100        # multiplied by the chain count

enum Tile { GROUND, SPIKES }


static func cooldown_frames() -> int:
	return ceili(COOLDOWN_SECONDS * PHYSICS_FPS)


## Kill zone for a move, as [tiles behind the landing spot, tiles ahead].
static func kill_zone(move: int) -> Vector2:
	if move == Move.VERTICAL:
		return Vector2(KILL_RADIUS, VERTICAL_KILL_AHEAD)
	return Vector2(KILL_RADIUS, KILL_RADIUS)


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

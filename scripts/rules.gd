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
# Counted in whole frames: 0.2 s = 12 frames.
const COOLDOWN_SECONDS := 0.2

# Each teleport's landing zone (what the line under its marker shows), the
# same for all three: this many tiles behind and ahead of the landing spot.
# It reaches further ahead so pressing a little early still hits.
# After a miss, an enemy just past the zone can still be unavoidable: it's
# within HIT_RADIUS + one cooldown of running (0.95 + 1.2 = 2.15 tiles) but
# outside the zone (AHEAD + half an enemy = 1.55). That gap is on
# purpose: it's what makes blind mashing risky.
const KILL_BEHIND := 0.8
const KILL_AHEAD := 1.25
# An enemy is killed if any part of it touches the landing zone, so the zone
# for its centre is wider by half its width (enemies are 0.6 tiles wide).
const ENEMY_HALF_WIDTH := 0.3
# Running within this many tiles of a live enemy's centre kills you: about
# where her body (sprite) touches the enemy's.
const HIT_RADIUS := 0.95

# A kill lands you this many tiles short of the enemy (facing him at sword's
# length) instead of on top of him. Every chain step still hits: the next
# enemy then sits STRIKE_OFFSET ahead of a marker's middle, well inside the
# zone (KILL_AHEAD + ENEMY_HALF_WIDTH = 1.55).
const STRIKE_OFFSET := 0.7

# Run speed in tiles per second: full speed (the solver's, the patterns').
const RUN_SPEED := 6.0
# A run starts slower (more time to see the red katana over an enemy) and
# eases up to full speed by FULL_SPEED_LEVEL.
const START_SPEED := 4.8
const FULL_SPEED_LEVEL := 5
const SPEED_EASE := 0.4   # tiles/s per second: how gently it speeds up at a level-up
## Her speed right now (main.gd eases it toward speed_for_level).
static var speed := RUN_SPEED


static func speed_for_level(level: int) -> float:
	return lerpf(START_SPEED, RUN_SPEED, clampf(float(level - 1) / float(FULL_SPEED_LEVEL - 1), 0.0, 1.0))

# The knight (see knight.gd): each hit on her counts this many kills toward
# the progression bar, since you can't see where she'll blink ahead of time.
const KNIGHT_POINTS := 2
const KNIGHT_HITS_MIN := 3
const KNIGHT_HITS_MAX := 4
# The ninja takes more: 4-5 hits.
const NINJA_HITS_MIN := 4
const NINJA_HITS_MAX := 5
# The master takes more still: 5-6.
const MASTER_HITS_MIN := 5
const MASTER_HITS_MAX := 6

# Scoring.
const KILL_POINTS := 100        # multiplied by the chain count

enum Tile { GROUND, SPIKES }


static func cooldown_frames() -> int:
	return ceili(COOLDOWN_SECONDS * PHYSICS_FPS)


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


## A knight she's fighting at dx tiles from her (knight - her) is within her
## reach: a forward or diagonal teleport could still hit her (up to her far
## kill-zone edge), or she's at most FORWARD behind. That knight strikes when
## the freeze runs out, or as soon as she's running.
static func knight_in_reach(dx: float) -> bool:
	return dx >= -FORWARD and dx < FORWARD + kill_zone(Move.FORWARD).y


## The ninja also watches straight ahead (see ninja.gd): he's "ahead" of the
## player while she could teleport to him (in her row, under her forward
## marker: he winds up), and "too close" once he's in front of her in her row
## but nearer than that (she can't reach him: he strikes).
static func ninja_ahead(ninja_x: float, ninja_row: int, x: float, row: int) -> bool:
	return ninja_row == row and in_kill_zone(Move.FORWARD, ninja_x, x + move_dx(Move.FORWARD))


static func ninja_too_close(ninja_x: float, ninja_row: int, x: float, row: int) -> bool:
	var d := ninja_x - x
	return ninja_row == row and d > 0.0 and d <= move_dx(Move.FORWARD) - kill_zone(Move.FORWARD).x


## The master also watches diagonally (see master.gd): "ahead" while he's in
## the other row under her diagonal marker; "too close" once he's in the other
## row in front of her, nearer than that but not yet straight across (where
## her across teleport reaches him: the knight's rule).
static func master_diag_ahead(master_x: float, master_row: int, x: float, row: int) -> bool:
	return master_row != row and in_kill_zone(Move.DIAGONAL, master_x, x + move_dx(Move.DIAGONAL))


static func master_diag_too_close(master_x: float, master_row: int, x: float, row: int) -> bool:
	var d := master_x - x
	return master_row != row and d >= kill_zone(Move.VERTICAL).y and d <= move_dx(Move.DIAGONAL) - kill_zone(Move.DIAGONAL).x


## True if the player is straight across from a knight (at knight_x in
## knight_row): the player's across teleport would hit the knight.
static func knight_across(knight_x: float, knight_row: int, x: float, row: int) -> bool:
	return knight_row != row and in_kill_zone(Move.VERTICAL, knight_x, x)


## True if running from from_x to x takes the player on past a knight straight
## across: the knight was in reach of the player's across teleport and now is
## behind it.
static func knight_runs_past(knight_x: float, knight_row: int, from_x: float, x: float, row: int) -> bool:
	return knight_across(knight_x, knight_row, from_x, row) and not knight_across(knight_x, knight_row, x, row) \
			and knight_x < x


## A knight dx tiles ahead of her (negative = behind) that she's gone past
## for good: behind her and out of reach of every teleport.
static func knight_passed(dx: float) -> bool:
	return dx < -kill_zone(Move.VERTICAL).x


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

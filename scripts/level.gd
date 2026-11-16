class_name Level
extends Node2D
## Owns the endless floor and ceiling and the enemies on them.
## Builds it ahead of the player by laying enemy chains end to end: the
## hand-made patterns for levels 1-3, generated chains from level 4 (see
## patterns.gd). Draws the visible part as grey boxes.
##
## The ground is still a strip of tiles so hazards (e.g. spikes) can come
## back later as pattern steps; for now it's all plain ground.

const AHEAD_TILES := 48            # always have this much level built ahead
const RUNWAY_TILES := 16.0         # the first enemy appears this far in
const SIGN_EVERY := 50             # distance marker every N tiles

const GROUND_A := Color(0.36, 0.38, 0.44)
const GROUND_B := Color(0.32, 0.34, 0.40)
const GROUND_TOP := Color(0.55, 0.58, 0.66)
const SPIKE_COLOR := Color(0.85, 0.85, 0.9)
const SIGN_COLOR := Color(0.6, 0.62, 0.7, 0.6)

var start_x := 0.0
var tiles := PackedByteArray()
var enemies: Array[Enemy] = []
## Enemies are added here (a layer above the grey freeze effect, so they
## keep their colour during the kill pause). Set by main.gd.
var enemy_parent: Node = self
## The level whose chains are being laid out (set by main.gd).
var level := 1
## Each chain laid so far: {start, row, name, enemies}. Used to rebuild what's
## ahead on a level-up, and to name the chain the player died in.
var sections: Array = []
# Killed enemies' bodies: they stay where they fell until well behind.
var corpses: Array = []

# Practice mode: no enemies at all (N key, or the button on the pause
# screen). Static, so it stays on across retries.
static var enemies_off := false

## How much more the progression bar can take before it's full (main.gd
## keeps it up to date). Once the chains already laid could fill it, no more
## are laid until it's decided: so the chain that levels you up is the last
## one at the old level, and the new level starts on a clear screen.
var bar_room := INF
const HOLD_FROM_LEVEL := Patterns.KNIGHT_DEBUT_LEVEL - 1
var _held := false
var _knight_intro_done := false   # level 9 opens with a knight alone, once
var _cursor := RUNWAY_TILES        # where the next chain's first enemy goes
var _cursor_row := Rules.Row.FLOOR # ...and its row (the row the last one ended in)
var _rng := RandomNumberGenerator.new()
var _view_left := 0.0
var _view_size := Vector2(1024, 576)


func _ready() -> void:
	_rng.randomize()


func set_seed(value: int) -> void:
	_rng.seed = value


func ensure_generated(player_x: float) -> void:
	while _cursor < player_x + AHEAD_TILES:
		if _could_level_up(player_x):
			_held = true
			break
		if _held:
			# Picking up again (a level-up, or the chains that could have done
			# it were dropped): start just past the right edge of the screen,
			# never popping in.
			_held = false
			_cursor = maxf(_cursor, player_x + CameraRig.VIEW_TILES - CameraRig.HOME_TILES + 1.0)
		var pattern := _pick_pattern()
		if pattern.get("name", "").begins_with("knight alone"):
			_cursor_row = Rules.Row.FLOOR   # his debut: on the floor
		_append_pattern(pattern)
	while tiles.size() < _cursor + Patterns.BREAK:
		tiles.append(Rules.Tile.GROUND)


## Levels 1-3: a weighted pick from that level's hand-made pool.
## Level 4+: a freshly generated chain.
func _pick_pattern() -> Dictionary:
	if level == Patterns.KNIGHT_DEBUT_LEVEL and not _knight_intro_done:
		_knight_intro_done = true
		return Patterns.knight_alone(_rng)
	if level >= Patterns.FIRST_GENERATED_LEVEL:
		return Patterns.generate(level, _rng)
	var pool := Patterns.pool_for_level(level)
	var total := 0.0
	for entry in pool:
		total += float(entry["weight"])
	var roll := _rng.randf() * total
	var chosen: Dictionary = pool.back()["pattern"]
	for entry in pool:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			chosen = entry["pattern"]
			break
	var parsed := Patterns.parse(chosen["steps"])
	parsed["name"] = chosen["name"]
	return parsed


## True if the enemies still ahead of her could, at best (every one killed,
## a PERFECT), fill the rest of the bar. Ones she's already left behind
## (a dropped chain's leftovers) don't count: they can't level her up.
func _could_level_up(player_x: float) -> bool:
	# Early levels flow straight into each other; from the level-up into the
	# knight's debut on, each level starts on a clear screen.
	if level < HOLD_FROM_LEVEL:
		return false
	var best := 0.0
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or Rules.knight_passed(e.tile_x - player_x):
			continue
		var k := e as Knight
		best += float(Rules.KNIGHT_POINTS * k.hits_left()) if k else 1.0
	best *= float(Progression.MULTIPLIER["PERFECT"])
	return best > 0.0 and best >= bar_room - 0.001


func _append_pattern(pattern: Dictionary) -> void:
	var section := {"start": _cursor, "row": _cursor_row, "name": pattern["name"], "enemies": [], "ids": []}
	var shape: Array = pattern["enemies"]
	var knights: Array = pattern.get("knights", [])
	var last_row := _cursor_row
	var knight: Knight = null
	for i in shape.size():
		var e: Vector2 = shape[i]
		var row: int = _cursor_row if int(e.y) == 0 else 1 - _cursor_row
		last_row = row
		if enemies_off:
			continue   # keep the layout the same, just empty
		var group: int = int(knights[i]) if not knights.is_empty() else -1
		if group >= 0 and i > 0 and int(knights[i - 1]) == group:
			knight.path.append(Vector2(_cursor + e.x, row))   # one of his later spots
			continue
		var enemy: Enemy
		if group >= 0:
			knight = Knight.new()
			knight.path.append(Vector2(_cursor + e.x, row))
			enemy = knight
		else:
			enemy = Enemy.new()
		enemy.tile_x = _cursor + e.x
		enemy.row = row
		enemy_parent.add_child(enemy)
		enemies.append(enemy)
		section["enemies"].append(enemy)
		section["ids"].append(enemy.get_instance_id())
	sections.append(section)
	var last: Vector2 = shape.back()
	_cursor += last.x + Patterns.BREAK
	_cursor_row = last_row


## Switches enemies off (removes every one) or back on (enemies spawn again
## from from_x, e.g. just off the right edge of the screen).
func set_enemies_off(off: bool, from_x: float) -> void:
	enemies_off = off
	if off:
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		enemies.clear()
		for section in sections:
			section["enemies"] = []
	else:
		rebuild_ahead(from_x)


## On a level-up: throw away every chain that starts beyond `from_x` (not on
## screen yet) and lay new ones at the current level. Chains already on
## screen stay as they are.
func rebuild_ahead(from_x: float) -> void:
	while not sections.is_empty() and float(sections.back()["start"]) > from_x:
		var section: Dictionary = sections.pop_back()
		for enemy in section["enemies"]:
			var e: Enemy = enemy
			if is_instance_valid(e):
				enemies.erase(e)
				e.queue_free()
		_cursor = section["start"]
		_cursor_row = section["row"]


func tile_at(x: float) -> int:
	var i := int(floor(x))
	if i < 0 or i >= tiles.size():
		return Rules.Tile.GROUND
	return tiles[i]


## Live enemies in `row` that `move` landing at x would kill.
func enemies_hit_by(move: int, x: float, row: int) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for e in enemies:
		if e.alive and e.row == row and Rules.in_kill_zone(move, e.tile_x, x):
			found.append(e)
	return found


func enemies_at(x: float, radius: float, row: int) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for e in enemies:
		if e.alive and e.row == row and absf(e.tile_x - x) < radius:
			found.append(e)
	return found


func hazard_between(from_x: float, to_x: float) -> bool:
	for i in range(int(floor(from_x)) + 1, int(floor(to_x))):
		if i >= 0 and i < tiles.size() and Rules.is_hazard(tiles[i]):
			return true
	return false


## The instance ids of every enemy in the spawned chain (section) that the
## enemy with instance id `id` belongs to, or [] if it's not in one.
func section_ids_of(id: int) -> Array:
	for section in sections:
		if section["ids"].has(id):
			return section["ids"]
	return []


func section_name_at(x: float) -> String:
	for i in range(sections.size() - 1, -1, -1):
		if float(sections[i]["start"]) <= x:
			return "%s (starts at %.1f)" % [sections[i]["name"], sections[i]["start"]]
	return "runway"


## Frees enemies that are dead or scrolled off the left edge, and forgets
## chains that are well behind.
func prune(min_x: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if e.tile_x < min_x:
			e.queue_free()
			enemies.remove_at(i)
	for i in range(corpses.size() - 1, -1, -1):
		var c: Enemy = corpses[i]
		if not is_instance_valid(c) or c.tile_x < min_x:
			if is_instance_valid(c):
				c.queue_free()
			corpses.remove_at(i)
	while sections.size() > 1 and float(sections[1]["start"]) < min_x - 30.0:
		sections.pop_front()


## left_px and size are the visible area in world pixels.
func set_view(left_px: float, size: Vector2) -> void:
	_view_left = left_px
	_view_size = size
	queue_redraw()


func _draw() -> void:
	var t := Rules.TILE
	var gy := Rules.GROUND_Y
	var bottom := gy + _view_size.y + 64.0  # comfortably past the bottom of any screen
	var first := int(floor(_view_left / t)) - 1
	var last := first + int(_view_size.x / t) + 3

	for i in range(first, last + 1):
		var x0 := i * t
		var tile := tile_at(i)
		draw_rect(Rect2(x0, gy, t, bottom - gy), GROUND_A if i % 2 == 0 else GROUND_B)
		draw_rect(Rect2(x0, gy, t, 4), GROUND_TOP)
		if tile == Rules.Tile.SPIKES:
			for s in 2:
				var sx := x0 + s * t * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(sx + 2, gy), Vector2(sx + t * 0.25, gy - t * 0.45), Vector2(sx + t * 0.5 - 2, gy)
				]), SPIKE_COLOR)

	# Ceiling: a solid band above the ceiling surface, mirroring the floor.
	var cy := Rules.CEILING_Y
	var roof := cy - _view_size.y - 64.0
	for i in range(first, last + 1):
		var x0 := i * t
		draw_rect(Rect2(x0, roof, t, cy - roof), GROUND_A if i % 2 == 0 else GROUND_B)
		draw_rect(Rect2(x0, cy - 4, t, 4), GROUND_TOP)

	# Distance markers, so speed and progress are readable.
	if not Hud.SHOW_DISTANCE_UI:
		return
	var font := ThemeDB.fallback_font
	var first_sign := int(ceil((first - start_x) / SIGN_EVERY))
	var last_sign := int(floor((last - start_x) / SIGN_EVERY))
	for n in range(maxi(first_sign, 1), last_sign + 1):
		var sx := (start_x + n * SIGN_EVERY) * t
		draw_line(Vector2(sx, gy), Vector2(sx, gy - 90), SIGN_COLOR, 3.0)
		draw_string(font, Vector2(sx + 6, gy - 76), "%d m" % (n * SIGN_EVERY), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SIGN_COLOR)

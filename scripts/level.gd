class_name Level
extends Node2D
## Owns the endless floor and ceiling and the enemies on them.
## Builds it ahead of the player by laying random enemy patterns end to end
## (see patterns.gd), and draws the visible part as grey boxes.
##
## The ground is still a strip of tiles so hazards (e.g. spikes) can come
## back later as pattern steps; for now it's all plain ground.

const AHEAD_TILES := 48            # always have this much level built ahead
const RUNWAY_TILES := 16.0         # the first enemy appears this far in
const TILES_PER_DIFFICULTY := 200.0
const BREATHER_CHANCE := 0.15      # sometimes drop in an easy pattern
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
var section_log: Array = []        # [start_x, name], for debugging deaths

var _patterns: Array = []
var _cursor := RUNWAY_TILES        # where the next pattern's first enemy goes
var _cursor_row := Rules.Row.FLOOR # ...and its row (the row the last one ended in)
var _last_name := ""
var _rng := RandomNumberGenerator.new()
var _view_left := 0.0
var _view_size := Vector2(1024, 576)


func _ready() -> void:
	_rng.randomize()
	for p in Patterns.LIST:
		if not Patterns.INCLUDE_BEATS and Patterns.has_beats(p["steps"]):
			continue
		var parsed := Patterns.parse(p["steps"])
		if not parsed["errors"].is_empty():
			push_error("pattern %s: %s" % [p["name"], parsed["errors"]])
			continue
		parsed["name"] = p["name"]
		parsed["difficulty"] = p["difficulty"]
		_patterns.append(parsed)
	section_log.append([0.0, "runway"])


func set_seed(value: int) -> void:
	_rng.seed = value


func ensure_generated(player_x: float) -> void:
	while _cursor < player_x + AHEAD_TILES:
		_append_pattern(_pick_pattern(_cursor - start_x))
	while tiles.size() < _cursor + Patterns.BREAK:
		tiles.append(Rules.Tile.GROUND)


func _pick_pattern(at_distance: float) -> Dictionary:
	var top := clampi(1 + int(at_distance / TILES_PER_DIFFICULTY), 1, 5)
	var low := maxi(1, top - 2)
	if _rng.randf() < BREATHER_CHANCE:
		top = mini(top, 2)
		low = 1
	var candidates: Array = []
	for p in _patterns:
		var d: int = p["difficulty"]
		if d >= low and d <= top and p["name"] != _last_name:
			candidates.append(p)
	if candidates.is_empty():
		candidates = _patterns
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _append_pattern(pattern: Dictionary) -> void:
	_last_name = pattern["name"]
	section_log.append([_cursor, pattern["name"]])
	var shape: Array = pattern["enemies"]
	var last_row := _cursor_row
	for rel in shape:
		var e: Vector2 = rel
		var enemy := Enemy.new()
		enemy.tile_x = _cursor + e.x
		enemy.row = _cursor_row if int(e.y) == 0 else 1 - _cursor_row
		enemy_parent.add_child(enemy)
		enemies.append(enemy)
		last_row = enemy.row
	var last: Vector2 = shape.back()
	_cursor += last.x + Patterns.BREAK
	_cursor_row = last_row


func tile_at(x: float) -> int:
	var i := int(floor(x))
	if i < 0 or i >= tiles.size():
		return Rules.Tile.GROUND
	return tiles[i]


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


func section_name_at(x: float) -> String:
	for i in range(section_log.size() - 1, -1, -1):
		if section_log[i][0] <= x:
			return "%s (starts at %.1f)" % [section_log[i][1], section_log[i][0]]
	return "?"


## Frees enemies that are dead or scrolled off the left edge.
func prune(min_x: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if not e.alive or e.tile_x < min_x:
			e.queue_free()
			enemies.remove_at(i)


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

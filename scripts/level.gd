class_name Level
extends Node2D
## Owns the endless strip of tiles and the enemies standing on it.
## Builds it ahead of the player by appending random chunks, and draws the
## visible part as grey boxes.

const AHEAD_TILES := 48            # always have this much level built ahead
const RUNWAY_TILES := 16           # flat ground at the very start
const TILES_PER_DIFFICULTY := 200.0
const BREATHER_CHANCE := 0.15      # sometimes drop in an easy chunk
const SIGN_EVERY := 50             # distance marker every N tiles

const GROUND_A := Color(0.36, 0.38, 0.44)
const GROUND_B := Color(0.32, 0.34, 0.40)
const GROUND_TOP := Color(0.55, 0.58, 0.66)
const SPIKE_COLOR := Color(0.85, 0.85, 0.9)
const SIGN_COLOR := Color(0.6, 0.62, 0.7, 0.6)

var start_x := 0.0
var tiles := PackedByteArray()
var enemies: Array[Enemy] = []
var chunk_log: Array = []          # [start_tile, name], for debugging deaths

var _chunks: Array = []
var _last_name := ""
var _rng := RandomNumberGenerator.new()
var _view_left := 0.0
var _view_size := Vector2(1024, 576)


func _ready() -> void:
	_rng.randomize()
	for c in Chunks.LIST:
		var parsed := Chunks.parse(c["map"])
		parsed["name"] = c["name"]
		parsed["difficulty"] = c["difficulty"]
		_chunks.append(parsed)
	for i in RUNWAY_TILES:
		tiles.append(Rules.Tile.GROUND)
	chunk_log.append([0, "runway"])


func set_seed(value: int) -> void:
	_rng.seed = value


func ensure_generated(player_x: float) -> void:
	while tiles.size() < player_x + AHEAD_TILES:
		_append_chunk(_pick_chunk(tiles.size() - start_x))


func _pick_chunk(at_distance: float) -> Dictionary:
	var top := clampi(1 + int(at_distance / TILES_PER_DIFFICULTY), 1, 5)
	var low := maxi(1, top - 2)
	if _rng.randf() < BREATHER_CHANCE:
		top = mini(top, 2)
		low = 1
	var candidates: Array = []
	for c in _chunks:
		var d: int = c["difficulty"]
		if d >= low and d <= top and c["name"] != _last_name:
			candidates.append(c)
	if candidates.is_empty():
		candidates = _chunks
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _append_chunk(chunk: Dictionary) -> void:
	var base := tiles.size()
	_last_name = chunk["name"]
	chunk_log.append([base, chunk["name"]])
	tiles.append_array(chunk["tiles"])
	for local_x in chunk["enemies"]:
		var enemy := Enemy.new()
		enemy.tile_x = base + float(local_x)
		enemy.position = Vector2(enemy.tile_x * Rules.TILE, Rules.GROUND_Y)
		add_child(enemy)
		enemies.append(enemy)


func tile_at(x: float) -> int:
	var i := int(floor(x))
	if i < 0 or i >= tiles.size():
		return Rules.Tile.GROUND
	return tiles[i]


func enemies_at(x: float, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for e in enemies:
		if e.alive and absf(e.tile_x - x) < radius:
			found.append(e)
	return found


func hazard_between(from_x: float, to_x: float) -> bool:
	for i in range(int(floor(from_x)) + 1, int(floor(to_x))):
		if i >= 0 and i < tiles.size() and Rules.is_hazard(tiles[i]):
			return true
	return false


func chunk_name_at(x: float) -> String:
	for i in range(chunk_log.size() - 1, -1, -1):
		if chunk_log[i][0] <= x:
			return "%s (starts at tile %d)" % [chunk_log[i][1], chunk_log[i][0]]
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

	# Distance markers, so speed and progress are readable.
	if not Hud.SHOW_SCORE_UI:
		return
	var font := ThemeDB.fallback_font
	var first_sign := int(ceil((first - start_x) / SIGN_EVERY))
	var last_sign := int(floor((last - start_x) / SIGN_EVERY))
	for n in range(maxi(first_sign, 1), last_sign + 1):
		var sx := (start_x + n * SIGN_EVERY) * t
		draw_line(Vector2(sx, gy), Vector2(sx, gy - 90), SIGN_COLOR, 3.0)
		draw_string(font, Vector2(sx + 6, gy - 76), "%d m" % (n * SIGN_EVERY), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SIGN_COLOR)

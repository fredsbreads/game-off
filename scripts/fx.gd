class_name Fx
extends Node2D
## Short-lived visual effects: teleport trails, landing rings, slashes,
## particles and floating text. Runs on real time; main.gd sets `frozen`
## to hold them mid-air during the kill pause.

const GRAVITY := 900.0
# Her effects are all reds, each a slightly different one so they don't merge
# into one red blur: the teleport line scarlet, the landing ring darker, the
# kill ring bright, the slash streak pale, the sparks a mix.
const TRAIL_COLOR := Color(1.0, 0.25, 0.3)
const LANDING_RING_COLOR := Color(0.75, 0.12, 0.18, 0.85)
const KILL_RING_COLOR := Color(1.0, 0.35, 0.3, 0.9)
const SLASH_COLOR := Color(1.0, 0.62, 0.6)
const KILL_COLORS := [Color(1.0, 0.3, 0.28), Color(0.85, 0.08, 0.14), Color(1.0, 0.55, 0.5)]
const BLOOD_COLORS := [Color(0.9, 0.08, 0.1), Color(1.0, 0.18, 0.15), Color(0.7, 0.03, 0.06)]
const STAIN_SECONDS := 4.0   # how long a drop of blood stays on the floor

var _items: Array[Dictionary] = []
## While true, every effect holds still (used during the kill pause).
var frozen := false
## Slow motion (the death moment): effects run at this speed.
var time_scale := 1.0


## from / to are body centres in pixels.
func teleport_trail(from: Vector2, to: Vector2) -> void:
	_items.append({"kind": "trail", "t": 0.0, "life": 0.22, "a": from, "b": to})


func landing_ring(pos: Vector2) -> void:
	_ring(pos, 10.0, 46.0, 0.25, 3.0, LANDING_RING_COLOR)


## Bigger and brighter the longer the chain.
func kill_burst(pos: Vector2, combo: int) -> void:
	var c := mini(combo, 8)
	_ring(pos, 12.0, 60.0 + 10.0 * c, 0.3, 4.0 + c * 0.5, KILL_RING_COLOR)
	_items.append({"kind": "slash", "t": 0.0, "life": 0.16, "pos": pos, "len": 80.0 + 10.0 * c})
	for i in 8 + c * 3:
		var dir := Vector2.from_angle(randf_range(-PI, 0.2))
		_items.append({"kind": "particle", "t": 0.0, "life": randf_range(0.35, 0.65),
			"pos": pos, "vel": dir * randf_range(150.0, 350.0 + 40.0 * c),
			"color": KILL_COLORS[i % KILL_COLORS.size()]})


## A spray of blood from `pos`, flung mostly toward `dir_x` (+1 right, -1
## left) and upward. Drops that reach the floor leave a stain for a while.
## `burst`: start the drops this many seconds into their flight (each a
## random share of it), so a spray that freezes at once (the "your move"
## pause) is already spread out behind the enemy instead of on top of him.
## `dir_y`: -1 sprays upward (floor), +1 downward (from the ceiling).
func blood(pos: Vector2, dir_x: float, amount: int = 24, burst: float = 0.0, dir_y: float = -1.0) -> void:
	for i in amount:
		var angle := randf_range(0.1, 1.25)   # away from the surface, and forward
		var dir := Vector2(cos(angle) * dir_x, sin(angle) * dir_y)
		var vel := dir * randf_range(300.0, 750.0)
		var p := pos + Vector2(randf_range(-6, 6), randf_range(-10, 10))
		var head_start := randf_range(0.4, 1.0) * burst
		p += vel * head_start + Vector2(0, 0.5 * GRAVITY * head_start * head_start)
		vel.y += GRAVITY * head_start
		_items.append({"kind": "blood", "t": 0.0, "life": 1.5, "pos": p, "vel": vel,
			"size": randf_range(4.0, 10.0),
			"color": BLOOD_COLORS[i % BLOOD_COLORS.size()]})


## A crackle of lightning over a body centred at `pos` (her death): a few
## short jagged arcs across it, and sparks. `vel` (pixels/s) moves the arcs
## along with her; `size` is the body's half-extent the arcs stay within.
func zap(pos: Vector2, arcs: int = 2, vel: Vector2 = Vector2.ZERO, size: Vector2 = Vector2(18, 34), sparks: int = 3) -> void:
	for a in arcs:
		var start := pos + Vector2(randf_range(-1, 1) * size.x, randf_range(-1, 1) * size.y)
		var end := pos + Vector2(randf_range(-1, 1) * size.x * 1.6, randf_range(-1, 1) * size.y * 1.2)
		var pts := PackedVector2Array([start])
		var steps := 5
		for i in range(1, steps):
			var p := start.lerp(end, float(i) / steps)
			var n := (end - start).orthogonal().normalized()
			pts.append(p + n * randf_range(-8.0, 8.0))
		pts.append(end)
		_items.append({"kind": "bolt", "t": 0.0, "life": randf_range(0.06, 0.12), "pts": pts, "vel": vel})
	for i in sparks:
		var dir := Vector2.from_angle(randf() * TAU)
		_items.append({"kind": "particle", "t": 0.0, "life": randf_range(0.25, 0.45),
			"pos": pos, "vel": dir * randf_range(120.0, 320.0),
			"color": [Color(1.0, 0.95, 0.9), Color(1.0, 0.3, 0.3)][i % 2]})


## A jagged arc along a line (lightning running down her sword), moving with `vel`.
func zap_line(a: Vector2, b: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	var pts := PackedVector2Array([a])
	var steps := 5
	var n := (b - a).orthogonal().normalized()
	for i in range(1, steps):
		pts.append(a.lerp(b, float(i) / steps) + n * randf_range(-6.0, 6.0))
	pts.append(b)
	_items.append({"kind": "bolt", "t": 0.0, "life": randf_range(0.06, 0.12), "pts": pts, "vel": vel})


## Removes the lightning arcs (so frozen lightning can flicker: redrawn each time).
func clear_bolts() -> void:
	for i in range(_items.size() - 1, -1, -1):
		if _items[i]["kind"] == "bolt":
			_items.remove_at(i)


## Floating text at `pos`. `speed` (pixels/s) moves it forward: at the run
## speed it keeps pace with the player, so it stays put on screen instead of
## scrolling away with the world. `rise` 1 drifts it up as it fades, -1 down.
func text(pos: Vector2, value: String, size: int, color: Color, speed := 0.0, life := 0.7, rise := 1.0) -> void:
	_items.append({"kind": "text", "t": 0.0, "life": life, "pos": pos, "text": value, "size": size, "color": color, "speed": speed, "rise": rise})


func _ring(pos: Vector2, r0: float, r1: float, life: float, width: float, color: Color) -> void:
	_items.append({"kind": "ring", "t": 0.0, "life": life, "pos": pos, "r0": r0, "r1": r1, "width": width, "color": color})


func _process(real_delta: float) -> void:
	if frozen:
		queue_redraw()   # effects added while frozen still need drawing once
		return
	var delta := real_delta * time_scale
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		# Lightning ages on real time, so it keeps flickering in slow motion.
		it["t"] += real_delta if it["kind"] == "bolt" else delta
		if it["kind"] == "bolt":
			var shift: Vector2 = it["vel"] * delta
			var pts: PackedVector2Array = it["pts"]
			for p in pts.size():
				pts[p] += shift
			it["pts"] = pts
		if it["kind"] == "particle" or it["kind"] == "blood":
			it["vel"].y += GRAVITY * delta
			it["pos"] += it["vel"] * delta
		if it["kind"] == "blood" and it["pos"].y >= Rules.GROUND_Y:
			# Hit the floor: becomes a flat stain.
			it["kind"] = "stain"
			it["pos"].y = Rules.GROUND_Y
			it["t"] = 0.0
			it["life"] = STAIN_SECONDS
		if it["t"] >= it["life"]:
			_items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var t := Rules.TILE
	var gy := Rules.GROUND_Y
	var font := ThemeDB.fallback_font
	for it in _items:
		var k: float = it["t"] / it["life"]
		var fade := 1.0 - k
		match it["kind"]:
			"trail":
				var a: Vector2 = it["a"]
				var b: Vector2 = it["b"]
				# (The afterimages of her along the path are drawn by player.gd.)
				draw_line(a, b, Color(TRAIL_COLOR, 0.9 * fade), 1.0 + 5.0 * fade)
			"ring":
				var r := lerpf(it["r0"], it["r1"], 1.0 - pow(1.0 - k, 3.0))
				var col: Color = it["color"]
				col.a *= fade
				draw_arc(it["pos"], r, 0.0, TAU, 40, col, it["width"])
			"slash":
				var dir := Vector2(1, -0.8).normalized()
				var half: float = it["len"] / 2.0
				var pos: Vector2 = it["pos"]
				var grow := minf(1.0, k * 4.0)
				draw_line(pos - dir * half, pos - dir * half + dir * half * 2.0 * grow, Color(SLASH_COLOR, fade), 2.0 + 6.0 * fade)
			"blood":
				var s: float = it["size"]
				draw_rect(Rect2(it["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), it["color"])
			"stain":
				var col: Color = it["color"]
				col.a = minf(1.0, fade * 3.0)   # fades out over its last third
				var s: float = it["size"]
				draw_rect(Rect2(it["pos"] - Vector2(s, 2.0), Vector2(s * 2.0, 3.0)), col)
			"bolt":
				var pts: PackedVector2Array = it["pts"]
				draw_polyline(pts, Color(1.0, 0.2, 0.25, 0.9 * fade), 5.0)
				draw_polyline(pts, Color(1.0, 0.95, 0.9, fade), 2.0)
			"particle":
				var col: Color = it["color"]
				col.a = fade
				draw_rect(Rect2(it["pos"] - Vector2(3, 3), Vector2(6, 6)), col)
			"text":
				var size: int = it["size"]
				var value: String = it["text"]
				var col: Color = it["color"]
				col.a = 1.0 - k * k
				var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var base: Vector2 = it["pos"] + Vector2(float(it["speed"]) * float(it["t"]), 0.0)
				var pos: Vector2 = base - Vector2(w / 2.0, k * 50.0 * float(it["rise"]))
				draw_string_outline(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, col.a))
				draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

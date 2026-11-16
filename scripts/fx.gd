class_name Fx
extends Node2D
## Short-lived visual effects: lightning, slashes,
## particles and floating text. Runs on real time; main.gd sets `frozen`
## to hold them mid-air during the kill pause.

const GRAVITY := 900.0
# Her effects are all reds, each a slightly different one so they don't merge
# into one red blur: the slash streak pale, the sparks a mix. (The teleport
# itself is sprite lightning: see bolt().)
const SLASH_COLOR := Color(1.0, 0.62, 0.6)
const KILL_COLORS := [Color(1.0, 0.3, 0.28), Color(0.85, 0.08, 0.14), Color(1.0, 0.55, 0.5)]
const BLOOD_COLORS := [Color(0.9, 0.08, 0.1), Color(1.0, 0.18, 0.15), Color(0.7, 0.03, 0.06)]
const BLOOD_FLIGHT_SECONDS := 3.0   # a drop gets this long to reach the floor
# Blood on the floor stays until it scrolls off screen; past this many stains
# the oldest go first (a safety cap, normally never reached).
const MAX_STAINS := 1500
var _stains := 0
# Lightning sprite strips (Frostwindz "Pixel Art Skill Animations - Lightning",
# recoloured red), each one row of equal frames.
enum Bolt { THIN, THICK, STRIKE, BIG_STRIKE, RING, SPARKS }
const BOLT_SHEETS := [
	preload("res://assets/vfx/lightning_1.png"), preload("res://assets/vfx/lightning_2.png"),
	preload("res://assets/vfx/lightning_3.png"), preload("res://assets/vfx/lightning_4.png"),
	preload("res://assets/vfx/lightning_5.png"), preload("res://assets/vfx/lightning_6.png"),
]
const BOLT_FRAMES := [4, 4, 5, 5, 4, 8]
# The knight's lightning: the same strikes and sparks, green.
const BOLT_SHEETS_GREEN := {
	Bolt.STRIKE: preload("res://assets/vfx/lightning_3_green.png"),
	Bolt.SPARKS: preload("res://assets/vfx/lightning_6_green.png"),
}
const SPARK_FRAMES := [0, 1, 2, 3, 4, 5]   # the small bolts in SPARKS with something in them
const BOLT_LENGTH := 211.0   # pixels the THIN / THICK bolts span across their frame

var _items: Array[Dictionary] = []
## While true, every effect holds still (used during the kill pause).
var frozen := false
## Slow motion (the death moment): effects run at this speed.
var time_scale := 1.0
var bolt_alpha := 1.0   # lightning fades with her as she dissolves


## from / to are body centres in pixels.
## Plays one lightning animation once, on real time (it keeps going through
## the kill pause and slow motion). `pos` is the frame's centre.
## `first`: start at this frame (to play only the end of an animation).
func bolt(kind: int, pos: Vector2, angle := 0.0, size := Vector2.ONE, fps := 20.0, first := 0, green := false) -> void:
	var s := _bolt_sprite(kind, pos, angle, size, green)
	s.frame = first
	_items.append({"kind": "anim", "t": 0.0, "node": s, "fps": fps, "first": first,
		"frames": BOLT_FRAMES[kind] - first})


## A horizontal bolt (THIN or THICK) stretched to run from `a` to `b`.
func bolt_between(kind: int, a: Vector2, b: Vector2, thickness := 1.2, fps := 20.0) -> void:
	var d := b - a
	bolt(kind, (a + b) * 0.5, d.angle(), Vector2(d.length() / BOLT_LENGTH, thickness), fps)


## A strike from `a` that bursts at `b` (the teleport look).
func strike(a: Vector2, b: Vector2, green := false, fps := 18.0) -> void:
	var d := b - a
	var sy := maxf(d.length(), 40.0) / 200.0
	# The strike runs down its frame with the burst near the bottom: turn the
	# frame's "down" to point along the line and put the burst on b.
	var centre := b - d.normalized() * (STRIKE_BURST_Y - 128.0) * sy
	bolt(Bolt.STRIKE, centre, d.angle() - PI / 2.0, Vector2(1.0, sy), fps, 0, green)


const STRIKE_BURST_Y := 215.0   # pixels down the STRIKE frame where its burst is


func _bolt_sprite(kind: int, pos: Vector2, angle: float, size: Vector2, green := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = BOLT_SHEETS_GREEN[kind] if green and BOLT_SHEETS_GREEN.has(kind) else BOLT_SHEETS[kind]
	if not green:
		s.material = Palette.sprite_material()   # her colour (pink from level 10)
	s.hframes = BOLT_FRAMES[kind]
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.rotation = angle
	s.scale = size
	add_child(s)
	return s


func _remove(i: int) -> void:
	var node: Node = _items[i].get("node")
	if node:
		node.queue_free()
	_items.remove_at(i)
## Bigger and brighter the longer the chain.
func kill_burst(pos: Vector2, combo: int) -> void:
	var c := mini(combo, 8)
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
		_items.append({"kind": "blood", "t": 0.0, "life": BLOOD_FLIGHT_SECONDS, "pos": p, "vel": vel,
			"size": randf_range(4.0, 10.0),
			"color": BLOOD_COLORS[i % BLOOD_COLORS.size()]})


## A crackle of lightning over a body centred at `pos` (her death): a few
## short jagged arcs across it, and sparks. `vel` (pixels/s) moves the arcs
## along with her; `size` is the body's half-extent the arcs stay within.
func zap(pos: Vector2, arcs: int = 2, vel: Vector2 = Vector2.ZERO, size: Vector2 = Vector2(18, 34), sparks: int = 3) -> void:
	for a in arcs:
		var at := pos + Vector2(randf_range(-1, 1) * size.x, randf_range(-1, 1) * size.y)
		var s := _bolt_sprite(Bolt.SPARKS, at, randf() * TAU, Vector2.ONE * randf_range(0.6, 0.9))
		s.frame = SPARK_FRAMES.pick_random()
		_items.append({"kind": "bolt", "t": 0.0, "life": randf_range(0.06, 0.12), "node": s, "vel": vel})
	for i in sparks:
		var dir := Vector2.from_angle(randf() * TAU)
		var s := _bolt_sprite(Bolt.SPARKS, pos, randf() * TAU, Vector2.ONE * randf_range(0.3, 0.45))
		s.frame = SPARK_FRAMES.pick_random()
		_items.append({"kind": "spark", "t": 0.0, "life": randf_range(0.25, 0.45), "node": s,
			"vel": vel + dir * randf_range(120.0, 320.0)})


## A jagged arc along a line (lightning running down her sword), moving with `vel`.
func zap_line(a: Vector2, b: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	var d := b - a
	var s := _bolt_sprite(Bolt.THIN, (a + b) * 0.5, d.angle(), Vector2(d.length() / BOLT_LENGTH, 0.5))
	s.frame = randi() % BOLT_FRAMES[Bolt.THIN]
	s.flip_v = randf() < 0.5
	_items.append({"kind": "bolt", "t": 0.0, "life": randf_range(0.06, 0.12), "node": s, "vel": vel})


## Removes the lightning arcs (so frozen lightning can flicker: redrawn each time).
func clear_bolts() -> void:
	for i in range(_items.size() - 1, -1, -1):
		if _items[i]["kind"] == "bolt":
			_remove(i)


## Floating text at `pos`. `speed` (pixels/s) moves it forward: at the run
## speed it keeps pace with the player, so it stays put on screen instead of
## scrolling away with the world. `rise` 1 drifts it up as it fades, -1 down.
func text(pos: Vector2, value: String, size: int, color: Color, speed := 0.0, life := 0.7, rise := 1.0) -> void:
	_items.append({"kind": "text", "t": 0.0, "life": life, "pos": pos, "text": value, "size": size, "color": color, "speed": speed, "rise": rise})


func _process(real_delta: float) -> void:
	# Lightning animations run on real time, frozen or not.
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		if it["kind"] == "anim":
			it["t"] += real_delta
			var f := int(it["t"] * it["fps"])
			if f >= it["frames"]:
				_remove(i)
			else:
				it["node"].frame = it["first"] + f
		elif it["kind"] == "bolt" and it.has("node"):
			it["node"].modulate.a = bolt_alpha
	if frozen:
		queue_redraw()   # effects added while frozen still need drawing once
		return
	var delta := real_delta * time_scale
	var screen_left := (get_canvas_transform().affine_inverse() * Vector2.ZERO).x
	_stains = 0
	for it in _items:
		if it["kind"] == "stain":
			_stains += 1
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		if it["kind"] == "anim":
			continue
		# Lightning ages on real time, so it keeps flickering in slow motion.
		it["t"] += real_delta if it["kind"] == "bolt" else delta
		if it["kind"] == "bolt":
			it["node"].position += it["vel"] * delta
		elif it["kind"] == "spark":
			it["node"].position += it["vel"] * delta
			it["node"].rotation += 12.0 * delta
			it["node"].modulate.a = 1.0 - it["t"] / it["life"]
		if it["kind"] == "particle" or it["kind"] == "blood":
			it["vel"].y += GRAVITY * delta
			it["pos"] += it["vel"] * delta
		if it["kind"] == "blood" and it["pos"].y >= Rules.GROUND_Y:
			# Hit the floor: becomes a flat stain.
			it["kind"] = "stain"
			it["pos"].y = Rules.GROUND_Y
			it["t"] = 0.0
			_stains += 1
		if it["kind"] == "stain":
			# Stains stay until they've scrolled off the left of the screen.
			if it["pos"].x < screen_left - 64.0:
				_remove(i)
				_stains -= 1
		elif it["t"] >= it["life"]:
			_remove(i)
	# Safety cap: the oldest stains go first (items are oldest-first).
	var oldest := 0
	while _stains > MAX_STAINS and oldest < _items.size():
		if _items[oldest]["kind"] == "stain":
			_remove(oldest)
			_stains -= 1
		else:
			oldest += 1
	queue_redraw()


func _draw() -> void:
	var t := Rules.TILE
	var gy := Rules.GROUND_Y
	var font := ThemeDB.fallback_font
	for it in _items:
		if it.has("node"):
			continue   # sprites draw themselves
		var k: float = it["t"] / it["life"]
		var fade := 1.0 - k
		match it["kind"]:
			"slash":
				var dir := Vector2(1, -0.8).normalized()
				var half: float = it["len"] / 2.0
				var pos: Vector2 = it["pos"]
				var grow := minf(1.0, k * 4.0)
				draw_line(pos - dir * half, pos - dir * half + dir * half * 2.0 * grow, Color(Palette.tint(SLASH_COLOR), fade), 2.0 + 6.0 * fade)
			"blood":
				var s: float = it["size"]
				draw_rect(Rect2(it["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), it["color"])
			"stain":
				var col: Color = it["color"]   # stays until it scrolls off screen
				var s: float = it["size"]
				draw_rect(Rect2(it["pos"] - Vector2(s, 2.0), Vector2(s * 2.0, 3.0)), col)
			"particle":
				var col: Color = Palette.tint(it["color"])
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

class_name AutoOverlay
extends Control
## While the power-up's auto-chain plays itself (main.gd _auto, through its
## finale): a crackling frame of lightning round the screen in her colour,
## "AUTO" slamming in at the start, and a small "AUTO" tag that stays. A press
## while it runs (it's ignored) flares the frame and the tag, so it's clear
## the game is playing this part.

const FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")
const RED := Color(0.95, 0.15, 0.2)   # her red (her colour once she has it: Palette.tint)
const STAMP_TIME := 0.7
const EDGE := 26.0                     # how far in the frame's glow reaches (pixels)

var _active := false
var _t := 0.0          # seconds since it started
var _fade := 0.0       # 1 while active, easing out after
var _poke := 0.0       # 1 on an ignored press, easing to 0
var _arcs: Array[PackedVector2Array] = []
var _arc_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()


func set_active(on: bool) -> void:
	if on and not _active:
		_t = 0.0
	_active = on


## A press while it plays itself.
func poke() -> void:
	_poke = 1.0


func _process(delta: float) -> void:
	_t += delta
	_fade = clampf(_fade + (delta / 0.15 if _active else -delta / 0.3), 0.0, 1.0)
	_poke = maxf(_poke - delta / 0.35, 0.0)
	visible = _fade > 0.0
	if not visible:
		return
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = 0.05
		_strike()
	queue_redraw()


## Bolts running along the screen's edges.
func _strike() -> void:
	_arcs.clear()
	var n := 4 + int(4.0 * _poke)
	for i in n:
		var side := _rng.randi_range(0, 3)
		var along := _rng.randf()
		var length := _rng.randf_range(80.0, 200.0)
		var a: Vector2
		var dir: Vector2
		var inset := _rng.randf_range(3.0, 10.0)
		match side:
			0: a = Vector2(along * size.x, inset); dir = Vector2.RIGHT
			1: a = Vector2(along * size.x, size.y - inset); dir = Vector2.RIGHT
			2: a = Vector2(inset, along * size.y); dir = Vector2.DOWN
			_: a = Vector2(size.x - inset, along * size.y); dir = Vector2.DOWN
		var b := a + dir * length
		var nrm := dir.orthogonal()
		var pts := PackedVector2Array()
		for k in 9:
			var t := k / 8.0
			pts.append(a.lerp(b, t) + nrm * (0.0 if k == 0 or k == 8 else _rng.randf_range(-7.0, 7.0)))
		_arcs.append(pts)


func _draw() -> void:
	var col := Palette.tint(RED)
	var a := _fade * (0.75 + 0.25 * sin(_t * 14.0)) + 0.6 * _poke
	# The frame's glow: bands fading in from each edge.
	for i in 6:
		var d := EDGE * i / 6.0
		var w := EDGE / 6.0
		var c := Color(col, 0.16 * a * (1.0 - i / 6.0))
		draw_rect(Rect2(0, d, size.x, w), c)
		draw_rect(Rect2(0, size.y - d - w, size.x, w), c)
		draw_rect(Rect2(d, 0, w, size.y), c)
		draw_rect(Rect2(size.x - d - w, 0, w, size.y), c)
	for arc in _arcs:
		draw_polyline(arc, Color(col, 0.5 * a), 6.0, true)
		draw_polyline(arc, Color(1, 0.95, 0.95, minf(a, 1.0)), 1.6, true)
	# "AUTO": slams in big at the start, then a small tag stays near the top.
	if _active and _t < STAMP_TIME:
		var k := _t / STAMP_TIME
		var sc := lerpf(2.2, 1.0, ease(minf(k / 0.25, 1.0), 0.3))
		var alpha := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
		_draw_word("AUTO", Vector2(size.x / 2.0, size.y * 0.42), 64, sc, alpha, col)
	var tag_a := _fade * (0.85 if _t >= STAMP_TIME * 0.6 or not _active else 0.0)
	if tag_a > 0.0:
		_draw_word("AUTO", Vector2(size.x / 2.0, size.y - 34.0), 26, 1.0 + 0.35 * _poke, tag_a, col)


func _draw_word(word: String, at: Vector2, fs: int, sc: float, alpha: float, col: Color) -> void:
	var w := FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(at, 0.0, Vector2.ONE * sc)
	draw_string_outline(FONT, Vector2(-w / 2.0, fs * 0.35), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(col.darkened(0.5), alpha))
	draw_string(FONT, Vector2(-w / 2.0, fs * 0.35), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)

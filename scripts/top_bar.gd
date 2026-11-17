class_name TopBar
extends Control
## The bar across the top of the play screen, centred above the ceiling:
##  - the power-up meter: a lightning bolt that fills from the bottom with
##    CLEAN / PERFECT chains and crackles once it's full;
##  - the level, and the level bar as a katana: the blade fills from the guard
##    to the tip (white = counted, grey = this chain's kills so far, gold =
##    PERFECT's bonus growing in, grey pieces = a dropped chain's lost half
##    breaking off);
##  - the flawless streak: its number pops with every kill (bigger at 10, 25,
##    50, ...), turns gold at the reward (STREAK_GOLD_AT), and shatters when
##    it breaks.
## The control's origin is the blade's top-left corner (where it leaves the
## guard); everything else is drawn relative to it. hud.gd places it.

const FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")

# The blade.
const BLADE := Vector2(300, 14)
const TIP := 34.0            # pixels at the end that taper to the point
const SORI := 5.0            # the blade's upward curve, pixels at the tip
const STEEL := Color(0.92, 0.94, 1.0, 0.95)       # counted
const PENDING := Color(0.6, 0.62, 0.68, 0.8)      # this chain's kills, not yet counted
const EMPTY := Color(0.55, 0.6, 0.7, 0.16)
const BONUS := Color(1.0, 0.85, 0.3)              # PERFECT's extra half, growing in
const CRUMBLE := Color(0.62, 0.64, 0.7)           # a dropped chain's lost half, breaking off
const CRUMBLE_PIECE := 9.0
const CRUMBLE_FALL := 20.0
# When a chain ends, the blade acts out its grade before the kills count:
# RESULT_ACT seconds of growing / crumbling / turning solid, then a short hold.
const RESULT_ACT := 0.35
const RESULT_HOLD := 0.2

# The hilt, left of the blade.
const HABAKI := 6.0
const TSUBA := Vector2(7, 32)
const TSUKA := 66.0
const KASHIRA := 5.0
const GOLD := Color(0.86, 0.68, 0.3)
const WRAP := Color(0.62, 0.05, 0.1)       # the handle's wrap (her red)
const WRAP_UNDER := Color(0.9, 0.87, 0.8)  # what shows between the wraps

# The power-up bolt, left of the level.
const BOLT_SIZE := Vector2(30, 46)
const BOLT_POINTS := [Vector2(19, 0), Vector2(2, 26), Vector2(13, 26), Vector2(8, 46), Vector2(28, 17), Vector2(17, 17), Vector2(23, 0)]
const CHARGE_COLOR := Color(0.95, 0.15, 0.2)   # her red (her colour once she has it: Palette.tint)

# The flawless streak, right of the tip.
const STREAK_GOLD_AT := 50   # (main.gd STREAK_REWARD)
const STREAK_GOLD := Color(1.0, 0.82, 0.25)
const STREAK_MILESTONES := [10, 25]   # bigger pops (and every 25 after)
const POP_TIME := 0.18
const BREAK_TIME := 0.6

var level := 1
var _bar := 0.0
var _size := 1.0
var _pending := 0.0
var _pulse := 0.0
var _pulse_tween: Tween
var _result := {}
var _result_t := 0.0

var _charge := 0.0
var _charged := false
var _charge_pop := 0.0
var _arcs: Array[PackedVector2Array] = []
var _arc_timer := 0.0
var _rng := RandomNumberGenerator.new()   # (the look only: never the game's random numbers)

var _streak := 0
var _pop := 0.0          # 1 right after a kill, easing to 0
var _pop_big := false
var _broken := 0         # the streak that just broke (shown shattering)
var _break_t := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BLADE
	_rng.randomize()


func _process(delta: float) -> void:
	if not visible:
		return
	if not _result.is_empty():
		_result_t += delta
		if _result_t >= RESULT_ACT + RESULT_HOLD:
			_result = {}
			pulse()
	_pop = maxf(_pop - delta / POP_TIME, 0.0)
	_charge_pop = maxf(_charge_pop - delta / 0.2, 0.0)
	if _break_t >= 0.0:
		_break_t += delta
		if _break_t > BREAK_TIME:
			_break_t = -1.0
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = 0.06
		_strike_arcs()
	queue_redraw()


# --- what main.gd / hud.gd tell it -------------------------------------------

func set_progress(lv: int, bar: float, bar_size: float, pending: int) -> void:
	_bar = bar
	_size = maxf(bar_size, 0.001)
	_pending = pending
	level = _result["level"] if not _result.is_empty() else lv


func set_charge(value: int, full: int, charged: bool) -> void:
	var v := clampf(float(value) / float(full), 0.0, 1.0)
	if v > _charge + 0.001:
		_charge_pop = 1.0
	_charge = v
	_charged = charged


func set_streak(n: int) -> void:
	if n > _streak:
		_pop = 1.0
		_pop_big = n in STREAK_MILESTONES or (n >= 50 and n % 25 == 0)
	elif n < _streak and _streak > 0:
		_broken = _streak
		_break_t = 0.0
	_streak = n


func show_chain_result(grade: String, kills: int, old_bar: float, bar_size: float, lv: int) -> void:
	var gain := minf(kills * float(Progression.MULTIPLIER[grade]), bar_size - old_bar)
	_result = {"grade": grade, "kills": float(kills), "base": old_bar, "gain": maxf(gain, 0.0),
		"size": maxf(bar_size, 0.001), "level": lv}
	_result_t = 0.0


## A short flare on the blade when a chain is added to it.
func pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse = 1.0
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "_pulse", 0.0, 0.35)


# --- the blade ---------------------------------------------------------------

func _top(x: float) -> float:
	var y := -SORI * pow(x / BLADE.x, 2.0)
	var u := (x - (BLADE.x - TIP)) / TIP
	if u > 0.0:
		y += BLADE.y * 0.42 * u * u   # the back curves down to the point
	return y


func _bottom(x: float) -> float:
	var y := BLADE.y - SORI * pow(x / BLADE.x, 2.0)
	var u := (x - (BLADE.x - TIP)) / TIP
	if u > 0.0:
		y -= BLADE.y * 0.58 * pow(u, 0.7)   # the edge sweeps up to it
	return y


## The blade's outline between x0 and x1 (pixels along it), moved by `off`.
func _slice(x0: float, x1: float, off := Vector2.ZERO) -> PackedVector2Array:
	x0 = clampf(x0, 0.0, BLADE.x)
	x1 = clampf(x1, 0.0, BLADE.x)
	var pts := PackedVector2Array()
	if x1 - x0 < 0.5:
		return pts
	var n := maxi(int((x1 - x0) / 6.0), 1)
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, _top(x)) + off)
	for i in range(n, -1, -1):
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, _bottom(x)) + off)
	return pts


func _fill(x0: float, x1: float, c: Color, off := Vector2.ZERO) -> void:
	var pts := _slice(x0, x1, off)
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)


func _draw_blade() -> void:
	var w := BLADE.x
	_fill(0.0, w, EMPTY)
	if not _result.is_empty():
		_draw_result()
	else:
		var filled := w * clampf(_bar / _size, 0.0, 1.0)
		var pending := minf(w * _pending / _size, w - filled)
		if pending > 0.0:
			_fill(filled, filled + pending, PENDING)
		if filled > 0.0:
			_fill(0.0, filled, STEEL)
	# The edge (bottom) catches the light; the back stays dark; the outline flares on a pulse.
	var edge := PackedVector2Array()
	var back := PackedVector2Array()
	for i in 51:
		var x := w * i / 50.0
		edge.append(Vector2(x, _bottom(x)))
		back.append(Vector2(x, _top(x)))
	var outline := _slice(0.0, w)
	outline.append(outline[0])
	if _pulse > 0.0:
		draw_polyline(outline, Color(1, 1, 1, 0.35 * _pulse), 6.0 * _pulse + 2.0, true)
	draw_polyline(outline, Color(1, 1, 1, 0.4 + 0.6 * _pulse), 1.5, true)
	draw_polyline(edge, Color(1, 1, 1, 0.55), 1.0, true)
	draw_polyline(back, Color(0.15, 0.17, 0.2, 0.6), 1.0, true)


func _draw_result() -> void:
	var w := BLADE.x
	var px := w / float(_result["size"])
	var base := minf(float(_result["base"]) * px, w)
	var kills := minf(float(_result["kills"]) * px, w - base)
	var gain := minf(float(_result["gain"]) * px, w - base)
	var p := ease(clampf(_result_t / RESULT_ACT, 0.0, 1.0), 0.4)   # fast start, soft end
	var hold := clampf((_result_t - RESULT_ACT) / RESULT_HOLD, 0.0, 1.0)
	if base > 0.0:
		_fill(0.0, base, STEEL)
	match _result["grade"]:
		"PERFECT":
			# The kills turn solid while the bonus half grows in gold beside them.
			_fill(base, base + kills, PENDING.lerp(STEEL, p))
			var extra := maxf(gain - kills, 0.0) * p
			if extra > 0.0:
				_fill(base + kills, base + kills + extra, BONUS.lerp(STEEL, hold))
		"DROPPED":
			# The kept half turns solid while the lost half breaks off and falls.
			_fill(base, base + gain, PENDING.lerp(STEEL, p))
			var x := base + gain
			var i := 0
			while x < base + kills - 0.01:
				var pw := minf(CRUMBLE_PIECE, base + kills - x)
				var fall := CRUMBLE_FALL * p * (0.7 + 0.15 * (i % 3))
				_fill(x + 1.0, x + pw - 1.0, Color(CRUMBLE, 1.0 - p), Vector2(0, fall))
				x += pw
				i += 1
		_:   # CLEAN, SINGLE: counts as it is
			_fill(base, base + kills, PENDING.lerp(STEEL, p))


func _draw_hilt() -> void:
	var mid := BLADE.y / 2.0
	# Habaki (the gold collar), tsuba (the guard), tsuka (the wrapped handle), kashira (the cap).
	draw_rect(Rect2(-HABAKI, -1.0, HABAKI, BLADE.y + 2.0), GOLD)
	var tsuba := Rect2(-HABAKI - TSUBA.x, mid - TSUBA.y / 2.0, TSUBA.x, TSUBA.y)
	draw_rect(tsuba, Color(0.1, 0.08, 0.08))
	draw_rect(tsuba, GOLD, false, 1.5)
	var h := BLADE.y * 0.95
	var handle := Rect2(tsuba.position.x - TSUKA, mid - h / 2.0, TSUKA, h)
	draw_rect(handle, WRAP_UNDER)
	# The wrap: bands crossing over, leaving diamonds.
	var step := 11.0
	var x := handle.position.x
	while x < handle.end.x - 0.1:
		var x1 := minf(x + step, handle.end.x)
		var cx := (x + x1) / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, handle.position.y), Vector2(x1, handle.position.y), Vector2(cx, mid)]), WRAP)
		draw_colored_polygon(PackedVector2Array([Vector2(x, handle.end.y), Vector2(x1, handle.end.y), Vector2(cx, mid)]), WRAP)
		x += step
	draw_rect(handle, Color(0.15, 0.0, 0.02), false, 1.0)
	draw_rect(Rect2(handle.position.x - KASHIRA, mid - h * 0.55, KASHIRA, h * 1.1), Color(0.18, 0.14, 0.12))
	draw_rect(Rect2(handle.position.x - KASHIRA, mid - h * 0.55, KASHIRA, h * 1.1), GOLD, false, 1.0)


func _hilt_left() -> float:
	return -HABAKI - TSUBA.x - TSUKA - KASHIRA


# --- the power-up bolt -------------------------------------------------------

func _bolt_origin() -> Vector2:
	var lv_w := FONT.get_string_size(_level_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	return Vector2(_hilt_left() - 12.0 - lv_w - 26.0 - BOLT_SIZE.x, BLADE.y / 2.0 - BOLT_SIZE.y / 2.0)


func _bolt_poly(o: Vector2, scale_by := 1.0) -> PackedVector2Array:
	var c := BOLT_SIZE / 2.0
	var pts := PackedVector2Array()
	for p in BOLT_POINTS:
		pts.append(o + c + (p - c) * scale_by)
	return pts


## The part of `poly` at or below height y (keeps y >= cut).
func _below(poly: PackedVector2Array, cut: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var a_in := a.y >= cut
		var b_in := b.y >= cut
		if a_in:
			out.append(a)
		if a_in != b_in:
			var t := (cut - a.y) / (b.y - a.y)
			out.append(a.lerp(b, t))
	return out


func _strike_arcs() -> void:
	_arcs.clear()
	if not _charged:
		return
	var o := _bolt_origin()
	var c := o + BOLT_SIZE / 2.0
	for n in 3:
		var a := c + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(10.0, 18.0)
		var b := a + (a - c).normalized().rotated(_rng.randf_range(-0.8, 0.8)) * _rng.randf_range(7.0, 13.0)
		var pts := PackedVector2Array()
		var nrm := (b - a).orthogonal().normalized()
		for i in 5:
			var t := i / 4.0
			pts.append(a.lerp(b, t) + nrm * (0.0 if i == 0 or i == 4 else _rng.randf_range(-4.0, 4.0)))
		_arcs.append(pts)


func _draw_bolt() -> void:
	var col := Palette.tint(CHARGE_COLOR)
	var o := _bolt_origin()
	var s := 1.0 + 0.15 * _charge_pop
	var poly := _bolt_poly(o, s)
	if _charged:
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		for k in 3:   # glow
			draw_colored_polygon(_bolt_poly(o, s * (1.25 + 0.15 * k)), Color(col, 0.08 * pulse))
		draw_colored_polygon(poly, col.lightened(0.15 + 0.2 * pulse))
		var core := _bolt_poly(o, s * 0.55)
		draw_colored_polygon(core, Color(1, 0.95, 0.95, 0.75 * pulse))
		for arc in _arcs:
			draw_polyline(arc, Color(col, 0.9), 2.0, true)
			draw_polyline(arc, Color(1, 1, 1, 0.9), 1.0, true)
	else:
		draw_colored_polygon(poly, Color(1, 1, 1, 0.08))
		if _charge > 0.0:
			var top := lerpf(poly_bottom(poly), poly_top(poly), _charge)
			var part := _below(poly, top)
			if part.size() >= 3:
				draw_colored_polygon(part, Color(col, 0.9))
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, Color(1, 1, 1, 0.9) if _charged else Color(col.lightened(0.3), 0.75), 1.5, true)


func poly_top(poly: PackedVector2Array) -> float:
	var y := INF
	for p in poly:
		y = minf(y, p.y)
	return y


func poly_bottom(poly: PackedVector2Array) -> float:
	var y := -INF
	for p in poly:
		y = maxf(y, p.y)
	return y


# --- the flawless streak -----------------------------------------------------

func _streak_colour(n: int) -> Color:
	if n >= STREAK_GOLD_AT:
		return STREAK_GOLD
	# In her reward colour while she has it.
	return Palette.swatch().lightened(0.25) if Palette.pink > 0.5 else Color.WHITE


func _draw_streak() -> void:
	var x := BLADE.x + 22.0
	var mid := BLADE.y / 2.0
	var cap_col := _streak_colour(_streak)
	draw_string(FONT, Vector2(x, mid - 12.0), "FLAWLESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(cap_col, 0.65))
	var fs := 26
	var text := str(_streak)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var centre := Vector2(x + w / 2.0, mid + 5.0)
	# The pop: bigger right after a kill (more at a milestone), easing back.
	var pop := ease(_pop, 2.0) * (0.6 if _pop_big else 0.3)
	if _break_t < 0.0 or _break_t > 0.25:
		draw_set_transform(centre, 0.0, Vector2.ONE * (1.0 + pop))
		var a := 1.0 if _break_t < 0.0 else clampf((_break_t - 0.25) / 0.2, 0.0, 1.0)
		draw_string(FONT, Vector2(-w / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_streak_colour(_streak), a))
		draw_set_transform(Vector2.ZERO)
	if _pop_big and _pop > 0.0:   # a ring bursting out at a milestone
		draw_arc(centre, 14.0 + 30.0 * (1.0 - _pop), 0.0, TAU, 32, Color(_streak_colour(_streak), _pop * 0.8), 2.0, true)
	if _break_t >= 0.0:
		# The streak that broke: flashes red, shakes, splits and falls away.
		var t := _break_t / BREAK_TIME
		var old := str(_broken)
		var ow := FONT.get_string_size(old, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var shake := sin(_break_t * 90.0) * 4.0 * (1.0 - minf(_break_t / 0.15, 1.0))
		var drop := 60.0 * t * t
		var red := Color(1.0, 0.25, 0.3, 1.0 - t)
		for side in [-1.0, 1.0]:
			var piece_at := Vector2(x + ow / 2.0 + shake + side * 8.0 * t, mid + 5.0 + drop * (1.0 if side < 0.0 else 1.2))
			draw_set_transform(piece_at, side * 0.6 * t, Vector2.ONE)
			draw_string(FONT, Vector2(-ow / 2.0, fs * 0.35), old, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(red, red.a * 0.6))
		draw_set_transform(Vector2.ZERO)


# --- all of it ---------------------------------------------------------------

## How far it reaches left and right of its origin (for centring it).
func extent() -> Vector2:
	return Vector2(_bolt_origin().x, BLADE.x + 22.0 + 80.0)


func _level_text() -> String:
	return "LV %d" % level


func _draw() -> void:
	_draw_bolt()
	var lv := _level_text()
	var lv_w := FONT.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(FONT, Vector2(_hilt_left() - 12.0 - lv_w, BLADE.y / 2.0 + 7.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
	_draw_hilt()
	_draw_blade()
	_draw_streak()

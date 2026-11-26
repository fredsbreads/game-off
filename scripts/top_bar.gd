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


## The game's second colour: the Flawless Color picked in Options (yellow by
## default). The grip, the gold of PERFECT and of a level-up, the bolt while
## golden and the streak at its reward all use it.
static func _sec() -> Color:
	return Palette.secondary()

# The blade.
const BLADE := Vector2(330, 16)
const TIP := 24.0            # the point (kissaki): pixels at the end where the edge sweeps up to the spine
# The grip is straight and level; the blade leaves the guard level too and
# curves gently up from there to the tip.
static var sori := 18.0       # how far the tip rises (pixels)
static var straight := 0.2    # the first part of the blade that stays straight (of its length); it curves after
const TAPER := 0.15          # the blade narrows this much (of its width) from the guard to the point
const STEEL := Color(0.92, 0.94, 1.0, 0.95)       # counted
const PENDING := Color(0.6, 0.62, 0.68, 0.8)      # this chain's kills, not yet counted
const EMPTY := Color(0.55, 0.6, 0.7, 0.16)
const CRUMBLE := Color(0.62, 0.64, 0.7)           # a dropped chain's lost half, breaking off
const CRUMBLE_PIECE := 9.0
const CRUMBLE_FALL := 20.0
# When a chain ends, the blade acts out its grade before the kills count:
# RESULT_ACT seconds of growing / crumbling / turning solid, then a short hold.
const RESULT_ACT := 0.35
const RESULT_HOLD := 0.2

# The hilt, left of the blade: a thin black guard seen edge-on (tsuba), the grip (tsuka, about a third of the whole):
# yellow wrap crossing over black, so black diamonds show between, and a
# dark cap at its end (kashira).
const HABAKI := 0.0   # (no collar: the blade starts right at the guard)
const TSUBA := Vector2(7, 36)
const TSUKA := 150.0
const KASHIRA := 6.0
const HILT_BLACK := Color(0.03, 0.03, 0.04)
const WRAP_STEP := 15.0       # one diamond's length (pixels)

# Juice: a shine sweeping the blade when a chain is added; sparks off the
# fill's leading edge while it grows; a shimmer in her colour once it's
# nearly full (NEAR_FULL); and a level-up: the katana flashes white and
# swells, sparks burst off the blade, the level pops in gold, then the blade
# drains back to the new level's start.
const GLEAM_TIME := 0.35
const NEAR_FULL := 0.8
const LEVEL_UP_TIME := 0.6
const LEVEL_UP_FLASH := 0.22   # seconds the whole blade stays lit before draining
const LEVEL_UP_SWELL := 0.2    # seconds the katana swells and settles
const HIT_PULSE := 0.15        # each kill in a chain: the whole katana pulses this long

# The power-up bolt, left of the level.
const BOLT_SIZE := Vector2(36, 54)
const BOLT_POINTS := [Vector2(23, 0), Vector2(2, 31), Vector2(16, 31), Vector2(10, 54), Vector2(34, 20), Vector2(20, 20), Vector2(28, 0)]
# Space between the level and the hilt (pixels). The bolt and the streak are
# placed by hud.gd, out toward the screen's edges (bolt_x, streak_x).
const GAP_LEVEL := 22.0
const LEVEL_SIZE := 24
const CHARGE_COLOR := Color(0.95, 0.15, 0.2)   # her red (her colour once she has it: Palette.tint)

# The flawless streak, right of the tip.
const STREAK_GOLD_AT := 50   # (main.gd STREAK_REWARD)
const STREAK_MILESTONES := [10, 25]   # bigger pops (and every 25 after)
const POP_TIME := 0.18
const BREAK_TIME := 0.6

var level := 1
## Where the bolt (its left) and the streak (its left) go, in this control's
## coordinates (set by hud.gd).
var bolt_x := -400.0
var streak_x := 400.0
var _bar := 0.0
var _size := 1.0
var _pending := 0.0
var _pulse := 0.0
var _pulse_tween: Tween
var _result := {}
var _result_t := 0.0
var _gleam := -1.0          # 0..1 while the shine sweeps the blade
var _shown_level := -1
var _latest_level := 1      # the real level (shown once a chain's result is done)
var _level_up := -1.0       # seconds into the level-up (-1 = none)
var _bits: Array = []       # [pos, vel, life, max_life, colour]: sparks off the blade
var _edge_timer := 0.0
var _hit := 0.0   # 1 on a kill, easing to 0
## The power-up's auto-chain playing (hud.gd set_auto): lightning crackles
## over the whole katana until it's done.
var auto_on := false
var _blade_arcs: Array[PackedVector2Array] = []   # lightning on the katana (level-up / about to)

var _charge := 0.0
var _charged := false
var _charge_pop := 0.0
## Golden (she has her reward colour): her PERFECT chains charge double
## (main.gd CHARGE_GOLDEN_PERFECT). The bolt shows it: gold glow and rim,
## gold sparks rising, and a bigger pop with a ring per gain.
var _boosted := false
var _charge_units := 0     # the charge as counted (CHARGE_FULL is full)
var _charge_full := 10
var _charge_mult := 1.0    # how fast a PERFECT fills it now (golden 1.5, rainbow 2): its badge
var _ring_flash := {}      # arc index -> seconds since it gained
var _ring_sparks: Array = []   # [pos, vel, life, max_life, colour]
var _turn_ring := 0.0     # the ring bursting out as she turns, 1 easing to 0
const TURN_RING_TIME := 0.5
var _badge_pop := -1.0     # seconds since the speed badge appeared (-1: none)
const RING_FLASH := 0.35
const PIP_UNITS := 2       # charge per pip: one PERFECT (a CLEAN fills half)
const PIP := 9.0           # a pip's size
const PIP_GAP := 4.0
var _discharge := 0.0   # 1 as a full bolt empties (the power-up used), fading
var _boost_ring := 0.0
var _sparks: Array = []   # [position, velocity, life]
var _spark_timer := 0.0
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
	if get_tree().paused:
		queue_redraw()   # frozen with the game, but redrawn: a colour picked in Options shows at once
		return
	for k in _ring_flash.keys():
		_ring_flash[k] += delta
		if _ring_flash[k] > RING_FLASH:
			_ring_flash.erase(k)
	for sp in _ring_sparks:
		sp[0] += sp[1] * delta
		sp[1] *= 0.9
		sp[2] -= delta
	_ring_sparks = _ring_sparks.filter(func(sp: Array) -> bool: return sp[2] > 0.0)
	if _badge_pop >= 0.0:
		_badge_pop += delta
	if not _result.is_empty():
		_result_t += delta
		if _result_t < RESULT_ACT and _result["grade"] != "DROPPED":
			_edge_timer -= delta
			if _edge_timer <= 0.0:
				_edge_timer = 0.025
				_edge_sparks()
		if _result_t >= RESULT_ACT + RESULT_HOLD:
			_result = {}
			pulse()
			_show_level(_latest_level)   # (at once: no frame of the old level over the new bar)
	if _gleam >= 0.0:
		_gleam += delta / GLEAM_TIME
		if _gleam > 1.0:
			_gleam = -1.0
	if _level_up >= 0.0:
		_level_up += delta
		if _level_up > LEVEL_UP_TIME:
			_level_up = -1.0
	for b in _bits:
		b[0] += b[1] * delta
		b[1].y += 260.0 * delta   # they fall
		b[2] -= delta
	_bits = _bits.filter(func(b: Array) -> bool: return b[2] > 0.0)
	_pop = maxf(_pop - delta / POP_TIME, 0.0)
	_hit = maxf(_hit - delta / HIT_PULSE, 0.0)
	_charge_pop = maxf(_charge_pop - delta / 0.2, 0.0)
	_turn_ring = maxf(_turn_ring - delta / TURN_RING_TIME, 0.0)
	_boost_ring = maxf(_boost_ring - delta / 0.45, 0.0)
	_discharge = maxf(_discharge - delta / 0.4, 0.0)
	_update_sparks(delta)
	if _break_t >= 0.0:
		_break_t += delta
		if _break_t > BREAK_TIME:
			_break_t = -1.0
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = 0.06
		_strike_arcs()
		_strike_blade_arcs()
	queue_redraw()


# --- what main.gd / hud.gd tell it -------------------------------------------

func set_progress(lv: int, bar: float, bar_size: float, pending: int) -> void:
	_bar = bar
	_size = maxf(bar_size, 0.001)
	if pending > _pending:
		_hit = 1.0   # a kill: the whole katana pulses
	_pending = pending
	_latest_level = lv
	if not _result.is_empty() and lv > int(_result["level"]):
		# This chain levelled up: no result act, the level-up plays at once.
		_result = {}
	_show_level(_result["level"] if not _result.is_empty() else lv)


## The level, shown at once (no level-up: the tutorial skipped to level 1).
func set_level_quietly(lv: int) -> void:
	level = lv
	_shown_level = lv
	_latest_level = lv
	_level_up = -1.0
	_result = {}


func _show_level(lv: int) -> void:
	level = lv
	if _shown_level >= 0 and level > _shown_level:
		_start_level_up()
	_shown_level = level


func set_charge(value: int, full: int, charged: bool, boosted := false, mult := 1.0) -> void:
	if value > _charge_units:   # the ring's arcs that just gained: they flash and throw sparks
		var n := int(ceil(float(full) / PIP_UNITS))
		for i in n:
			var before := clampf(float(_charge_units) / PIP_UNITS - i, 0.0, 1.0)
			var after := clampf(float(value) / PIP_UNITS - i, 0.0, 1.0)
			if after > before:
				_ring_flash[i] = 0.0
				_ring_burst(i, n, after >= 1.0)
	if mult > 1.0 and _charge_mult <= 1.0:
		_badge_pop = 0.0
	if mult > _charge_mult + 0.01:   # golden, then rainbow: the bolt jumps out, as the flawless number does
		_turn_ring = 1.0
	_charge_units = value
	_charge_full = full
	_charge_mult = mult
	var v := clampf(float(value) / float(full), 0.0, 1.0)
	if v > _charge + 0.001:
		_charge_pop = 1.0
		if boosted:
			_boost_ring = 1.0
	if _charged and not charged:
		_discharge = 1.0
	_charge = v
	_charged = charged
	_boosted = boosted


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
	_gleam = 0.0


func _start_level_up() -> void:
	_level_up = 0.0
	for i in 40:   # sparks bursting off the whole blade
		var x := _rng.randf_range(0.0, BLADE.x)
		var up := _rng.randf() < 0.5
		var p := Vector2(x, _top(x) if up else _bottom(x))
		var v := Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-220.0, -90.0) if up else _rng.randf_range(20.0, 120.0))
		var life := _rng.randf_range(0.4, 0.8)
		_bits.append([p, v, life, life, Color(1, 0.95, 0.7) if i % 3 == 0 else Color.WHITE])


## True while this chain's kills (not counted yet) would fill the blade:
## finishing the chain levels up.
func _will_level() -> bool:
	return _result.is_empty() and _level_up < 0.0 and _pending > 0.0 and _bar + _pending >= _size - 0.001


## Lightning on the katana: big bolts all round it through a level-up, small
## ones crackling along the blade while a level-up is coming.
func _strike_blade_arcs() -> void:
	_blade_arcs.clear()
	var w := BLADE.x
	if _level_up >= 0.0 and _level_up < LEVEL_UP_TIME * 0.8:
		for n in 8:   # (the whole katana: grip too)
			var x := _rng.randf_range(_hilt_left(), w)
			var up := _rng.randf() < 0.5
			var a := Vector2(x, _top(x) if up else _bottom(x))
			var b := a + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-34.0, -14.0) if up else _rng.randf_range(14.0, 34.0))
			_blade_arcs.append(_zigzag(a, b, 6, 7.0))
		for n in 2:   # and along it
			var x0 := _rng.randf_range(_hilt_left(), w - 80.0)
			_blade_arcs.append(_zigzag(Vector2(x0, _centre(x0)), Vector2(x0 + 80.0, _centre(x0 + 80.0)), 8, 6.0))
	elif auto_on:
		for n in 3:   # around the whole katana
			var x := _rng.randf_range(_hilt_left(), w)
			var up := _rng.randf() < 0.5
			var a := Vector2(x, _top(x) if up else _bottom(x))
			var b := a + Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-24.0, -10.0) if up else _rng.randf_range(10.0, 24.0))
			_blade_arcs.append(_zigzag(a, b, 5, 6.0))
		var x0 := _rng.randf_range(_hilt_left(), w - 70.0)   # and one along it
		_blade_arcs.append(_zigzag(Vector2(x0, _centre(x0)), Vector2(x0 + 70.0, _centre(x0 + 70.0)), 7, 5.0))
	elif _will_level():
		for n in 2:
			var x0 := _rng.randf_range(0.0, w - 50.0)
			var x1 := x0 + _rng.randf_range(30.0, 60.0)
			_blade_arcs.append(_zigzag(Vector2(x0, _centre(x0)), Vector2(x1, _centre(x1)), 6, 6.0))


func _zigzag(a: Vector2, b: Vector2, n: int, jag: float) -> PackedVector2Array:
	var nrm := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + nrm * (0.0 if i == 0 or i == n else _rng.randf_range(-jag, jag)))
	return pts


func _draw_blade_arcs() -> void:
	for arc in _blade_arcs:
		draw_polyline(arc, Color(_sec(), 0.35), 5.0, true)
		draw_polyline(arc, Color(1, 0.97, 0.85, 0.95), 1.6, true)


## Sparks off the leading edge of the fill while a chain's kills count.
func _edge_sparks() -> void:
	var x := _growing_edge()
	if x < 0.0:
		return
	for i in 2:
		var p := Vector2(x, _rng.randf_range(_top(x), _bottom(x)))
		var v := Vector2(_rng.randf_range(20.0, 90.0), _rng.randf_range(-120.0, -30.0))
		var life := _rng.randf_range(0.25, 0.45)
		_bits.append([p, v, life, life, _sec() if _result["grade"] == "PERFECT" else Color.WHITE])


## Where the fill's growing edge is right now (pixels along the blade), or -1.
func _growing_edge() -> float:
	if _result.is_empty():
		return -1.0
	var w := BLADE.x
	var px := w / float(_result["size"])
	var base := minf(float(_result["base"]) * px, w)
	var kills := minf(float(_result["kills"]) * px, w - base)
	var gain := minf(float(_result["gain"]) * px, w - base)
	var p := ease(clampf(_result_t / RESULT_ACT, 0.0, 1.0), 0.4)
	if _result["grade"] == "PERFECT":
		return base + kills + maxf(gain - kills, 0.0) * p
	return base + kills * p

# --- the blade ---------------------------------------------------------------

## A katana, as drawn here: a level grip, the blade curving up from the guard (sori), the
## spine (top, the inside of the curve) running straight on into the point,
## the cutting edge (bottom, the outside) sweeping up to meet it there, and
## the blade narrowing a little toward the point. x: pixels along the blade
## (negative: the hilt).
func _arc(x: float) -> float:
	# Level along the grip and the first `straight` of the blade, then curving
	# up, more and more toward the tip (it leaves the straight part smoothly).
	var t := maxf(x / BLADE.x - straight, 0.0) / (1.0 - straight)
	return -sori * t * t


func _spine(x: float) -> float:
	return _arc(x)


## The sword's centre line at x (for the hilt).
func _centre(x: float) -> float:
	return _arc(x) + BLADE.y / 2.0


func _width(x: float) -> float:
	return BLADE.y * (1.0 - TAPER * x / BLADE.x)


func _top(x: float) -> float:
	var y := _spine(x)
	var u := (x - (BLADE.x - TIP)) / TIP
	if u > 0.0:
		y += _width(x) * 0.12 * u * u   # the spine dips just a touch into the point
	return y


func _bottom(x: float) -> float:
	var y := _spine(x) + _width(x)
	var u := (x - (BLADE.x - TIP)) / TIP
	if u > 0.0:
		y -= _width(x) * 0.88 * (1.0 - sqrt(maxf(1.0 - u * u, 0.0)))   # the edge curves up to the point
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
	if Settings.forest():   # (solid underneath, the grey it sat on in the simple look: no wood shows through)
		_fill(0.0, w, Color(0.34, 0.36, 0.42))
	_fill(0.0, w, EMPTY)
	if not _result.is_empty():
		_draw_result()
	else:
		var filled := w * clampf(_bar / _size, 0.0, 1.0)
		if _level_up >= 0.0:
			# Levelled up: the whole blade lit, then draining back to the new level's start.
			var k := clampf((_level_up - LEVEL_UP_FLASH) / (LEVEL_UP_TIME - LEVEL_UP_FLASH), 0.0, 1.0)
			filled = lerpf(w, filled, ease(k, 0.5))
		var pending := minf(w * _pending / _size, w - filled)
		if pending > 0.0:
			if _will_level():
				# This chain will level up once it's done: its part glows gold and
				# pulses, and lightning crackles along the blade (_draw_blade_arcs).
				var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
				_fill(filled, filled + pending, _sec().lerp(Color(1, 1, 0.9), 0.35 * beat))
			else:
				_fill(filled, filled + pending, PENDING)
		if filled > 0.0:
			_fill(0.0, filled, STEEL)
			if _level_up < 0.0 and filled / w >= NEAR_FULL:
				# Nearly there: a glint keeps running along the steel.
				var g := fmod(Time.get_ticks_msec() * 0.0009, 1.0) * (filled + 60.0) - 30.0
				_fill(maxf(g - 18.0, 0.0), minf(g + 18.0, filled), Color(1, 1, 1, 0.55))
		if _gleam >= 0.0 and filled > 0.0:
			# A shine sweeping out along what's filled.
			var gx := lerpf(-20.0, filled + 20.0, ease(_gleam, 0.6))
			_fill(maxf(gx - 22.0, 0.0), minf(gx + 22.0, filled), Color(1, 1, 1, 0.7 * (1.0 - _gleam * 0.5)))
		if _level_up >= 0.0 and _level_up < LEVEL_UP_FLASH + 0.15:
			var flash := 1.0 - clampf(_level_up / (LEVEL_UP_FLASH + 0.15), 0.0, 1.0)
			_fill(0.0, w, Color(1, 1, 1, 0.85 * flash))
	# The edge (bottom) catches the light; the back stays dark; the outline flares on a pulse.
	var edge := PackedVector2Array()
	var back := PackedVector2Array()
	for i in 51:
		var x := w * i / 50.0
		edge.append(Vector2(x, _bottom(x)))
		back.append(Vector2(x, _top(x)))
	var outline := _slice(0.0, w)
	outline.append(outline[0])
	if _level_up >= 0.0:
		var glow := 1.0 - clampf(_level_up / LEVEL_UP_TIME, 0.0, 1.0)
		draw_polyline(outline, Color(_sec(), 0.55 * glow), 10.0 * glow + 2.0, true)
	elif _will_level():
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_polyline(outline, Color(_sec(), 0.25 + 0.3 * beat), 5.0 + 3.0 * beat, true)
	if _pulse > 0.0:
		draw_polyline(outline, Color(1, 1, 1, 0.35 * _pulse), 6.0 * _pulse + 2.0, true)
	draw_polyline(outline, Color(1, 1, 1, 0.4 + 0.6 * _pulse), 1.5, true)
	draw_polyline(edge, Color(1, 1, 1, 0.55), 1.0, true)
	# The temper line (hamon): a soft wave along the blade, near the edge.
	var hamon := PackedVector2Array()
	for i in 81:
		var x := (w - TIP) * i / 80.0
		hamon.append(Vector2(x, _bottom(x) - _width(x) * (0.36 + 0.08 * sin(x * 0.22))))
	draw_polyline(hamon, Color(1, 1, 1, 0.22), 1.0, true)
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
				_fill(base + kills, base + kills + extra, _sec().lerp(STEEL, hold))
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


## A band along the sword's curve from x0 to x1, h tall, centred on it.
func _band(x0: float, x1: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(int((x1 - x0) / 6.0), 1)
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, _centre(x) - h / 2.0))
	for i in range(n, -1, -1):
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, _centre(x) + h / 2.0))
	return pts


func _draw_hilt() -> void:
	var guard_x := -HABAKI - TSUBA.x
	var grip0 := guard_x - TSUKA
	var h := BLADE.y + 3.0
	# The grip: black under, yellow wrap crossing over (black diamonds between).
	draw_colored_polygon(_band(grip0, guard_x, h), HILT_BLACK)
	var x := grip0
	while x < guard_x - 0.1:
		var x1 := minf(x + WRAP_STEP, guard_x)
		var xm := (x + x1) / 2.0
		var c0 := _centre(x)
		var c1 := _centre(x1)
		var cm := _centre(xm)
		# A black band crossing from each corner to the middle, top and bottom.
		# (They meet in the middle, so the black left between is a row of solid diamonds.)
		draw_colored_polygon(PackedVector2Array([Vector2(x, c0 - h / 2.0), Vector2(x1, c1 - h / 2.0), Vector2(xm, cm + 0.5)]), _sec())
		draw_colored_polygon(PackedVector2Array([Vector2(x, c0 + h / 2.0), Vector2(x1, c1 + h / 2.0), Vector2(xm, cm - 0.5)]), _sec())
		x = x1
	var outline := _band(grip0, guard_x, h)
	outline.append(outline[0])
	draw_polyline(outline, HILT_BLACK, 1.5, true)
	# The cap at its end.
	draw_colored_polygon(_band(grip0 - KASHIRA, grip0, h + 1.0), Color(0.12, 0.1, 0.1))
	# The guard, edge-on: a thin black disc across the sword.
	var gc := Vector2(guard_x + TSUBA.x / 2.0, _centre(guard_x + TSUBA.x / 2.0))
	var disc := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		disc.append(gc + Vector2(cos(a) * TSUBA.x / 2.0, sin(a) * TSUBA.y / 2.0))
	draw_colored_polygon(disc, HILT_BLACK)


## Over the whole katana (grip and guard as well as the blade): the level-up's
## white flash and gold glow, and a faint flash with each kill.
func _draw_whole_glow() -> void:
	var grip0 := _hilt_left()
	var grip := _band(grip0, 0.0, BLADE.y + 3.0)
	var outline := _band(grip0, 0.0, BLADE.y + 3.0)
	outline.append(outline[0])
	if _level_up >= 0.0:
		var flash := 1.0 - clampf(_level_up / (LEVEL_UP_FLASH + 0.1), 0.0, 1.0)
		if flash > 0.0:
			draw_colored_polygon(grip, Color(1, 1, 1, 0.8 * flash))
		var glow := 1.0 - clampf(_level_up / LEVEL_UP_TIME, 0.0, 1.0)
		draw_polyline(outline, Color(_sec(), 0.55 * glow), 10.0 * glow + 2.0, true)
	if _hit > 0.0:
		draw_colored_polygon(grip, Color(1, 1, 1, 0.18 * _hit))
		_fill(0.0, BLADE.x, Color(1, 1, 1, 0.18 * _hit))


func _hilt_left() -> float:
	return -HABAKI - TSUBA.x - TSUKA - KASHIRA


# --- the power-up bolt -------------------------------------------------------

func _bolt_origin() -> Vector2:
	var o := Vector2(bolt_x, BLADE.y / 2.0 - BOLT_SIZE.y / 2.0)
	if bolt_fly > 0.0:
		o += _bolt_fly_shift(o)
	return o


## 0..1: as she turns golden or rainbow the bolt (its ring and badge too) grows
## to BOLT_FLY_SCALE and back, as the flawless number does (main.gd tweens it
## the same way), nudged in just enough to stay on screen.
var bolt_fly := 0.0
const BOLT_FLY_SCALE := 1.6   # (half the flawless number's growth: it reads bigger, ring and all)

## How far the grown bolt moves in (right and down) to keep its ring on screen.
func _bolt_fly_shift(o: Vector2) -> Vector2:
	var c := o + BOLT_SIZE / 2.0
	var r := (ring_radius() + 6.0) * _boost_scale()
	var xf := get_global_transform_with_canvas()
	var k := xf.get_scale().x
	var at := xf * c
	return Vector2(maxf(0.0, r * k - at.x), maxf(0.0, r * k - at.y)) / k


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
		var a := c + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(12.0, 22.0)
		var b := a + (a - c).normalized().rotated(_rng.randf_range(-0.8, 0.8)) * _rng.randf_range(7.0, 13.0)
		var pts := PackedVector2Array()
		var nrm := (b - a).orthogonal().normalized()
		for i in 5:
			var t := i / 4.0
			pts.append(a.lerp(b, t) + nrm * (0.0 if i == 0 or i == 4 else _rng.randf_range(-4.0, 4.0)))
		_arcs.append(pts)


func _update_sparks(delta: float) -> void:
	for sp in _sparks:
		sp[0] += sp[1] * delta
		sp[2] -= delta
	_sparks = _sparks.filter(func(sp: Array) -> bool: return sp[2] > 0.0)
	if not _boosted:
		return
	_spark_timer -= delta
	while _spark_timer <= 0.0:
		_spark_timer += 0.05
		var o := _bolt_origin()
		var p := o + Vector2(_rng.randf_range(4.0, BOLT_SIZE.x - 4.0), _rng.randf_range(BOLT_SIZE.y * 0.4, BOLT_SIZE.y))
		_sparks.append([p, Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-70.0, -40.0)), _rng.randf_range(0.35, 0.6)])


func _draw_boost(o: Vector2, s: float) -> void:
	var gold := _sec()
	if _boost_ring > 0.0:   # a ring bursting out with each gain
		var c := o + BOLT_SIZE / 2.0
		draw_arc(c, 18.0 + 30.0 * (1.0 - _boost_ring), 0.0, TAU, 36, Color(gold, 0.9 * _boost_ring), 2.5, true)


func _draw_boost_front(o: Vector2) -> void:
	var gold := _sec()
	for sp in _sparks:   # gold sparks rising off it
		var a: float = clampf(sp[2] / 0.3, 0.0, 1.0)
		draw_rect(Rect2(sp[0] - Vector2(1.5, 1.5), Vector2(3, 3)), Color(gold.lightened(0.3), a))


func _draw_bolt() -> void:
	var col := Palette.tint(CHARGE_COLOR)
	var o := _bolt_origin()
	var s := (1.0 + (0.3 if _boosted else 0.15) * _charge_pop) * _boost_scale()
	if _boosted:
		_draw_boost(o, s)
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
		# The empty part: dark while golden, so the fill stands out against the glow.
		draw_colored_polygon(poly, Color(0.05, 0.03, 0.0, 0.6) if _boosted else Color(1, 1, 1, 0.08))
		if _charge > 0.0:
			var top := lerpf(poly_bottom(poly), poly_top(poly), _charge)
			var part := _below(poly, top)
			if part.size() >= 3:
				draw_colored_polygon(part, Color(col, 0.9))
	var closed := poly.duplicate()
	closed.append(poly[0])
	if _boosted and not _charged:
		draw_polyline(closed, Color(_sec(), 0.95), 2.5, true)   # a gold rim
	else:
		draw_polyline(closed, Color(1, 1, 1, 0.9) if _charged else Color(col.lightened(0.3), 0.75), 1.5, true)
	if _boosted:
		_draw_boost_front(o)
	_draw_pips(o)
	if _discharge > 0.0:   # used: a white flash bursting out as it empties
		draw_colored_polygon(_bolt_poly(o, 1.0 + 0.8 * (1.0 - _discharge)), Color(1, 1, 1, 0.55 * _discharge))
		draw_arc(o + BOLT_SIZE / 2.0, 14.0 + 34.0 * (1.0 - _discharge), 0.0, TAU, 36, Color(Palette.tint(CHARGE_COLOR).lightened(0.4), _discharge), 2.5, true)


## Under the bolt: a pip per PERFECT it takes to fill (a CLEAN fills half of
## one), and while golden or rainbow, how much faster it fills (x1.5, x2).
static var pip_style := "ring"   # (MOCKUP) "squares", "segments" (the bolt split in 5) or "ring"

func _draw_pips(o: Vector2) -> void:
	if pip_style == "segments":
		_draw_segments(o)
	elif pip_style == "ring":
		_draw_ring(o)
	else:
		_draw_squares(o)
	_draw_badge(o)


func _draw_badge(o: Vector2) -> void:
	if _charge_mult > 1.0:   # (ready or not: it stays while golden / rainbow)
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var txt := "x1.5" if _charge_mult < 1.9 else "x2"
		var p := Vector2(o.x + BOLT_SIZE.x + 6.0, o.y + 16.0)
		if pip_style == "ring":   # (beside the ring, out with it as it jumps)
			p = o + BOLT_SIZE / 2.0 + Vector2(ring_radius() * _boost_scale() + 4.0, -ring_radius() * 0.45 * _boost_scale())
		var pop := 1.0
		if _badge_pop >= 0.0 and _badge_pop < 0.3:
			pop = 1.0 + 0.6 * (1.0 - _badge_pop / 0.3)
		# (one font size, scaled as a picture: a new size each frame would make the font build new letters, a hitch)
		draw_set_transform(p, 0.0, Vector2(pop, pop))
		draw_string(FONT, Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.7))
		draw_string(FONT, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, _sec().lightened(0.2 * beat))
		draw_set_transform(Vector2.ZERO)


## The bolt's colour for its pips now.
func _pip_col() -> Color:
	var col := Palette.tint(CHARGE_COLOR)
	if _charged:
		return col.lightened(0.15 + 0.2 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)))
	return _sec() if _charge_mult > 1.0 else col


## Notches across the bolt at each fifth (the fill already rises in steps of them).
func _draw_segments(o: Vector2) -> void:
	var s := 1.0 + (0.3 if _boosted else 0.15) * _charge_pop
	var poly := _bolt_poly(o, s)
	var top := poly_top(poly)
	var bot := poly_bottom(poly)
	var n := int(ceil(float(_charge_full) / PIP_UNITS))
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	var filled := float(_charge_units) / PIP_UNITS
	for k in range(1, n):
		var y := lerpf(bot, top, float(k) / n)
		var xs: Array[float] = []
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			if (a.y - y) * (b.y - y) < 0.0:
				xs.append(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
		xs.sort()
		for j in range(0, xs.size() - 1, 2):
			draw_line(Vector2(xs[j], y), Vector2(xs[j + 1], y), Color(0.05, 0.03, 0.04, 0.95), 2.5)
	if not _charged and filled >= n - 1 and filled < n:   # one to go: the top part's edge pulses
		var part := _below(poly, lerpf(bot, top, float(n - 1) / n))
		var upper := PackedVector2Array()
		for p in poly:
			if p.y <= lerpf(bot, top, float(n - 1) / n) + 0.5:
				upper.append(p)
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color(1, 1, 1, 0.35 + 0.6 * beat), 2.0, true)


## The ring's radius (round the bolt's middle).
func ring_radius() -> float:
	return BOLT_SIZE.y / 2.0 + 12.0   # (clear of the bolt's points, even as it swells)


## The square round the ring (the tutorial's highlight of the Red Flash).
func ring_rect() -> Rect2:
	var c := _bolt_origin() + BOLT_SIZE / 2.0
	var half := ring_radius() + 4.0
	return Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)


## How much bigger the bolt and its ring are right now (the golden / rainbow jump).
func _boost_scale() -> float:
	return lerpf(1.0, BOLT_FLY_SCALE, bolt_fly)


## Sparks off an arc that just gained (more, and white-hot, when it's whole).
func _ring_burst(i: int, n: int, whole: bool) -> void:
	var c := _bolt_origin() + BOLT_SIZE / 2.0
	var r := ring_radius()
	var mid := -PI / 2.0 + (i + 0.5) * TAU / n
	for k in (10 if whole else 5):
		var a := mid + _rng.randf_range(-0.45, 0.45)
		var p := c + Vector2.RIGHT.rotated(a) * r
		var v := Vector2.RIGHT.rotated(a + _rng.randf_range(-0.5, 0.5)) * _rng.randf_range(60.0, 150.0)
		var life := _rng.randf_range(0.25, 0.45)
		_ring_sparks.append([p, v, life, life, Color(1, 0.95, 0.85) if whole and k % 2 == 0 else Color(1, 1, 1)])


## A ring round the bolt in five arcs, filling clockwise from the top: an arc
## that gains flashes white and swells; full, lightning jumps its gaps.
func _draw_ring(o: Vector2) -> void:
	var c := o + BOLT_SIZE / 2.0
	var n := int(ceil(float(_charge_full) / PIP_UNITS))
	var filled := float(_charge_units) / PIP_UNITS
	var r := ring_radius() * _boost_scale()
	if _turn_ring > 0.0:   # a ring bursting out with it, in her new colour
		var k := 1.0 - _turn_ring
		draw_arc(c, r + 30.0 * ease(k, 0.5), 0.0, TAU, 48, Color(_sec(), _turn_ring), 3.0, true)
	var gap := deg_to_rad(9.0)
	var seg := TAU / n
	var col := _pip_col()
	for i in n:
		var a0 := -PI / 2.0 + i * seg + gap / 2.0
		var a1 := a0 + seg - gap
		var part := clampf(filled - i, 0.0, 1.0)
		var t: float = _ring_flash.get(i, -1.0)
		var flash := 1.0 - t / RING_FLASH if t >= 0.0 else 0.0
		var w := 4.0 + 3.0 * flash
		draw_arc(c, r, a0, a1, 16, Color(1, 1, 1, 0.14), 4.0, true)
		if part > 0.0:
			var a_end := lerpf(a0, a1, part)
			draw_arc(c, r, a0, a_end, 16, Color(col, 0.22 + 0.25 * flash), w + 6.0, true)   # glow
			draw_arc(c, r, a0, a_end, 16, col.lerp(Color.WHITE, 0.75 * flash), w, true)
	if _charged:
		for i in n:
			if _rng.randf() < 0.35:
				var ga := -PI / 2.0 + i * seg
				var p0 := c + Vector2.RIGHT.rotated(ga - gap) * r
				var p1 := c + Vector2.RIGHT.rotated(ga + gap) * r
				var mid := (p0 + p1) / 2.0 + (p1 - p0).orthogonal().normalized() * _rng.randf_range(-5.0, 5.0)
				draw_polyline(PackedVector2Array([p0, mid, p1]), Color(1, 1, 1, 0.9), 1.5, true)
	for sp in _ring_sparks:
		var k: float = sp[2] / sp[3]
		draw_line(sp[0], sp[0] - sp[1] * 0.04, Color(sp[4], k), 2.0, true)


func _draw_squares(o: Vector2) -> void:
	var col := Palette.tint(CHARGE_COLOR)
	var n := int(ceil(float(_charge_full) / PIP_UNITS))
	var row_w := n * PIP + (n - 1) * PIP_GAP
	var x0 := o.x + BOLT_SIZE.x / 2.0 - row_w / 2.0
	var y := o.y + BOLT_SIZE.y + 9.0
	var filled := float(_charge_units) / PIP_UNITS
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for i in n:
		var r := Rect2(x0 + i * (PIP + PIP_GAP), y, PIP, PIP)
		var part := clampf(filled - i, 0.0, 1.0)
		var c := col
		if _charged:
			c = col.lightened(0.15 + 0.2 * beat)
		elif _charge_mult > 1.0:
			c = _sec()
		draw_rect(r, Color(1, 1, 1, 0.1))
		if part > 0.0:
			draw_rect(Rect2(r.position, Vector2(PIP * part, PIP)), c)
		var last_one := not _charged and i == n - 1 and filled >= n - 1 and filled < n
		draw_rect(r, Color(1, 1, 1, 0.5 + 0.5 * beat) if last_one else Color(1, 1, 1, 0.35), false, 1.0)


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
		return _sec()
	# In her reward colour while she has it.
	return Palette.swatch().lightened(0.25) if Palette.pink > 0.5 else Color.WHITE


## Where the number's centre goes under "FLAWLESS" (x: the caption's left):
## streak_align 0 = left-aligned with it, 1 = right-aligned, 2 = centred.
static var streak_align := 2   # (centred)
func _streak_number_x(x: float, w: float) -> float:
	var cw := FONT.get_string_size("FLAWLESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	match streak_align:
		1: return x + cw - w / 2.0
		2: return x + cw / 2.0
	return x + w / 2.0


## 0..1: the flawless number (and its caption) grows to FLY_SCALE where it
## is, kept on screen (main.gd moves it).
var fly := 0.0
const FLY_SCALE := 2.2

func _draw_streak() -> void:
	var x := streak_x
	var mid := BLADE.y / 2.0
	var cap_col := _streak_colour(_streak)
	var fs := 30
	var text := str(_streak)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var centre := Vector2(_streak_number_x(x, w), mid + 7.0)
	var f := fly   # (main.gd's tween eases it)
	var grow := lerpf(1.0, FLY_SCALE, f)
	var cw := FONT.get_string_size("FLAWLESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var cap_at := Vector2(_streak_number_x(x, cw), mid - 15.0)   # the caption's centre-baseline
	if f > 0.0:
		# It grows where it is, nudged in just enough to stay on screen
		# (it's up in the corner).
		var home := centre
		var cap_rel := cap_at - home
		var half_w := maxf(cw, w) / 2.0 * grow
		var top_y := (cap_rel.y - 12.0 * 0.8) * grow   # (the caption's top, from the centre)
		var screen_top := -global_position.y + 4.0
		var screen_right := get_viewport_rect().size.x - global_position.x - 4.0
		var to := home
		to.y = maxf(to.y, screen_top - top_y)
		to.x = minf(to.x, screen_right - half_w)
		centre = home.lerp(to, f)
		cap_at = centre + cap_rel * grow
	# While it's out (and coming back), the words are drawn at their full
	# grown size and scaled down, so they stay sharp: drawn small and
	# scaled up, they blurred. The caption brightens on its way out too.
	var r := FLY_SCALE if f > 0.0 else 1.0   # (drawn this many times bigger)
	draw_set_transform(cap_at, 0.0, Vector2.ONE * grow / r)
	draw_string(FONT, Vector2(-cw * r / 2.0, 0.0), "FLAWLESS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * r), Color(cap_col, lerpf(0.65, 1.0, f)))
	draw_set_transform(Vector2.ZERO)
	# The pop: bigger right after a kill (more at a milestone), easing back.
	var pop := ease(_pop, 2.0) * (0.6 if _pop_big else 0.3)
	if _break_t < 0.0 or _break_t > 0.25:
		draw_set_transform(centre, 0.0, Vector2.ONE * (1.0 + pop) * grow / r)
		var a := 1.0 if _break_t < 0.0 else clampf((_break_t - 0.25) / 0.2, 0.0, 1.0)
		draw_string(FONT, Vector2(-w * r / 2.0, fs * r * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * r), Color(_streak_colour(_streak), a))
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
			var piece_at := Vector2(_streak_number_x(x, ow) + shake + side * 8.0 * t, mid + 7.0 + drop * (1.0 if side < 0.0 else 1.2))
			draw_set_transform(piece_at, side * 0.6 * t, Vector2.ONE)
			draw_string(FONT, Vector2(-ow / 2.0, fs * 0.35), old, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(red, red.a * 0.6))
		draw_set_transform(Vector2.ZERO)


# --- all of it ---------------------------------------------------------------

## How far the level and the katana reach left and right of its origin
## (hud.gd centres them, and places the bolt and the streak out toward the
## screen's edges: bolt_x, streak_x).
func extent() -> Vector2:
	var lv_w := FONT.get_string_size(_level_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE).x
	return Vector2(_hilt_left() - GAP_LEVEL - lv_w, BLADE.x)


func _level_text() -> String:
	return "LV %d" % level


func _draw() -> void:
	_draw_bolt()
	# A level-up swells the level and the whole katana for a moment.
	var swell := 0.0
	if _level_up >= 0.0:
		swell = sin(clampf(_level_up / LEVEL_UP_SWELL, 0.0, 1.0) * PI)
	var lv := _level_text()
	var lv_w := FONT.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE).x
	var lv_at := Vector2(_hilt_left() - GAP_LEVEL - lv_w / 2.0, BLADE.y / 2.0)
	draw_set_transform(lv_at, 0.0, Vector2.ONE * (1.0 + 0.28 * swell))
	var lv_col := Color(1, 1, 1, 0.85).lerp(_sec(), clampf(1.0 - _level_up / LEVEL_UP_TIME, 0.0, 1.0) if _level_up >= 0.0 else 0.0)
	draw_string(FONT, Vector2(-lv_w / 2.0, LEVEL_SIZE * 0.36), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, LEVEL_SIZE, lv_col)
	var c := Vector2((_hilt_left() + BLADE.x) / 2.0, BLADE.y / 2.0)
	var sc := 1.0 + 0.08 * swell + 0.025 * _hit
	draw_set_transform(c * (1.0 - sc), 0.0, Vector2.ONE * sc)
	_draw_hilt()
	_draw_blade()
	_draw_whole_glow()
	_draw_blade_arcs()
	draw_set_transform(Vector2.ZERO)
	for b in _bits:
		var a: float = b[2] / b[3]
		draw_rect(Rect2(b[0] - Vector2(1.5, 1.5), Vector2(3, 3)), Color(b[4], a))
	_draw_streak()

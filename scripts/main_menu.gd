class_name MainMenu
extends Control
## The title screen, on its own dark background (the level isn't shown):
## "RED FLASH" across the top, her (the browser-tab pose: the first run frame,
## katana out behind her) large on the left with lightning crackling over her,
## and the buttons on the right (Play, the level chooser while main.gd
## LEVEL_CHOICE is on, Options). Drawn in code like the HUD; main.gd passes
## it every press while it's open (touch doesn't emulate mouse in this
## project, so it hit-tests taps itself) and acts on what handle() returns.
##
## Keys: Up/Down pick a button (it starts on Play); Left/Right, Enter/Space
## or any teleport key (K, J, D, A, the Shifts) press it; O opens Options.

const TITLE := "RED FLASH"
## The title's font ("Russo One", SIL Open Font License: assets/fonts).
var title_font: Font = preload("res://assets/fonts/RussoOne-Regular.ttf")
const TITLE_SIZE := 100
const TITLE_RED := Color(1.0, 0.22, 0.29)
## "RED FLASH" itself: her hair's red as it shows on screen (the buttons and
## the other screens keep TITLE_RED).
const TITLE_TEXT_RED := Color8(234, 8, 4)
const BG_TOP := Color(0.07, 0.04, 0.06)
const BG_BOTTOM := Color(0.02, 0.01, 0.02)
const BUTTON_SIZE := Vector2(300, 58)
const BUTTON_GAP := 14.0
const LABEL_SIZE := 26
const HINT_TOUCH := "Tap Left: Up/Down    Tap Right: Forward    Both: Diagonal"
const HINT_KEYS := "Left: Up/Down    Right: Forward    Both: Diagonal"

## Her: running (the run sheet, as in the game), at a whole-number scale
## (crisp pixels).
const RUN_FRAMES := 6
const RUN_CYCLE := 0.61676 / 1.25   # seconds a run cycle (a quarter faster than a beat of the music)
const FRAME_PX := 96
## The part of a frame she fills in any of them (frame pixels), and her
## katana's blade (its height in each frame: she bobs as she runs).
const HER_BODY := Rect2(5, 22, 66, 63)
const BLADE_X := Vector2(5, 24)
const BLADE_Y := [37, 39, 40, 37, 39, 40]
## Her body without the katana (where bolts run across her).
const HER_TORSO := Rect2(30, 26, 40, 50)

## Bolts crackling over her: one every this many seconds (random in range).
const HER_CRACKLE_EVERY := Vector2(0.02, 0.07)
## Small bolts off the title.
const TITLE_CRACKLE_EVERY := Vector2(0.12, 0.4)
const CRACKLE_LIFE := 0.13
## Now and then a big strike from above onto her (her glow flares; the title stays steady).
const STRIKE_EVERY := Vector2(2.0, 4.0)
const STRIKE_LIFE := 0.24

var start_level := 1
var level_choice := false
var _selected := 0
var _keyboard := false
## Picking a start level rebuilds the scene; this keeps the level button
## picked (and its highlight) across that, so pressing it again steps the
## level again instead of pressing Play.
static var _reopen := {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _bolts: Array = []   # [points, forks, life, max_life, width]
var _next_her := 0.0
var _next_title := 0.0
var _next_strike := 1.2
var _flash := 0.0
var _glow: GradientTexture2D   # the red glow behind her (smooth, radial)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = Palette.sprite_material()   # (her katana's hilt in her second colour, as in the game)
	visible = false
	_rng.randomize()
	var g := Gradient.new()
	g.set_color(0, Color(TITLE_RED, 0.32))
	g.set_color(1, Color(TITLE_RED, 0.0))
	g.add_point(0.45, Color(TITLE_RED, 0.12))
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 256
	_glow.height = 256


func open(level: int, choice: bool) -> void:
	start_level = level
	level_choice = choice
	_selected = 0
	if not _reopen.is_empty():
		_selected = maxi(_buttons().find(_reopen["id"]), 0)
		_keyboard = _reopen["keyboard"]
		_reopen = {}
	visible = true


## Keep the level button picked through the rebuild a new start level does.
func keep_level_picked() -> void:
	_reopen = {"id": "level", "keyboard": _keyboard}


func close() -> void:
	visible = false


func _buttons() -> Array[String]:
	var b: Array[String] = ["play"]
	if level_choice:
		b.append("level")
	b.append("options")
	if Hud.rotated:   # (a phone held upright: under Options, above Credits)
		b.append("flip")
	b.append("credits")
	return b


func _button_text(id: String) -> String:
	match id:
		"play": return "PLAY"
		"level": return "Tutorial" if start_level == 0 else "Start At Level %d" % start_level
		"flip": return "Flip Screen"
		"options": return "Options"
		"credits": return "Credits"
	return ""


# --- input (from main.gd) ---------------------------------------------------

## A fresh press while the menu is open; `pos` = its game-screen position
## (taps and clicks only). Returns "play", "level", "level_back" (a left key
## on the level button: the level before), "flip", "options", "credits" or "".
func handle(event: InputEvent, pos: Vector2) -> String:
	var ids := _buttons()
	if event is InputEventKey:
		# (physical code, or the key's code where the browser gives none)
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match code:
			KEY_UP:
				_keyboard = true
				_selected = posmod(_selected - 1, ids.size())
			KEY_DOWN:
				_keyboard = true
				_selected = posmod(_selected + 1, ids.size())
			# Left/Right (and the other teleport keys, Enter, Space) press the
			# picked button; it starts on Play.
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_K, KEY_J, KEY_D, KEY_A, KEY_SHIFT:
				var left: bool = code in [KEY_LEFT, KEY_J, KEY_A] or (code == KEY_SHIFT and event.location == KEY_LOCATION_LEFT)
				if ids[_selected] == "level" and left:
					return "level_back"
				return ids[_selected]
			KEY_O:
				return "options"
		return ""
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		for i in ids.size():
			var r := _button_rect(i)
			if r.has_point(pos):   # (on the button itself)
				_selected = i
				# The start level selector: its left third steps back.
				if ids[i] == "level" and pos.x < r.position.x + r.size.x / 3.0:
					return "level_back"
				return ids[i]
	return ""


# --- layout ----------------------------------------------------------------

func _title_baseline() -> float:
	return maxf(size.y * 0.2, 96.0)


func _title_rect() -> Rect2:
	var w := title_font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var h := TITLE_SIZE * 0.78
	return Rect2(Vector2((size.x - w) / 2.0, _title_baseline() - h), Vector2(w, h))


## Her scale: whole pixels, as big as fits the left part under the title.
func _her_scale() -> float:
	var room := Vector2(size.x * 0.5, size.y - _title_baseline() - 60.0)
	return maxf(floorf(minf(room.x / HER_BODY.size.x, room.y / HER_BODY.size.y)), 2.0)


## Where her frame's top-left corner goes (her body centred in the left part).
func _her_origin() -> Vector2:
	var s := _her_scale()
	var centre := Vector2(size.x * 0.29, (_title_baseline() + 30.0 + size.y - 40.0) / 2.0)
	return centre - (HER_BODY.position + HER_BODY.size / 2.0) * s


func _her_point(frame_px: Vector2) -> Vector2:
	return _her_origin() + frame_px * _her_scale()


func _button_rect(i: int) -> Rect2:
	var n := _buttons().size()
	var total := n * BUTTON_SIZE.y + (n - 1) * BUTTON_GAP
	var top := _her_point(HER_BODY.position + HER_BODY.size / 2.0).y - total / 2.0
	return Rect2(Vector2(size.x * 0.72 - BUTTON_SIZE.x / 2.0, top + i * (BUTTON_SIZE.y + BUTTON_GAP)), BUTTON_SIZE)


# --- the lightning -----------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	for b in _bolts:
		b[2] -= delta
	_bolts = _bolts.filter(func(b: Array) -> bool: return b[2] > 0.0)
	_next_her -= delta
	if _next_her <= 0.0:
		_next_her = _rng.randf_range(HER_CRACKLE_EVERY.x, HER_CRACKLE_EVERY.y)
		_crackle_her()
	_next_title -= delta
	if _next_title <= 0.0:
		_next_title = _rng.randf_range(TITLE_CRACKLE_EVERY.x, TITLE_CRACKLE_EVERY.y)
		_crackle_title()
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike = _rng.randf_range(STRIKE_EVERY.x, STRIKE_EVERY.y)
		_strike()
	queue_redraw()


## A bolt over her: arcing along her katana, running across her, or jumping
## off her.
func _crackle_her() -> void:
	var s := _her_scale()
	var roll := _rng.randf()
	if roll < 0.45:   # across her body
		var a := Vector2(_rng.randf_range(HER_TORSO.position.x, HER_TORSO.end.x), _rng.randf_range(HER_TORSO.position.y, HER_TORSO.end.y))
		var b := a + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(8.0, 20.0)
		b = b.clamp(HER_TORSO.position, HER_TORSO.end)
		_add_bolt(_her_point(a), _her_point(b), 6, s * 1.6, CRACKLE_LIFE, 1.3, 1)
		return
	if roll < 0.7:
		var y: float = BLADE_Y[_run_frame()]
		var a := _her_point(Vector2(lerpf(BLADE_X.x, BLADE_X.y, _rng.randf_range(0.0, 0.4)), y))
		var b := _her_point(Vector2(lerpf(BLADE_X.x, BLADE_X.y, _rng.randf_range(0.55, 1.0)), y))
		_add_bolt(a, b, 6, s * 2.2, CRACKLE_LIFE, 1.5, 1)
		return
	var p := _her_point(Vector2(_rng.randf_range(HER_TORSO.position.x, HER_TORSO.end.x),
			_rng.randf_range(HER_TORSO.position.y, HER_TORSO.end.y)))
	var centre := _her_point(HER_BODY.position + HER_BODY.size / 2.0)
	var out := (p - centre).normalized().rotated(_rng.randf_range(-0.8, 0.8))
	_add_bolt(p, p + out * _rng.randf_range(s * 6.0, s * 14.0), 6, s * 1.6, CRACKLE_LIFE, 1.6, 1)


## A short bolt off the title's edge, outward.
func _crackle_title() -> void:
	var r := _title_rect().grow(4.0)
	var up := _rng.randf() < 0.5
	var p := Vector2(_rng.randf_range(r.position.x, r.end.x), r.position.y if up else r.end.y)
	var to := p + (Vector2.UP if up else Vector2.DOWN).rotated(_rng.randf_range(-0.9, 0.9)) * _rng.randf_range(30.0, 80.0)
	_add_bolt(p, to, 6, 9.0, CRACKLE_LIFE, 1.3, 1)


## A big bolt from the top of the screen down onto her.
func _strike() -> void:
	var hit := _her_point(Vector2(_rng.randf_range(42.0, 60.0), 24.0))
	var from := Vector2(hit.x + _rng.randf_range(-120.0, 120.0), -10.0)
	_add_bolt(from, hit, 16, 24.0, STRIKE_LIFE, 3.0, 3)
	_flash = 1.0


func _add_bolt(a: Vector2, b: Vector2, n: int, jag: float, life: float, width: float, forks: int) -> void:
	var pts := _jagged(a, b, n, jag)
	var fork_lines: Array[PackedVector2Array] = []
	for k in forks:
		var i := _rng.randi_range(1, pts.size() - 2)
		var dir := (b - a).normalized().rotated(_rng.randf_range(-1.2, 1.2))
		fork_lines.append(_jagged(pts[i], pts[i] + dir * _rng.randf_range(15.0, 55.0), 4, jag * 0.5))
	_bolts.append([pts, fork_lines, life, life, width])


func _jagged(a: Vector2, b: Vector2, n: int, jag: float) -> PackedVector2Array:
	var normal := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var off := 0.0 if i == 0 or i == n else _rng.randf_range(-jag, jag)
		pts.append(a.lerp(b, t) + normal * off)
	return pts


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	# Its own background: dark, a little warmer at the top.
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	_draw_her()
	_draw_title()
	for b in _bolts:
		var k: float = b[2] / b[3]
		var w: float = b[4]
		for line in [b[0]] + b[1]:
			var main_line: bool = line == b[0]
			var lw := w * (1.0 if main_line else 0.55)
			draw_polyline(line, Color(TITLE_RED, 0.2 * k), lw * 6.0, true)
			draw_polyline(line, Color(1.0, 0.3, 0.35, 0.95 * k), lw * 1.6, true)
			draw_polyline(line, Color(1, 0.94, 0.94, k), maxf(lw * 0.6, 1.0), true)
	for i in _buttons().size():
		_draw_button(i)
	var f := ThemeDB.fallback_font
	var hw := f.get_string_size((HINT_TOUCH if Hud.is_touch() else HINT_KEYS), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2((size.x - hw) / 2.0, size.y - 20.0), (HINT_TOUCH if Hud.is_touch() else HINT_KEYS), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.5))


func _draw_her() -> void:
	var s := _her_scale()
	var centre := _her_point(HER_BODY.position + HER_BODY.size / 2.0)
	# A red glow behind her, breathing, brighter on a strike.
	var glow := 0.75 + 0.15 * sin(_t * 2.6) + 0.6 * _flash
	var r := HER_BODY.size.x * s * 0.75
	draw_texture_rect(_glow, Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, minf(glow, 1.0)))
	var rect := Rect2(_her_origin(), Vector2(FRAME_PX, FRAME_PX) * s)
	draw_texture_rect_region(Player.RUN_SHEET, rect, Rect2(_run_frame() * FRAME_PX, 0, FRAME_PX, FRAME_PX))


## Her run: a full cycle every RUN_CYCLE seconds (five to every four beats). Put in
## step with the music once, when it starts: her last frame (head lowest) on
## a beat, and on every fourth beat after; then her own clock runs on.
var _run_offset := 0.0   # cycles to add to her clock
var _run_synced := false

func _run_frame() -> int:
	if not _run_synced:
		var music := get_tree().root.get_node_or_null("Music") as AudioStreamPlayer
		if music and music.playing:
			var pos := music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
			_run_offset = pos / RUN_CYCLE - _t / RUN_CYCLE
			_run_synced = true
	return (int(floorf((_t / RUN_CYCLE + _run_offset) * RUN_FRAMES)) + RUN_FRAMES - 1) % RUN_FRAMES


func _draw_title() -> void:
	var r := _title_rect()
	var base := Vector2(r.position.x, _title_baseline())
	for i in 12:   # a soft glow
		var o := Vector2.RIGHT.rotated(i * TAU / 12.0) * 6.0
		draw_string(title_font, base + o, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(TITLE_TEXT_RED, 0.06))
	# Steady (it doesn't flicker or flash), in her hair's red with no highlight.
	draw_string(title_font, base, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, TITLE_TEXT_RED)


func _draw_button(i: int) -> void:
	var id := _buttons()[i]
	var r := _button_rect(i)
	var picked := _keyboard and i == _selected
	if id == "level":
		_draw_level_selector(r, picked)
		return
	var play := id == "play"
	var fill := Color(TITLE_RED, 0.3) if play else Color(1, 1, 1, 0.07)
	if picked:
		fill = Color(fill, fill.a + 0.12)
	draw_rect(r, fill)
	var border := Color(1, 0.45, 0.5, 0.95) if play else Color(1, 1, 1, 0.55)
	draw_rect(r, Color.WHITE if picked else border, false, 2.0)
	var f := ThemeDB.fallback_font
	var text := _button_text(id)
	var s := 30 if play else LABEL_SIZE
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(f, Vector2(r.position.x + (r.size.x - w) / 2.0, r.position.y + r.size.y / 2.0 + s * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color.WHITE)


## The start level: a setting you step through, not a button. "<  Start
## Level 5  >" on a faint strip (underlined), its arrows stepping it.
func _draw_level_selector(r: Rect2, picked: bool) -> void:
	draw_rect(r, Color(1, 1, 1, 0.1 if picked else 0.035))
	if picked:
		draw_rect(r, Color.WHITE, false, 2.0)
	else:
		draw_line(Vector2(r.position.x + 12.0, r.end.y - 1.0), Vector2(r.end.x - 12.0, r.end.y - 1.0), Color(1, 1, 1, 0.3), 1.0)
	var f := ThemeDB.fallback_font
	var y := r.position.y + r.size.y / 2.0 + LABEL_SIZE * 0.35
	var arrow := Color(1, 1, 1, 0.75)
	draw_string(f, Vector2(r.position.x + 16.0, y), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, arrow)
	var gw := f.get_string_size(">", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(f, Vector2(r.end.x - 16.0 - gw, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, arrow)
	var label := "Start Level " if start_level > 0 else ""
	var value := str(start_level) if start_level > 0 else "Tutorial"   # (0: the tutorial)
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE - 4).x
	var vw := f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE + 4).x
	var x := r.position.x + (r.size.x - lw - vw) / 2.0
	draw_string(f, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE - 4, Color(1, 1, 1, 0.7))
	draw_string(f, Vector2(x + lw, y + 1.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE + 4, Color.WHITE)

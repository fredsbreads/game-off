class_name MainMenu
extends Control
## The title screen: "RED FLASH" in red with lightning crackling round it,
## and its buttons (Play, the level chooser while main.gd LEVEL_CHOICE is on,
## Options). Drawn in code like the HUD; main.gd passes it every press while
## it's open (touch doesn't emulate mouse in this project, so it hit-tests
## taps itself) and acts on what handle() returns.
##
## Keys: Up/Down pick a button, Enter/Space press it; any teleport key
## (Right, Left, K, J, D, A, the Shifts) plays; O opens Options.

const TITLE := "RED FLASH"
const TITLE_SIZE := 132
const TITLE_RED := Color(0.95, 0.1, 0.16)
const TITLE_DARK := Color(0.32, 0.0, 0.03)
const BUTTON_SIZE := Vector2(320, 58)
const BUTTON_GAP := 12.0
const LABEL_SIZE := 26
const HINT := "left tap: shift      right tap: forward      both: shift + forward"

## Small bolts crackling off the title: one every this many seconds (random in range).
const CRACKLE_EVERY := Vector2(0.03, 0.12)
const CRACKLE_LIFE := 0.14
## Now and then a big strike from above onto the title, which flashes white.
const STRIKE_EVERY := Vector2(1.6, 3.4)
const STRIKE_LIFE := 0.22

var start_level := 1
var level_choice := false
var _selected := 0
var _keyboard := false
var _font: FontVariation
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _bolts: Array = []   # [points, forks, life, max_life, width]
var _next_crackle := 0.0
var _next_strike := 1.0
var _flash := 0.0        # the title's white flash after a big strike


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 1.1
	_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)   # slanted forward
	_rng.randomize()


func open(level: int, choice: bool) -> void:
	start_level = level
	level_choice = choice
	_selected = 0
	visible = true


func close() -> void:
	visible = false


func _buttons() -> Array[String]:
	var b: Array[String] = ["play"]
	if level_choice:
		b.append("level")
	b.append("options")
	return b


func _button_text(id: String) -> String:
	match id:
		"play": return "PLAY"
		"level": return "Start at level %d (L)" % start_level
		"options": return "Options (O)"
	return ""


# --- input (from main.gd) ---------------------------------------------------

## A fresh press while the menu is open; `pos` = its game-screen position
## (taps and clicks only). Returns "play", "level", "options" or "".
func handle(event: InputEvent, pos: Vector2) -> String:
	var ids := _buttons()
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_UP:
				_keyboard = true
				_selected = posmod(_selected - 1, ids.size())
			KEY_DOWN:
				_keyboard = true
				_selected = posmod(_selected + 1, ids.size())
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				return ids[_selected]
			KEY_O:
				return "options"
			KEY_RIGHT, KEY_LEFT, KEY_K, KEY_J, KEY_D, KEY_A, KEY_SHIFT:
				return "play"
		return ""
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		for i in ids.size():
			if _button_rect(i).grow(8.0).has_point(pos):
				_selected = i
				return ids[i]
	return ""


# --- layout ----------------------------------------------------------------

func _title_baseline() -> float:
	return size.y * 0.36


func _title_rect() -> Rect2:
	var w := _font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var h := TITLE_SIZE * 0.72
	return Rect2(Vector2((size.x - w) / 2.0, _title_baseline() - h), Vector2(w, h))


func _button_rect(i: int) -> Rect2:
	var top := _title_baseline() + 62.0
	return Rect2(Vector2((size.x - BUTTON_SIZE.x) / 2.0, top + i * (BUTTON_SIZE.y + BUTTON_GAP)), BUTTON_SIZE)


# --- the lightning -----------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = maxf(_flash - delta * 3.5, 0.0)
	for b in _bolts:
		b[2] -= delta
	_bolts = _bolts.filter(func(b: Array) -> bool: return b[2] > 0.0)
	_next_crackle -= delta
	if _next_crackle <= 0.0:
		_next_crackle = _rng.randf_range(CRACKLE_EVERY.x, CRACKLE_EVERY.y)
		_crackle()
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike = _rng.randf_range(STRIKE_EVERY.x, STRIKE_EVERY.y)
		_strike()
	queue_redraw()


## A short bolt jumping off the edge of the title, outward.
func _crackle() -> void:
	var r := _title_rect().grow(6.0)
	var side := _rng.randi_range(0, 3)
	var p: Vector2
	var out: Vector2
	match side:
		0: p = Vector2(_rng.randf_range(r.position.x, r.end.x), r.position.y); out = Vector2.UP
		1: p = Vector2(_rng.randf_range(r.position.x, r.end.x), r.end.y); out = Vector2.DOWN
		2: p = Vector2(r.position.x, _rng.randf_range(r.position.y, r.end.y)); out = Vector2.LEFT
		_: p = Vector2(r.end.x, _rng.randf_range(r.position.y, r.end.y)); out = Vector2.RIGHT
	var to := p + out.rotated(_rng.randf_range(-0.9, 0.9)) * _rng.randf_range(50.0, 150.0)
	_add_bolt(p, to, 7, 11.0, CRACKLE_LIFE, 1.6, 1)


## A big bolt from the top of the screen down onto the title; it flashes.
func _strike() -> void:
	var r := _title_rect()
	var hit := Vector2(_rng.randf_range(r.position.x + 40.0, r.end.x - 40.0), r.position.y + 8.0)
	var from := Vector2(hit.x + _rng.randf_range(-160.0, 160.0), -10.0)
	_add_bolt(from, hit, 14, 26.0, STRIKE_LIFE, 3.0, 3)
	_flash = 1.0


func _add_bolt(a: Vector2, b: Vector2, n: int, jag: float, life: float, width: float, forks: int) -> void:
	var pts := _jagged(a, b, n, jag)
	var fork_lines: Array[PackedVector2Array] = []
	for k in forks:
		var i := _rng.randi_range(1, pts.size() - 2)
		var dir := (b - a).normalized().rotated(_rng.randf_range(-1.2, 1.2))
		fork_lines.append(_jagged(pts[i], pts[i] + dir * _rng.randf_range(20.0, 70.0), 4, jag * 0.5))
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
	# The level, dimmed behind it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.01, 0.62))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.85, 0.85, 0.07 * _flash))
	_draw_title()
	for b in _bolts:
		var k: float = b[2] / b[3]
		var w: float = b[4]
		for line in [b[0]] + b[1]:
			var main_line: bool = line == b[0]
			var lw := w * (1.0 if main_line else 0.55)
			draw_polyline(line, Color(TITLE_RED.r, TITLE_RED.g, TITLE_RED.b, 0.18 * k), lw * 6.0, true)
			draw_polyline(line, Color(1.0, 0.25, 0.3, 0.95 * k), lw * 1.6, true)
			draw_polyline(line, Color(1, 0.92, 0.92, k), maxf(lw * 0.6, 1.0), true)
	# A katana line under the title, with a glint running along it.
	var tr := _title_rect()
	var y := tr.end.y + 22.0
	var x0 := tr.position.x + 20.0
	var x1 := tr.end.x - 40.0
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(TITLE_RED, 0.55), 2.0, true)
	var g := fmod(_t * 0.45, 1.6)
	if g < 1.0:
		var gx := lerpf(x0, x1, g)
		draw_line(Vector2(gx - 40.0, y), Vector2(gx + 40.0, y), Color(1, 0.9, 0.9, 0.7 * sin(g * PI)), 2.0, true)
	for i in _buttons().size():
		_draw_button(i)
	var f := ThemeDB.fallback_font
	var hw := f.get_string_size(HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2((size.x - hw) / 2.0, size.y - 26.0), HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))


func _draw_title() -> void:
	var r := _title_rect()
	var base := Vector2(r.position.x, _title_baseline())
	var flicker := 0.85 + 0.15 * sin(_t * 23.0) * sin(_t * 7.0)
	# A soft red glow round it.
	for i in 12:
		var o := Vector2.RIGHT.rotated(i * TAU / 12.0) * 7.0
		draw_string(_font, base + o, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(TITLE_RED, 0.07 * flicker))
	# A deep shadow, then the dark edge, then the red.
	draw_string(_font, base + Vector2(6, 7), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(0, 0, 0, 0.7))
	draw_string_outline(_font, base, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 8, TITLE_DARK)
	var fill := TITLE_RED.lerp(Color(1, 0.95, 0.95), _flash * 0.85)
	draw_string(_font, base, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, fill)
	# A bright edge along the top of the letters.
	draw_string(_font, base + Vector2(0, -2), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(1, 0.6, 0.6, 0.25 + 0.3 * _flash))
	draw_string(_font, base, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(fill, 0.85))


func _draw_button(i: int) -> void:
	var id := _buttons()[i]
	var r := _button_rect(i)
	var picked := _keyboard and i == _selected
	var play := id == "play"
	var fill := Color(TITLE_RED, 0.28) if play else Color(1, 1, 1, 0.08)
	if picked:
		fill = Color(fill, fill.a + 0.12)
	draw_rect(r, fill)
	var border := Color(1, 0.4, 0.45, 0.95) if play else Color(1, 1, 1, 0.6)
	draw_rect(r, Color(1, 1, 1, 1) if picked else border, false, 2.0)
	var f := ThemeDB.fallback_font
	var text := _button_text(id)
	var s := 30 if play else LABEL_SIZE
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(f, Vector2(r.position.x + (r.size.x - w) / 2.0, r.position.y + r.size.y / 2.0 + s * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color.WHITE)

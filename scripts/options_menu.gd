class_name OptionsMenu
extends Control
## The Options screen (from the start screen or the pause screen). Drawn in
## code like the HUD's buttons; main.gd passes it every press while it's
## open (touch doesn't emulate mouse in this project, so it hit-tests taps
## itself). Every change takes effect and is saved at once (Settings).
##
## Tap a row's value (or the row) to step it: the left part steps back, the
## rest steps on. Keys: Up/Down (W/S) pick a row, Left/Right (A/D) change it,
## Enter/Space steps it or presses it, Esc/O/P go back. The teleport keys
## work like Left/Right (J, A, Left Shift; K, D, Right Shift).

signal closed
## A setting just changed (main plays a sound to preview the sound volume).
signal changed(key: String)

const ROW_H := 52.0
const ROW_GAP := 6.0
const WIDTH := 700.0
const TITLE_H := 64.0
const LABEL_SIZE := 24
const VALUE_W := 330.0   # the value's part of a row (on the right)
const BUTTON_W := 300.0  # an action row's button (centred)

const STEPS_VOLUME := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
const STEPS_SHAKE := [0.0, 0.5, 1.0]   # None, Soft, Full (left to right; it goes round)

# key, label (actions have no key; their label is the button text)
const ROWS := [
	{"key": "colour", "label": "Flawless Color"},
	{"key": "rainbow", "label": "Flawless Rainbow"},   # (only once she's had it: see open())
	{"key": "music", "label": "Music"},
	{"key": "sfx", "label": "Sound Effects"},
	{"key": "shake", "label": "Camera Shake & Zoom"},   # (screen shake and the camera's zooms in)
	{"key": "flashes", "label": "Screen Flashes"},
	{"action": "reset", "label": "Reset To Defaults"},
	{"action": "back", "label": "Back"},
]
const FLIP_ROW := {"action": "flip", "label": "Flip Screen"}   # (upright phones, above Reset)
var _rows: Array = ROWS.duplicate()
var _selected := 0
## Set by hud.gd: true over the game (see-through), false over the title screen.
var see_through := false
## The picked row's highlight (shown from the start: it opens on the top row).
var _keyboard := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	_rows = ROWS.duplicate()
	if not Settings.rainbow_unlocked():
		_rows = _rows.filter(func(r: Dictionary) -> bool: return r.get("key", "") != "rainbow")
	if Hud.rotated:
		_rows.insert(_rows.size() - 2, FLIP_ROW)
	_selected = 0
	_keyboard = true
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()   # (the view can change size: phones turning)


# --- input (from main.gd) ---------------------------------------------------

## A fresh press while the menu is open; `pos` = its game-screen position
## (taps and clicks only).
func handle(event: InputEvent, pos: Vector2) -> void:
	if event is InputEventKey:
		_keyboard = true
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		# The teleport keys work like Left/Right: J, A, Left Shift step back;
		# K, D, Right Shift step on.
		var left_shift: bool = code == KEY_SHIFT and event.location == KEY_LOCATION_LEFT
		match code:
			KEY_UP, KEY_W: _selected = posmod(_selected - 1, _rows.size())
			KEY_DOWN, KEY_S: _selected = posmod(_selected + 1, _rows.size())
			KEY_LEFT, KEY_A, KEY_J: _step(_selected, -1)
			KEY_SHIFT: _step(_selected, -1 if left_shift else 1)
			KEY_RIGHT, KEY_D, KEY_K, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _step(_selected, 1)
			KEY_ESCAPE, KEY_O, KEY_P, KEY_BACKSPACE: close()
		queue_redraw()
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	for i in _rows.size():
		var r := _row_rect(i)
		# A button (Flip Screen, Reset To Defaults, Back) only takes taps on the
		# box drawn for it; a setting's row takes them anywhere along it.
		var area := _button_rect(i) if _rows[i].has("action") else r.grow_individual(0, ROW_GAP / 2.0, 0, ROW_GAP / 2.0)
		var touch_row: bool = Hud.is_touch() and _rows[i].has("key")
		if touch_row:
			# Touch screens: a setting takes taps right across the screen at its
			# height; the left half steps it back, the right half steps it on.
			area = Rect2(0.0, area.position.y, size.x, area.size.y)
		if area.has_point(pos):
			_selected = i
			# The value's left third steps back; anywhere else steps on.
			var back: bool = _rows[i].has("key") and pos.x < r.end.x - VALUE_W + VALUE_W / 3.0 and pos.x >= r.end.x - VALUE_W
			if touch_row:
				back = pos.x < size.x / 2.0
			_step(i, -1 if back else 1)
			queue_redraw()
			return
	# Touch screens: a tap anywhere below the settings that isn't on a button
	# goes back.
	if Hud.is_touch() and pos.y > _settings_bottom():
		close()


func _step(i: int, dir: int) -> void:
	var row: Dictionary = _rows[i]
	if row.has("action"):   # (either way presses it)
		match row["action"]:
			"reset":
				Settings.reset()
				changed.emit("reset")
			"flip":
				Hud.flip_screen()
			"back":
				close()
		return
	var key: String = row["key"]
	var values := _values(key)
	var at := values.find(Settings.get_value(key))
	if at == -1:   # (a saved value between steps: the nearest one)
		at = _nearest(values, Settings.get_value(key))
	# Colours, flashes and shake go round; volumes stop at their ends.
	var to := posmod(at + dir, values.size()) if key in ["colour", "rainbow", "flashes", "shake"] else clampi(at + dir, 0, values.size() - 1)
	if to == at:
		return
	Settings.set_value(key, values[to])
	Settings.apply()
	Settings.save_all()
	changed.emit(key)


func _values(key: String) -> Array:
	match key:
		"colour":   # (the default's own colour isn't listed again under its name)
			return ["default"] + Palette.COLOURS.keys().filter(func(k: String) -> bool: return k != Palette.COLOUR)
		"rainbow": return [true, false]
		"music", "sfx": return STEPS_VOLUME
		"shake": return STEPS_SHAKE
		"flashes": return [0.0, Settings.FLASH_SOFT, 1.0]   # None, Soft, Full
	return []


func _nearest(values: Array, v: Variant) -> int:
	if not (v is float or v is int):
		return 0
	var best := 0
	for i in values.size():
		if absf(float(values[i]) - float(v)) < absf(float(values[best]) - float(v)):
			best = i
	return best


func _value_text(key: String) -> String:
	var v: Variant = Settings.get_value(key)
	match key:
		"colour":
			return ("%s (Default)" % Palette.display_name(Palette.COLOUR)) if v == "default" else Palette.display_name(String(v))
		"rainbow":
			return "Enabled" if bool(v) else "Disabled"
		"shake":
			return "Full" if float(v) >= 0.99 else ("None" if float(v) <= 0.001 else "Soft")
		"music", "sfx":
			return "Off" if float(v) <= 0.001 else "%d%%" % roundi(float(v) * 100.0)
		"flashes":
			return "Full" if float(v) >= 0.99 else ("None" if float(v) <= 0.001 else "Soft")
	return ""


# --- drawing ---------------------------------------------------------------

func _top() -> float:
	var h := TITLE_H + _rows.size() * (ROW_H + ROW_GAP)
	return maxf((size.y - h) / 2.0, 8.0)


## The bottom of the last setting's row (its tap band included).
func _settings_bottom() -> float:
	var bottom := 0.0
	for i in _rows.size():
		if _rows[i].has("key"):
			bottom = _row_rect(i).end.y + ROW_GAP / 2.0
	return bottom


## An action row's button: BUTTON_W wide, centred in its row.
func _button_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(Vector2(r.position.x + (r.size.x - BUTTON_W) / 2.0, r.position.y), Vector2(BUTTON_W, r.size.y))


func _row_rect(i: int) -> Rect2:
	var w := minf(WIDTH, size.x - 32.0)
	return Rect2(Vector2((size.x - w) / 2.0, _top() + TITLE_H + i * (ROW_H + ROW_GAP)), Vector2(w, ROW_H))


func _draw() -> void:
	# Solid over the title screen; see-through over the game (from the pause
	# screen), so a colour shows on the game as it's picked.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.55 if see_through else 1.0))
	var font := ThemeDB.fallback_font
	var title := "OPTIONS"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(font, Vector2((size.x - tw) / 2.0, _top() + 40.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var r := _row_rect(i)
		var picked := _keyboard and i == _selected
		var text_y := r.position.y + r.size.y / 2.0 + LABEL_SIZE * 0.35
		if row.has("action"):
			# A button, centred.
			var b := _button_rect(i)
			var bw := BUTTON_W
			draw_rect(b, Color(1, 1, 1, 0.2 if picked else 0.1))
			draw_rect(b, Color(1, 1, 1, 0.95 if picked else 0.6), false, 2.0)
			var w := font.get_string_size(row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
			draw_string(font, Vector2(b.position.x + (bw - w) / 2.0, text_y), row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color.WHITE)
			continue
		draw_rect(r, Color(1, 1, 1, 0.14 if picked else 0.06))
		if picked:
			draw_rect(r, Color(1, 1, 1, 0.9), false, 2.0)
		draw_string(font, Vector2(r.position.x + 18.0, text_y), row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(1, 1, 1, 0.85))
		# The value, between arrows (touch screens: big arrows outside the row,
		# since the whole left / right half of the screen at its height steps it).
		var vx := r.end.x - VALUE_W
		var arrow := Color(1, 1, 1, 0.7)
		if Hud.is_touch():
			_draw_chevron(Vector2(r.position.x - 34.0, r.get_center().y), -1, arrow)
			_draw_chevron(Vector2(r.end.x + 34.0, r.get_center().y), 1, arrow)
		else:
			draw_string(font, Vector2(vx + 10.0, text_y), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, arrow)
			draw_string(font, Vector2(r.end.x - 26.0, text_y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, arrow)
		var key: String = row["key"]
		var text := _value_text(key)
		var vw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var left := vx + (VALUE_W - vw) / 2.0
		if key == "colour":
			var sw := Rect2(Vector2(vx + 34.0, r.position.y + 12.0), Vector2(26.0, r.size.y - 24.0))
			draw_rect(sw, Palette.swatch())
			left = maxf(left, sw.end.x + 10.0)
		draw_string(font, Vector2(left, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color.WHITE)


## A big arrow (touch screens), pointing left (dir -1) or right (1).
func _draw_chevron(centre: Vector2, dir: int, col: Color) -> void:
	var w := 12.0
	var h := 16.0
	var pts := PackedVector2Array([centre + Vector2(-w * dir, -h), centre + Vector2(w * dir, 0), centre + Vector2(-w * dir, h)])
	draw_polyline(pts, col, 5.0, true)

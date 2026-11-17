class_name OptionsMenu
extends Control
## The Options screen (from the start screen or the pause screen). Drawn in
## code like the HUD's buttons; main.gd passes it every press while it's
## open (touch doesn't emulate mouse in this project, so it hit-tests taps
## itself). Every change takes effect and is saved at once (Settings).
##
## Tap a row's value (or the row) to step it: the left part steps back, the
## rest steps on. Keys: Up/Down (W/S) pick a row, Left/Right (A/D) change it,
## Enter/Space steps it or presses it, Esc/O/P go back.

signal closed
## A setting just changed (main plays a sound to preview the sound volume).
signal changed(key: String)

const ROW_H := 52.0
const ROW_GAP := 6.0
const WIDTH := 700.0
const TITLE_H := 64.0
const LABEL_SIZE := 24
const VALUE_W := 330.0   # the value's part of a row (on the right)

const STEPS_VOLUME := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
const STEPS_SHAKE := [0.0, 0.25, 0.5, 0.75, 1.0]

# key, label (actions have no key; their label is the button text)
var _rows := [
	{"key": "colour", "label": "Flawless colour"},
	{"key": "music", "label": "Music"},
	{"key": "sfx", "label": "Sound effects"},
	{"key": "shake", "label": "Screen shake"},
	{"key": "flashes", "label": "Screen flashes"},
	{"action": "reset", "label": "Reset to defaults"},
	{"action": "back", "label": "Back"},
]
var _selected := 0
## Shown with the keyboard highlight only once a key has been used.
var _keyboard := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	_selected = 0
	_keyboard = false
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
		match event.physical_keycode:
			KEY_UP, KEY_W: _selected = posmod(_selected - 1, _rows.size())
			KEY_DOWN, KEY_S: _selected = posmod(_selected + 1, _rows.size())
			KEY_LEFT, KEY_A: _step(_selected, -1)
			KEY_RIGHT, KEY_D, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _step(_selected, 1)
			KEY_ESCAPE, KEY_O, KEY_P, KEY_BACKSPACE: close()
		queue_redraw()
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	for i in _rows.size():
		var r := _row_rect(i)
		if r.grow_individual(0, ROW_GAP / 2.0, 0, ROW_GAP / 2.0).has_point(pos):
			_selected = i
			# The value's left third steps back; anywhere else steps on.
			var back: bool = _rows[i].has("key") and pos.x < r.end.x - VALUE_W + VALUE_W / 3.0 and pos.x >= r.end.x - VALUE_W
			_step(i, -1 if back else 1)
			queue_redraw()
			return


func _step(i: int, dir: int) -> void:
	var row: Dictionary = _rows[i]
	if row.has("action"):
		if dir < 0:
			return
		match row["action"]:
			"reset":
				Settings.reset()
				changed.emit("reset")
			"back":
				close()
		return
	var key: String = row["key"]
	var values := _values(key)
	var at := values.find(Settings.get_value(key))
	if at == -1:   # (a saved value between steps: the nearest one)
		at = _nearest(values, Settings.get_value(key))
	# Colours and flashes go round; volumes and shake stop at their ends.
	var to := posmod(at + dir, values.size()) if key in ["colour", "flashes"] else clampi(at + dir, 0, values.size() - 1)
	if to == at:
		return
	Settings.set_value(key, values[to])
	Settings.apply()
	Settings.save_all()
	changed.emit(key)


func _values(key: String) -> Array:
	match key:
		"colour": return ["default"] + Palette.COLOURS.keys()
		"music", "sfx": return STEPS_VOLUME
		"shake": return STEPS_SHAKE
		"flashes": return [1.0, Settings.FLASH_SOFT]
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
			return ("Default (%s)" % Palette.COLOUR.capitalize()) if v == "default" else String(v).capitalize()
		"music", "sfx", "shake":
			return "Off" if float(v) <= 0.001 else "%d%%" % roundi(float(v) * 100.0)
		"flashes":
			return "Full" if float(v) >= 0.99 else "Soft"
	return ""


# --- drawing ---------------------------------------------------------------

func _top() -> float:
	var h := TITLE_H + _rows.size() * (ROW_H + ROW_GAP)
	return maxf((size.y - h) / 2.0, 8.0)


func _row_rect(i: int) -> Rect2:
	var w := minf(WIDTH, size.x - 32.0)
	return Rect2(Vector2((size.x - w) / 2.0, _top() + TITLE_H + i * (ROW_H + ROW_GAP)), Vector2(w, ROW_H))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.88))
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
			var bw := 300.0
			var b := Rect2(Vector2(r.position.x + (r.size.x - bw) / 2.0, r.position.y), Vector2(bw, r.size.y))
			draw_rect(b, Color(1, 1, 1, 0.2 if picked else 0.1))
			draw_rect(b, Color(1, 1, 1, 0.95 if picked else 0.6), false, 2.0)
			var w := font.get_string_size(row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
			draw_string(font, Vector2(b.position.x + (bw - w) / 2.0, text_y), row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color.WHITE)
			continue
		draw_rect(r, Color(1, 1, 1, 0.14 if picked else 0.06))
		if picked:
			draw_rect(r, Color(1, 1, 1, 0.9), false, 2.0)
		draw_string(font, Vector2(r.position.x + 18.0, text_y), row["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(1, 1, 1, 0.85))
		# The value, between arrows.
		var vx := r.end.x - VALUE_W
		var arrow := Color(1, 1, 1, 0.7)
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

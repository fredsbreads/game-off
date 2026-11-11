class_name PressRateLog
extends CanvasLayer
## TEMPORARY tool for tuning the cooldown: measures how fast you can press.
## Every teleport press (key or tap) is timed against the previous one.
##   - bottom-left of the screen: last gap, average of the last 10, fastest
##   - Godot's Output panel: one line per press, to copy and share
## Turn off with ENABLED in main.gd (PRESS_RATE_LOG), or delete this file.

const WINDOW := 10              # average over this many most recent gaps
const IGNORE_GAP_MS := 1000.0   # longer pauses aren't "spamming"; not counted

var _last_usec := 0
var _gaps: Array[float] = []
var _fastest := INF
var _count := 0
var _label: Label


func _ready() -> void:
	layer = 20
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position = Vector2(16, -70)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_label)
	_refresh()
	print("PRESS RATE LOG on: spam a teleport key, then copy these lines.")


func record(button_name: String) -> void:
	var now := Time.get_ticks_usec()
	_count += 1
	if _last_usec == 0:
		print("PRESS #%d %s (first)" % [_count, button_name])
	else:
		var gap := (now - _last_usec) / 1000.0
		if gap <= IGNORE_GAP_MS:
			_gaps.append(gap)
			if _gaps.size() > WINDOW:
				_gaps.pop_front()
			_fastest = minf(_fastest, gap)
		print("PRESS #%d %s  +%.0f ms" % [_count, button_name, gap])
	_last_usec = now
	_refresh()


func _refresh() -> void:
	if _gaps.is_empty():
		_label.text = "PRESS RATE: spam a teleport key"
		return
	var total := 0.0
	for g in _gaps:
		total += g
	var avg := total / _gaps.size()
	_label.text = "PRESS RATE  last %.0f ms  |  avg of last %d: %.0f ms (%.1f per sec)  |  fastest %.0f ms" % [
		_gaps.back(), _gaps.size(), avg, 1000.0 / avg, _fastest]

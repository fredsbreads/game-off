class_name Hud
extends CanvasLayer
## Score, distance, chain counter, start/game-over messages, the
## "rotate your device" overlay and the screen flash.
## Built in code for the grey-box; swap for a designed scene later.
##
## The view is always 1024 wide (stretch aspect "keep_width"), so x
## positions can be fixed; only the height varies between screens.

## Score, distance and chain are still tracked internally; this only
## controls whether any of it is shown (HUD, pop-ups, menus, distance signs).
const SHOW_SCORE_UI := false

const VIEW_W := 1024.0
const CHAIN_COLOR_LOW := Color(1, 1, 1)
const CHAIN_COLOR_HIGH := Color(1, 0.55, 0.3)

var _score: Label
var _distance: Label
var _chain: Label
var _chain_bar_bg: ColorRect
var _chain_bar: ColorRect
var _message: Label
var _rotate: ColorRect
var _flash: ColorRect
var _flash_tween: Tween


func _ready() -> void:
	_flash = _rect(Color(1, 1, 1, 0))
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_score = _label(30, Vector2(20, 10))
	_distance = _label(20, Vector2(22, 50))

	_chain = _label(34, Vector2(VIEW_W - 220, 6))
	_chain.size.x = 200
	_chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chain_bar_bg = _rect(Color(1, 1, 1, 0.15))
	_chain_bar_bg.position = Vector2(VIEW_W - 200, 54)
	_chain_bar_bg.size = Vector2(180, 6)
	_chain_bar = _rect(Color(1, 1, 1, 0.9))
	_chain_bar.position = _chain_bar_bg.position
	_chain_bar.size = _chain_bar_bg.size

	_message = _label(26, Vector2.ZERO)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_rotate = _rect(Color(0.05, 0.05, 0.07, 1))
	_rotate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rotate_label := _label(72, Vector2.ZERO)
	rotate_label.reparent(_rotate)
	rotate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_label.text = "Rotate your device\nto landscape"


func _process(_delta: float) -> void:
	_rotate.visible = is_portrait()


func is_portrait() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.y > s.x * 1.05


func set_stats(score: int, distance: float, chain: int, chain_fraction: float) -> void:
	_score.visible = SHOW_SCORE_UI
	_distance.visible = SHOW_SCORE_UI
	_score.text = "%d" % score
	_distance.text = "%d m" % int(distance)
	var show_chain := SHOW_SCORE_UI and chain > 0
	_chain.visible = show_chain
	_chain_bar_bg.visible = show_chain
	_chain_bar.visible = show_chain
	if show_chain:
		_chain.text = "x%d" % chain
		var col := CHAIN_COLOR_LOW.lerp(CHAIN_COLOR_HIGH, clampf((chain - 1) / 6.0, 0.0, 1.0))
		_chain.add_theme_color_override("font_color", col)
		_chain_bar.color = col
		_chain_bar.size.x = 180.0 * clampf(chain_fraction, 0.0, 1.0)


func show_start(best: int) -> void:
	var lines := "RED FLASH  —  prototype\n\n"
	lines += "SHORT teleport:  ← / J / A / L-Shift   or tap the LEFT half\n"
	lines += "LONG teleport:   → / K / D / R-Shift   or tap the RIGHT half\n\n"
	lines += "Land on enemies to slash them. Long-jump over spikes.\n"
	if SHOW_SCORE_UI and best > 0:
		lines += "\nBest: %d\n" % best
	lines += "\nPress or tap to start"
	_message.text = lines
	_message.visible = true


func show_game_over(stats: Dictionary) -> void:
	var lines := "GAME OVER\n\n"
	if SHOW_SCORE_UI:
		lines += "Distance  %d m\n" % int(stats["distance"])
		lines += "Kills  %d      Best chain  x%d\n\n" % [stats["kills"], stats["best_chain"]]
		lines += "Score  %d\n" % stats["score"]
		lines += ("NEW BEST!\n" if stats["new_best"] else "Best  %d\n" % stats["best"])
		lines += "\n"
	lines += "Press or tap to retry"
	_message.text = lines
	_message.visible = true


func hide_message() -> void:
	_message.visible = false


func flash(color: Color, duration: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, duration)


func _label(font_size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(l)
	return l


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

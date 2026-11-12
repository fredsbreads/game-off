class_name Hud
extends CanvasLayer
## Score, distance, chain counter, start/game-over messages, the
## "rotate your device" overlay and the screen flash.
## Built in code for the grey-box; swap for a designed scene later.
##
## The view is at least 1024x576 and grows to fill wider or taller screens
## (stretch aspect "expand"), so right-aligned items follow the real width.

## Everything is always tracked internally; these only control what's shown.
## Distance: the metres counter, the distance signs on the ground, and the
## distance line on the game-over screen.
const SHOW_DISTANCE_UI := false
## Kills: the kill counter (top-left) and the kills line on the game-over screen.
const SHOW_KILLS_UI := true
## Score: score, kills, chain counter, point pop-ups and best score.
const SHOW_SCORE_UI := false

const CHAIN_COLOR_LOW := Color(1, 1, 1)
const CHAIN_COLOR_HIGH := Color(1, 0.55, 0.3)

var _score: Label
var _distance: Label
var _kills: Label
var _chain: Label
var _chain_bar_bg: ColorRect
var _chain_bar: ColorRect
var _message: Label
var _rotate: ColorRect
var _rotate_label: Label
var _rotate_sprite: AnimatedSprite2D

# Phones held sideways get this message instead of the game (in the
# browser, upright play is the intended way; see export_presets.cfg).
const PORTRAIT_MESSAGE := "Play on Portrait Mode.\nLock your Rotation.\n(Mobile browsers are weird ¯\\_(ツ)_/¯)"
# The default font has no ツ; this 2 KB font supplies just that character.
const SHRUG_FONT := preload("res://assets/fonts/NotoSansJP-shrug.ttf")
var _flash: ColorRect
var _flash_tween: Tween
var _pause_button: Control
var _pause_dim: ColorRect
var _flip_button: Control
const FLIP_BUTTON_SIZE := Vector2(300, 64)
var _message_before_pause := ""
var _message_visible_before_pause := false

const PAUSE_BUTTON_SIZE := 64.0
const PAUSE_BUTTON_MARGIN := 14.0


func _ready() -> void:
	_flash = _rect(Color(1, 1, 1, 0))
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_score = _label(30, Vector2(20, 10))
	_distance = _label(20, Vector2(22, 50))
	_kills = _label(30, Vector2(20, 10))

	_chain = _label(34, Vector2.ZERO)
	_chain.size.x = 200
	_chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chain_bar_bg = _rect(Color(1, 1, 1, 0.15))
	_chain_bar_bg.size = Vector2(180, 6)
	_chain_bar = _rect(Color(1, 1, 1, 0.9))
	_chain_bar.size = _chain_bar_bg.size

	# Pause button, top-right. Drawn only; main.gd hit-tests taps against it
	# (touch doesn't emulate mouse in this project, so Buttons won't see taps).
	_pause_button = Control.new()
	_pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_button.size = Vector2(PAUSE_BUTTON_SIZE, PAUSE_BUTTON_SIZE)
	_pause_button.visible = false
	_pause_button.draw.connect(_draw_pause_button)
	add_child(_pause_button)

	_pause_dim = _rect(Color(0, 0, 0, 0.55))
	_pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_dim.visible = false

	_flip_button = Control.new()
	_flip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip_button.size = FLIP_BUTTON_SIZE
	_flip_button.visible = false
	_flip_button.draw.connect(_draw_flip_button)

	_message = _label(26, Vector2.ZERO)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	add_child(_flip_button)   # above the pause message

	_rotate = _rect(Color(0.05, 0.05, 0.07, 1))
	_rotate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_label = _label(34, Vector2.ZERO)
	_rotate_label.reparent(_rotate)
	_rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_label.text = PORTRAIT_MESSAGE
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.fallbacks = [SHRUG_FONT]
	_rotate_label.add_theme_font_override("font", font)
	# Her falling animation beside the message.
	_rotate_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 10.0)
	for i in 3:
		var tex := AtlasTexture.new()
		tex.atlas = Player.SHEET
		tex.region = Rect2(i * 96, 5 * 96, 96, 96)
		frames.add_frame("default", tex)
	_rotate_sprite.sprite_frames = frames
	_rotate_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rotate_sprite.scale = Vector2(4, 4)
	_rotate_sprite.play()
	_rotate.add_child(_rotate_sprite)


func _process(_delta: float) -> void:
	_rotate.visible = needs_portrait()
	var view := get_viewport().get_visible_rect().size
	if _rotate.visible:
		_rotate_sprite.position = Vector2(view.x * 0.2, view.y * 0.5)
		_rotate_label.position = Vector2(view.x * 0.36, 0)
		_rotate_label.size = Vector2(view.x * 0.6, view.y)
	var right := view.x
	_chain.position = Vector2(right - 220, 6)
	_chain_bar_bg.position = Vector2(right - 200, 54)
	_chain_bar.position = _chain_bar_bg.position
	_pause_button.position = Vector2(right - PAUSE_BUTTON_SIZE - PAUSE_BUTTON_MARGIN, PAUSE_BUTTON_MARGIN)
	_flip_button.position = Vector2((view.x - FLIP_BUTTON_SIZE.x) / 2.0, view.y * 0.5 + 90.0)


## True on a phone/tablet held sideways in the browser: play is upright there.
func needs_portrait() -> bool:
	if not OS.has_feature("web"):
		return false
	return int(JavaScriptBridge.eval("window.redFlashNeedPortrait === true ? 1 : 0", true)) == 1


func set_stats(score: int, distance: float, kills: int, chain: int, chain_fraction: float) -> void:
	_kills.visible = SHOW_KILLS_UI and not SHOW_SCORE_UI
	_kills.text = "%d kills" % kills if kills != 1 else "1 kill"
	_score.visible = SHOW_SCORE_UI
	_distance.visible = SHOW_DISTANCE_UI
	# Move the distance up into the score's spot when the score is hidden.
	_distance.position = Vector2(22, 50) if SHOW_SCORE_UI else Vector2(20, 10)
	_distance.add_theme_font_size_override("font_size", 20 if SHOW_SCORE_UI else 30)
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
	var lines := "left tap - shift\n"
	lines += "right tap - forward\n"
	lines += "tap both - shift + forward"
	if SHOW_SCORE_UI and best > 0:
		lines += "\n\nBest: %d" % best
	_message.text = lines
	_message.visible = true


func show_game_over(stats: Dictionary) -> void:
	var lines := "GAME OVER\n\n"
	if SHOW_DISTANCE_UI:
		lines += "Distance  %d m\n" % int(stats["distance"])
	if SHOW_KILLS_UI and not SHOW_SCORE_UI:
		lines += "Kills  %d\n" % stats["kills"]
	if SHOW_SCORE_UI:
		lines += "Kills  %d      Best chain  x%d\n\n" % [stats["kills"], stats["best_chain"]]
		lines += "Score  %d\n" % stats["score"]
		lines += ("NEW BEST!\n" if stats["new_best"] else "Best  %d\n" % stats["best"])
	if SHOW_DISTANCE_UI or SHOW_KILLS_UI or SHOW_SCORE_UI:
		lines += "\n"
	lines += "Press or tap to retry"
	_message.text = lines
	_message.visible = true


func set_pause_button_visible(value: bool) -> void:
	_pause_button.visible = value


## A slightly larger area than the drawn button, so it's easy to hit.
func pause_button_contains(pos: Vector2) -> bool:
	return _pause_button.visible and _pause_button.get_rect().grow(12.0).has_point(pos)


## can_flip: show the "Flip screen" button (upright phones only).
func show_paused(paused: bool, can_flip: bool = false) -> void:
	_pause_dim.visible = paused
	_pause_button.visible = not paused
	_flip_button.visible = paused and can_flip
	if paused:
		_message_before_pause = _message.text
		_message_visible_before_pause = _message.visible
		_message.text = "PAUSED\n\nPress any key or tap to resume"
		_message.visible = true
	else:
		_message.text = _message_before_pause
		_message.visible = _message_visible_before_pause


func flip_button_contains(pos: Vector2) -> bool:
	return _flip_button.visible and _flip_button.get_rect().grow(10.0).has_point(pos)


func _draw_flip_button() -> void:
	var s := FLIP_BUTTON_SIZE
	_flip_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.12))
	_flip_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	var text := "Flip screen"
	var size := 26
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_flip_button.draw_string(font, Vector2((s.x - w) / 2.0, s.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _draw_pause_button() -> void:
	var s := PAUSE_BUTTON_SIZE
	_pause_button.draw_rect(Rect2(0, 0, s, s), Color(0, 0, 0, 0.35))
	_pause_button.draw_rect(Rect2(0, 0, s, s), Color(1, 1, 1, 0.5), false, 2.0)
	var bar := Vector2(s * 0.14, s * 0.5)
	_pause_button.draw_rect(Rect2(Vector2(s * 0.3, s * 0.25), bar), Color(1, 1, 1, 0.85))
	_pause_button.draw_rect(Rect2(Vector2(s * 0.56, s * 0.25), bar), Color(1, 1, 1, 0.85))


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

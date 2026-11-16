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
## Kills: the kill counter (top-left). The game-over screen always shows kills.
const SHOW_KILLS_UI := false
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
const PORTRAIT_MESSAGE := "Play in Portrait Mode.\nLock your Rotation.\n(Mobile browsers are weird ¯\\_(ツ)_/¯)"
# The default font has no ツ; this 2 KB font supplies just that character.
const SHRUG_FONT := preload("res://assets/fonts/NotoSansJP-shrug.ttf")
var _flash: ColorRect
# The level-10 colour change: a glowing band sweeping across the screen.
var _sweep: Control
var _sweep_x := -1.0          # screen x (0..1) of the band, < 0 = none
var _sweep_colour := Color.WHITE
const SWEEP_GLOW := 70.0      # pixels either side of the band's core
const SWEEP_WASH := 0.12      # the new colour, faintly, over the part already swept
var _flash_tween: Tween
var _pause_button: Control
var _pause_dim: ColorRect
var _flip_button: Control
const FLIP_BUTTON_SIZE := Vector2(300, 64)
# Practice mode toggle on the pause screen (N on a keyboard), plus a small
# note in the corner while enemies are off.
var _enemies_button: Control
# Her level-10 colour (Palette), stepped through on the pause screen.
var _colour_button: Control
# The start screen's "Start at level" choice (1 or 5).
var _level_button: Control
var _start_level := 1
var _enemies_off_label: Label
var _enemies_off := false
var _message_before_pause := ""
var _message_visible_before_pause := false

# Progression bar, centred above the ceiling row.
const PROGRESS_SIZE := Vector2(320, 12)
const PROGRESS_FILL := Color(1, 1, 1, 0.9)
const PROGRESS_PENDING := Color(0.6, 0.6, 0.6, 0.75)   # this chain's kills, not yet counted
const PROGRESS_EMPTY := Color(1, 1, 1, 0.12)
const PROGRESS_BONUS := Color(1.0, 0.85, 0.3)        # PERFECT's extra half, growing in
const PROGRESS_CRUMBLE := Color(0.6, 0.6, 0.6)       # a dropped chain's lost half, falling off
# When a chain ends, the bar acts out its grade before the kills count:
# RESULT_ACT seconds of growing / crumbling / turning solid, then a short hold.
const RESULT_ACT := 0.35
const RESULT_HOLD := 0.2
const CRUMBLE_PIECE := 8.0     # pixels
const CRUMBLE_FALL := 18.0     # pixels the pieces drop
var _result := {}              # the chain being shown (empty = none)
var _result_t := 0.0
var _progress: Control
var _progress_level: Label
# The current flawless streak (kills in a row without letting one get away),
# right of the bar.
var _streak: Label
var _p_bar := 0.0
var _p_size := 1.0
var _p_pending := 0.0
var _p_pulse := 0.0
var _p_tween: Tween

const PAUSE_BUTTON_SIZE := 64.0
const PAUSE_BUTTON_MARGIN := 14.0


func _ready() -> void:
	_flash = _rect(Color(1, 1, 1, 0))
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sweep = Control.new()
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sweep.draw.connect(_draw_sweep)
	add_child(_sweep)

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

	_progress = Control.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.size = PROGRESS_SIZE
	_progress.visible = false
	_progress.draw.connect(_draw_progress)
	add_child(_progress)
	_progress_level = _label(20, Vector2.ZERO)
	_progress_level.reparent(_progress)
	_progress_level.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_streak = _label(20, Vector2.ZERO)
	_streak.reparent(_progress)
	_streak.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))

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
	_enemies_button = Control.new()
	_enemies_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemies_button.size = FLIP_BUTTON_SIZE
	_enemies_button.visible = false
	_enemies_button.draw.connect(_draw_enemies_button)
	add_child(_enemies_button)
	_colour_button = Control.new()
	_colour_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colour_button.size = FLIP_BUTTON_SIZE
	_colour_button.visible = false
	_colour_button.draw.connect(_draw_colour_button)
	add_child(_colour_button)
	_level_button = Control.new()
	_level_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_button.size = FLIP_BUTTON_SIZE
	_level_button.visible = false
	_level_button.draw.connect(_draw_level_button)
	add_child(_level_button)
	_enemies_off_label = _label(20, Vector2(20, 14))
	_enemies_off_label.text = "NO ENEMIES (N)"
	_enemies_off_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_enemies_off_label.visible = false

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


func _process(delta: float) -> void:
	_process_result(delta)
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
	# The pause screen's buttons, side by side under the message (so they fit
	# on an upright phone too).
	var shown: Array[Control] = []
	for b in [_flip_button, _enemies_button, _colour_button]:
		if b.visible:
			shown.append(b)
	var gap := 16.0
	var row := shown.size() * FLIP_BUTTON_SIZE.x + maxf(shown.size() - 1, 0) * gap
	var x := (view.x - row) / 2.0
	for b in shown:
		b.position = Vector2(x, view.y * 0.5 + 55.0)
		x += FLIP_BUTTON_SIZE.x + gap
	_level_button.position = Vector2((view.x - FLIP_BUTTON_SIZE.x) / 2.0, view.y * 0.5 + 55.0)


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


## The progression bar: `bar` of `bar_size` filled, plus this chain's
## `pending` kills shown in grey after it. ceiling_y = the ceiling's screen y;
## the bar sits in the middle of the band above it.
func set_progress(level: int, bar: float, bar_size: float, pending: int, ceiling_y: float) -> void:
	_progress.visible = true
	_p_bar = bar
	_p_size = maxf(bar_size, 0.001)
	_p_pending = pending
	if not _result.is_empty():
		level = _result["level"]
	var view := get_viewport().get_visible_rect().size
	_progress.position = Vector2((view.x - PROGRESS_SIZE.x) / 2.0, maxf(ceiling_y * 0.5, 30.0) - PROGRESS_SIZE.y / 2.0)
	_progress_level.text = "LV %d" % level
	_progress_level.position = Vector2(-_progress_level.get_minimum_size().x - 12.0, (PROGRESS_SIZE.y - _progress_level.get_minimum_size().y) / 2.0)
	_progress.queue_redraw()


## The current flawless streak, shown right of the bar.
func set_streak(n: int) -> void:
	_streak.text = "Streak %d" % n
	# In her reward colour while she has it.
	_streak.add_theme_color_override("font_color", Palette.swatch().lightened(0.25) if Palette.pink > 0.5 else Color(1, 1, 1, 0.75))
	_streak.position = Vector2(PROGRESS_SIZE.x + 12.0, (PROGRESS_SIZE.y - _streak.get_minimum_size().y) / 2.0)


func hide_progress() -> void:
	_progress.visible = false


## Shows how a finished chain counts: `kills` were grey (pending) on top of
## `old_bar`. PERFECT turns solid while an extra half grows in gold,
## CLEAN/SINGLE turn solid, DROPPED keeps half (turning solid) while the other half crumbles off. Then the bar flashes and shows
## the real values again (set_progress).
func show_chain_result(grade: String, kills: int, old_bar: float, bar_size: float, level: int) -> void:
	var gain := minf(kills * float(Progression.MULTIPLIER[grade]), bar_size - old_bar)
	_result = {"grade": grade, "kills": float(kills), "base": old_bar, "gain": maxf(gain, 0.0),
		"size": maxf(bar_size, 0.001), "level": level}
	_result_t = 0.0


func _process_result(delta: float) -> void:
	if _result.is_empty():
		return
	_result_t += delta
	_progress.queue_redraw()
	if _result_t >= RESULT_ACT + RESULT_HOLD:
		_result = {}
		pulse_progress()


## A short flash on the bar when a chain is added to it.
func pulse_progress() -> void:
	if _p_tween:
		_p_tween.kill()
	_p_pulse = 1.0
	_p_tween = create_tween()
	_p_tween.tween_method(func(v: float) -> void:
		_p_pulse = v
		_progress.queue_redraw(), 1.0, 0.0, 0.35)


func _draw_progress() -> void:
	var s := PROGRESS_SIZE
	var full := Rect2(Vector2.ZERO, s)
	_progress.draw_rect(full, PROGRESS_EMPTY)
	if not _result.is_empty():
		_draw_result()
		_progress.draw_rect(full.grow(2.0), Color(1, 1, 1, 0.35), false, 2.0)
		return
	var filled := s.x * clampf(_p_bar / _p_size, 0.0, 1.0)
	var pending := minf(s.x * _p_pending / _p_size, s.x - filled)
	if pending > 0.0:
		_progress.draw_rect(Rect2(filled, 0, pending, s.y), PROGRESS_PENDING)
	if filled > 0.0:
		_progress.draw_rect(Rect2(0, 0, filled, s.y), PROGRESS_FILL)
	var outline := Color(1, 1, 1, 0.35 + 0.65 * _p_pulse)
	_progress.draw_rect(full.grow(2.0 + 3.0 * _p_pulse), outline, false, 2.0)


func _draw_result() -> void:
	var s := PROGRESS_SIZE
	var px := s.x / float(_result["size"])
	var base := minf(float(_result["base"]) * px, s.x)
	var kills := minf(float(_result["kills"]) * px, s.x - base)
	var gain := minf(float(_result["gain"]) * px, s.x - base)
	var p := ease(clampf(_result_t / RESULT_ACT, 0.0, 1.0), 0.4)   # fast start, soft end
	var hold := clampf((_result_t - RESULT_ACT) / RESULT_HOLD, 0.0, 1.0)
	if base > 0.0:
		_progress.draw_rect(Rect2(0, 0, base, s.y), PROGRESS_FILL)
	match _result["grade"]:
		"PERFECT":
			# The kills turn solid while the bonus half grows in gold beside them.
			_progress.draw_rect(Rect2(base, 0, kills, s.y), PROGRESS_PENDING.lerp(PROGRESS_FILL, p))
			var extra := maxf(gain - kills, 0.0) * p
			if extra > 0.0:
				_progress.draw_rect(Rect2(base + kills, 0, extra, s.y), PROGRESS_BONUS.lerp(PROGRESS_FILL, hold))
		"DROPPED":
			# The kept half turns solid while the lost half crumbles.
			_progress.draw_rect(Rect2(base, 0, gain, s.y), PROGRESS_PENDING.lerp(PROGRESS_FILL, p))
			# The lost half breaks into pieces that fall and fade.
			var x := base + gain
			var i := 0
			while x < base + kills - 0.01:
				var w := minf(CRUMBLE_PIECE, base + kills - x)
				var fall := CRUMBLE_FALL * p * (0.7 + 0.15 * (i % 3))
				var c := PROGRESS_CRUMBLE
				c.a = 1.0 - p
				_progress.draw_rect(Rect2(x + 1.0, fall, w - 2.0, s.y), c)
				x += w
				i += 1
		_:   # CLEAN, SINGLE: counts as it is
			_progress.draw_rect(Rect2(base, 0, kills, s.y), PROGRESS_PENDING.lerp(PROGRESS_FILL, p))


## The start screen's level choice: shown with the start message.
func show_level_choice(level: int) -> void:
	_start_level = level
	_level_button.visible = true
	_level_button.queue_redraw()


func level_button_contains(pos: Vector2) -> bool:
	return _level_button.visible and _level_button.get_rect().grow(10.0).has_point(pos)


func _draw_level_button() -> void:
	var s := FLIP_BUTTON_SIZE
	_level_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.12))
	_level_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	var text := "Start at level %d" % _start_level
	var size := 26
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_level_button.draw_string(font, Vector2((s.x - w) / 2.0, s.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


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
	if not SHOW_SCORE_UI:
		lines += "Kills  %d\n" % stats["kills"]
		lines += "Level reached  %d\n" % stats["level"]
		lines += "Flawless Streak (No Survivors)  %d\n" % stats["best_sweep"]
	if SHOW_SCORE_UI:
		lines += "Kills  %d      Best chain  x%d\n\n" % [stats["kills"], stats["best_chain"]]
		lines += "Score  %d\n" % stats["score"]
		lines += ("NEW BEST!\n" if stats["new_best"] else "Best  %d\n" % stats["best"])
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
	_enemies_button.visible = paused
	_colour_button.visible = paused
	_colour_button.queue_redraw()
	if paused:
		_message_before_pause = _message.text
		_message_visible_before_pause = _message.visible
		_message.text = "PAUSED\n\nPress any key or tap to resume"
		_message.visible = true
	else:
		_message.text = _message_before_pause
		_message.visible = _message_visible_before_pause


func set_enemies_off(off: bool) -> void:
	_enemies_off = off
	_enemies_off_label.visible = off
	_enemies_button.queue_redraw()


func enemies_button_contains(pos: Vector2) -> bool:
	return _enemies_button.visible and _enemies_button.get_rect().grow(10.0).has_point(pos)


func _draw_enemies_button() -> void:
	var s := FLIP_BUTTON_SIZE
	_enemies_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.12))
	_enemies_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	var text := "Enemies: off" if _enemies_off else "Enemies: on"
	var size := 26
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_enemies_button.draw_string(font, Vector2((s.x - w) / 2.0, s.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func colour_button_contains(pos: Vector2) -> bool:
	return _colour_button.visible and _colour_button.get_rect().grow(10.0).has_point(pos)


func refresh_colour_button() -> void:
	_colour_button.queue_redraw()


func _draw_colour_button() -> void:
	var s := FLIP_BUTTON_SIZE
	_colour_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.12))
	_colour_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.7), false, 2.0)
	var sw := Rect2(Vector2(16, 14), Vector2(36, s.y - 28))
	_colour_button.draw_rect(sw, Palette.swatch())
	var font := ThemeDB.fallback_font
	var text := "Colour: " + Palette.colour_name.capitalize()
	var size := 24
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var left := sw.end.x + 10.0
	_colour_button.draw_string(font, Vector2(left + (s.x - left - w) / 2.0, s.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


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
	_level_button.visible = false


## The colour-change wave at screen x `x` (0..1, right to left), in
## `colour`; x < 0 hides it.
func show_sweep(x: float, colour: Color) -> void:
	_sweep_x = x
	_sweep_colour = colour
	_sweep.queue_redraw()


func _draw_sweep() -> void:
	if _sweep_x < -0.5:   # hidden
		return
	var view := _sweep.size
	var cx := _sweep_x * view.x
	# Behind the wave (already changed): a faint wash of the new colour.
	if cx < view.x:
		_sweep.draw_rect(Rect2(Vector2(maxf(cx, 0.0), 0), Vector2(view.x - maxf(cx, 0.0), view.y)), Color(_sweep_colour, SWEEP_WASH))
	# The wave: a glow in her colour, brightest at its white core.
	var step := 4.0
	var d := -SWEEP_GLOW
	while d <= SWEEP_GLOW:
		var k := 1.0 - absf(d) / SWEEP_GLOW
		_sweep.draw_rect(Rect2(Vector2(cx + d, 0), Vector2(step, view.y)), Color(_sweep_colour.lightened(0.3), 0.55 * k * k))
		d += step
	_sweep.draw_rect(Rect2(Vector2(cx - 3.0, 0), Vector2(6.0, view.y)), Color(1, 1, 1, 0.9))


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

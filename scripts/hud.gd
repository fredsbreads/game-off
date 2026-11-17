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
# Opens the Options screen (on the start screen and the pause screen).
var _options_button: Control
var _on_pause_screen := false
## The Options screen itself (main.gd passes it presses while it's open).
var options: OptionsMenu
# The start screen's "Start at level" choice (1 or 5).
# The game-over screen's "Main menu" button (a retry goes straight into a run).
var _menu_button: Control
## The title screen (main.gd passes it presses while it's open).
var menu: MainMenu
var _enemies_off_label: Label
var _enemies_off := false
var _message_before_pause := ""
var _message_visible_before_pause := false

# The level bar (a katana), the power-up bolt and the flawless streak,
# centred above the ceiling row (scripts/top_bar.gd).
var _top: TopBar

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

	_top = TopBar.new()
	_top.visible = false
	add_child(_top)

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
	_options_button = Control.new()
	_options_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_button.size = FLIP_BUTTON_SIZE
	_options_button.visible = false
	_options_button.draw.connect(_draw_options_button)
	add_child(_options_button)
	_menu_button = Control.new()
	_menu_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_button.size = FLIP_BUTTON_SIZE
	_menu_button.visible = false
	_menu_button.draw.connect(_draw_menu_button)
	add_child(_menu_button)
	_enemies_off_label = _label(20, Vector2(20, 14))
	_enemies_off_label.text = "NO ENEMIES (N)"
	_enemies_off_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_enemies_off_label.visible = false

	menu = MainMenu.new()
	add_child(menu)
	options = OptionsMenu.new()
	add_child(options)   # over everything but the "turn your phone" screen

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
	for b in [_flip_button, _enemies_button, _options_button]:
		if b.visible and _on_pause_screen:
			shown.append(b)
	var gap := 16.0
	var row := shown.size() * FLIP_BUTTON_SIZE.x + maxf(shown.size() - 1, 0) * gap
	var x := (view.x - row) / 2.0
	for b in shown:
		b.position = Vector2(x, view.y * 0.5 + 55.0)
		x += FLIP_BUTTON_SIZE.x + gap
	_menu_button.position = Vector2((view.x - FLIP_BUTTON_SIZE.x) / 2.0, view.y - FLIP_BUTTON_SIZE.y - 24.0)


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
	_top.visible = not menu.visible   # (hidden behind the title screen)
	_top.set_progress(level, bar, bar_size, pending)
	var view := get_viewport().get_visible_rect().size
	var ext := _top.extent()
	_top.position = Vector2((view.x - (ext.y - ext.x)) / 2.0 - ext.x, maxf(ceiling_y * 0.5, 34.0) - TopBar.BLADE.y / 2.0)


## The power-up meter: value out of full; charged = full and ready.
func set_charge(value: int, full: int, charged: bool) -> void:
	_top.set_charge(value, full, charged)


## The current flawless streak.
func set_streak(n: int) -> void:
	_top.set_streak(n)


func hide_progress() -> void:
	_top.visible = false


## Shows how a finished chain counts (see TopBar.show_chain_result).
func show_chain_result(grade: String, kills: int, old_bar: float, bar_size: float, level: int) -> void:
	_top.show_chain_result(grade, kills, old_bar, bar_size, level)


## A short flash on the bar when a chain is added to it.
func pulse_progress() -> void:
	_top.pulse()


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
	_menu_button.visible = true


func menu_button_contains(pos: Vector2) -> bool:
	return _menu_button.visible and _menu_button.get_rect().grow(10.0).has_point(pos)


func _draw_menu_button() -> void:
	var s := FLIP_BUTTON_SIZE
	_menu_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.12))
	_menu_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	var text := "Main menu (M)"
	var size := 26
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_menu_button.draw_string(font, Vector2((s.x - w) / 2.0, s.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


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
	_on_pause_screen = paused
	_options_button.visible = paused
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


func options_button_contains(pos: Vector2) -> bool:
	return _options_button.visible and not options.visible and _options_button.get_rect().grow(10.0).has_point(pos)


func _draw_options_button() -> void:
	var s := FLIP_BUTTON_SIZE
	_options_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.12))
	_options_button.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	var text := "Options (O)"
	var size := 26
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_options_button.draw_string(font, Vector2((s.x - w) / 2.0, s.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


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
	_menu_button.visible = false
	_options_button.visible = false


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
	_flash.color.a *= Settings.flashes   # the Screen flashes option
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

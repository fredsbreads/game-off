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
var _rotate_font: FontVariation
var _rotate_sprite: AnimatedSprite2D

# Phones held sideways get this message instead of the game (in the
# browser, upright play is the intended way; see export_presets.cfg).
const PORTRAIT_TITLE := "PLAY IN PORTRAIT"
const PORTRAIT_LINE := "Turn your phone upright and lock your rotation."
const PORTRAIT_NOTE := "(Mobile browsers are weird ¯\\_(ツ)_/¯)"
var _flash: ColorRect
# The level-10 colour change: a glowing band sweeping across the screen.
var _sweep: Control
var _sweep_x := -1.0          # screen x (0..1) of the band, < 0 = none
var _sweep_colour := Color.WHITE
const SWEEP_GLOW := 70.0      # pixels either side of the band's core
const SWEEP_WASH := 0.12      # the new colour, faintly, over the part already swept
var _flash_tween: Tween
var _pause_button: Control
## Behind the pause and game-over screens: the game dimmed, with a darker band
## across the middle (red hairlines at its edges) and the screen's title in
## the title screen's glowing red. The game still shows above and below.
var _pause_dim: Control
var _backdrop_mode := "pause"   # "pause" or "over"
var _band := Rect2()            # the band (set in _process)
var _over_stats: Array = []     # [[value, label], ...] on the game-over screen
var _over_hint := ""
var _over_start_note := ""   # e.g. "Started At 5" (under the level; empty from level 1)
var _over_t := 0.0              # seconds the game-over screen has shown
## On a computer the game-over screen has buttons only: New Run (picked
## first) over Main Menu. (On touch screens a tap anywhere starts a new run.)
var _retry_button: Control
var _over_sel := 0             # 0 = New Run, 1 = Main Menu
var _flip_button: Control
const FLIP_BUTTON_SIZE := Vector2(300, 58)   # (as the title screen's buttons)
const BAND_PAD := 30.0
const PAUSE_TITLE_H := 92.0
const OVER_TITLE_H := 96.0
const OVER_STATS_H := 104.0   # (room for "Started At N" under the level)
const OVER_HINT_H := 64.0
const OVER_HINT_SIZE := 34     # "Tap Anywhere To Retry"
const OVER_HINT_PULSE := 4.0   # its breathing (radians per second)
# Practice mode toggle on the pause screen (N on a keyboard), plus a small
# note in the corner while enemies are off.
# Opens the Options screen (on the start screen and the pause screen).
var _options_button: Control
var _on_pause_screen := false
## The Options screen itself (main.gd passes it presses while it's open).
var options: OptionsMenu
# The start screen's "Start at level" choice (1 or 5).
# The game-over screen's "Main menu" button (a retry goes straight into a run).
var _menu_button: Control
# The pause screen's "Main Menu" button (leaves the run for the title screen).
var _pause_menu_button: Control
var _pause_skip_button: Control   # (the tutorial) "Skip Tutorial"
var _skip_button: Control         # ...and the one on screen while it plays
var _skip_on := false
const SKIP_BUTTON_SIZE := Vector2(170, 44)
var _over_options_button: Control
var _on_over_screen := false
# ...and "Resume". The pause screen's buttons stand in a column under
# "PAUSED"; on a keyboard Up/Down pick one (Resume, each time it opens) and
# Left/Right (or Enter/Space) press it.
var _resume_button: Control
var _pause_sel := 0
## The title screen (main.gd passes it presses while it's open).
var menu: MainMenu
## The power-up's auto-chain on screen (scripts/auto_overlay.gd).
var auto_overlay: AutoOverlay
var _pause_can_flip := false
var _message_before_pause := ""
var _message_visible_before_pause := false

# The level bar (a katana), the power-up bolt and the flawless streak,
# centred above the ceiling row (scripts/top_bar.gd).
var _top: TopBar
# The tutorial: "Tap Left", "Tap Right", "Tap Both" stacked on the right of
# the screen, each with an arrow to its left showing where that move takes
# her from where she is (up or down; forward; up-right or down-right). Dull
# until she does that move (then her red, with a pop); when all three are
# done they flicker and fizzle out.
var _tut: Control
var _tut_lit := {}        # key -> seconds since it lit
var _tut_fizzle := -1.0   # seconds since all three were done (-1: not yet)
var _tut_rng := RandomNumberGenerator.new()
var tutorial_on_floor := true   # (main.gd: she's on the floor: Tap Left goes up)
const TUT_FIZZLE_TIME := 0.8

const PAUSE_BUTTON_SIZE := 80.0
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
	# Hidden until there's a chain to show (else it flashes up for a frame
	# at the top left when the scene starts: a new start level reloads it).
	_chain.visible = false
	_chain_bar_bg.visible = false
	_chain_bar.visible = false

	_top = TopBar.new()
	_top.visible = false
	add_child(_top)

	# The first-time tutorial's three prompts (see show_tutorial).
	_tut = Control.new()
	_tut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tut.visible = false
	_tut.draw.connect(_draw_tutorial)
	add_child(_tut)
	_coach = Control.new()
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coach.visible = false
	_coach.draw.connect(_draw_coach)
	add_child(_coach)

	# Pause button, top-right. Drawn only; main.gd hit-tests taps against it
	# (touch doesn't emulate mouse in this project, so Buttons won't see taps).
	_pause_button = Control.new()
	_pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_button.size = Vector2(PAUSE_BUTTON_SIZE, PAUSE_BUTTON_SIZE)
	_pause_button.visible = false
	_pause_button.draw.connect(_draw_pause_button)
	add_child(_pause_button)

	_pause_dim = Control.new()
	_pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_dim.visible = false
	_pause_dim.draw.connect(_draw_backdrop)
	add_child(_pause_dim)

	_flip_button = Control.new()
	_flip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip_button.size = FLIP_BUTTON_SIZE
	_flip_button.visible = false
	_flip_button.draw.connect(_draw_pause_btn.bind(_flip_button, "Flip Screen"))

	_message = _label(26, Vector2.ZERO)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	add_child(_flip_button)   # above the pause message
	_options_button = Control.new()
	_options_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_button.size = FLIP_BUTTON_SIZE
	_options_button.visible = false
	_options_button.draw.connect(_draw_pause_btn.bind(_options_button, "Options"))
	add_child(_options_button)
	_resume_button = Control.new()
	_resume_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_button.size = FLIP_BUTTON_SIZE
	_resume_button.visible = false
	_resume_button.draw.connect(_draw_pause_btn.bind(_resume_button, "Resume"))
	add_child(_resume_button)
	_pause_menu_button = Control.new()
	_pause_menu_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_menu_button.size = FLIP_BUTTON_SIZE
	_pause_menu_button.visible = false
	_pause_menu_button.draw.connect(_draw_pause_btn.bind(_pause_menu_button, "Main Menu"))
	add_child(_pause_menu_button)
	_pause_skip_button = Control.new()
	_pause_skip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_skip_button.size = FLIP_BUTTON_SIZE
	_pause_skip_button.visible = false
	_pause_skip_button.draw.connect(_draw_pause_btn.bind(_pause_skip_button, "Skip Tutorial"))
	add_child(_pause_skip_button)
	# The tutorial's own "Skip Tutorial", bottom right.
	_skip_button = Control.new()
	_skip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_button.size = SKIP_BUTTON_SIZE
	_skip_button.visible = false
	_skip_button.draw.connect(_draw_skip_button)
	add_child(_skip_button)
	_menu_button = Control.new()
	_menu_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_button.size = FLIP_BUTTON_SIZE
	_menu_button.visible = false
	_menu_button.draw.connect(_draw_menu_button)
	add_child(_menu_button)
	_retry_button = Control.new()
	_retry_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retry_button.size = FLIP_BUTTON_SIZE
	_retry_button.visible = false
	_retry_button.draw.connect(func() -> void: _draw_menu_style_button(_retry_button, "New Run", true, _over_sel == 0))
	add_child(_retry_button)
	# The game-over screen's "Options" (between New Run and Main Menu, as on
	# the pause screen).
	_over_options_button = Control.new()
	_over_options_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_options_button.size = FLIP_BUTTON_SIZE
	_over_options_button.visible = false
	_over_options_button.draw.connect(func() -> void: _draw_menu_style_button(_over_options_button, "Options", false, not is_touch() and _over_sel == 1))
	add_child(_over_options_button)

	auto_overlay = AutoOverlay.new()
	add_child(auto_overlay)
	menu = MainMenu.new()
	add_child(menu)
	options = OptionsMenu.new()
	add_child(options)
	options.closed.connect(_on_options_closed)   # over everything but the "turn your phone" screen

	# The "turn your phone" screen, in the title screen's look: its dark
	# background, the heading in her red with a glow, a red frog croaking
	# (with a red glow behind it) beside it. Drawn in _draw_rotate.
	_rotate = _rect(Color(0, 0, 0, 0))
	_rotate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Shown only on a phone held sideways, from the very first frame (a new
	# scene, as on a new run, would otherwise draw it for a frame before
	# _process hides it).
	_rotate.visible = needs_portrait()
	_rotate.draw.connect(_draw_rotate)
	# The game's font has no ツ: it falls back to a tiny one that does.
	_rotate_font = FontVariation.new()
	_rotate_font.base_font = preload("res://assets/fonts/RussoOne-Regular.ttf")
	_rotate_font.fallbacks = [preload("res://assets/fonts/NotoSansJP-shrug.ttf")]
	# A red frog beside the message, facing south-east, croaking now and then
	# (assets/sprites/frog_croak_red.png: four 32 px frames).
	_rotate_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8.0)
	var croak := preload("res://assets/sprites/frog_croak_red.png")
	for i in [0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 2, 3, 3, 2, 1]:   # (a rest, then the croak)
		var tex := AtlasTexture.new()
		tex.atlas = croak
		tex.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("default", tex)
	_rotate_sprite.sprite_frames = frames
	_rotate_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rotate_sprite.scale = Vector2(8, 8)
	_rotate_sprite.offset = Vector2(0.5, -9)   # (the frog's pixels centre at (15.5, 25) in its 32 px frames: put that on the glow's centre)
	_rotate_sprite.play()
	_rotate.add_child(_rotate_sprite)


func _process(delta: float) -> void:
	if _coach.visible and not get_tree().paused:
		_coach_t += delta
		_coach_shake = maxf(_coach_shake - delta, 0.0)
		_coach.queue_redraw()
		# What it's about, in the top bar, pops again and again.
		_coach_beat -= delta
		if _coach_beat <= 0.0 and not _coach_points.is_empty():
			_coach_beat = COACH_BEAT
			for what in _coach_points:
				match what:
					"katana": _top.pulse()
					"bolt": _top._charge_pop = 1.0
					"streak": _top._pop = 1.0
	_skip_button.position = Vector2(get_viewport().get_visible_rect().size.x - SKIP_BUTTON_SIZE.x - 16.0, get_viewport().get_visible_rect().size.y - SKIP_BUTTON_SIZE.y - 14.0)
	if _skip_pulse > 0.0 and not get_tree().paused:
		_skip_pulse = maxf(_skip_pulse - delta, 0.0)
		_skip_button.pivot_offset = SKIP_BUTTON_SIZE   # (it grows out of its corner, staying on screen)
		_skip_button.scale = Vector2.ONE * (1.0 + 0.15 * _skip_glow())
		_skip_button.queue_redraw()
	if _tut.visible and not get_tree().paused:
		for k in _tut_lit:
			_tut_lit[k] += delta
		for k in _tut_bump:
			_tut_bump[k] += delta
		if _tut_fizzle >= 0.0:
			_tut_fizzle += delta
			if _tut_fizzle >= TUT_FIZZLE_TIME:
				_tut.visible = false
		_tut.queue_redraw()
	rotated = OS.has_feature("web") and int(JavaScriptBridge.eval("window.redFlashRotated === true ? 1 : 0", true)) == 1
	_rotate.visible = needs_portrait()
	var view := get_viewport().get_visible_rect().size
	if _rotate.visible:
		_rotate_sprite.position = Vector2(view.x * 0.2, view.y * 0.5)
		_rotate.queue_redraw()
	var right := view.x
	_chain.position = Vector2(right - 220, 6)
	_chain_bar_bg.position = Vector2(right - 200, 54)
	_chain_bar.position = _chain_bar_bg.position
	_pause_button.position = Vector2(right - PAUSE_BUTTON_SIZE - PAUSE_BUTTON_MARGIN, PAUSE_BUTTON_MARGIN)
	# The pause screen's buttons: a column under "PAUSED", in the band.
	var shown := pause_buttons()
	var gap := 14.0
	var col := shown.size() * FLIP_BUTTON_SIZE.y + maxf(shown.size() - 1, 0) * gap
	var bx := (view.x - FLIP_BUTTON_SIZE.x) / 2.0
	if _backdrop_mode == "over":
		var n := 2.0 if is_touch() else 3.0   # (Options and Main Menu; New Run too on a computer)
		var buttons_h := FLIP_BUTTON_SIZE.y * n + gap * (n - 1.0)
		var h := OVER_TITLE_H + OVER_STATS_H + (OVER_HINT_H if is_touch() else 24.0) + buttons_h
		_band = Rect2(0, (view.y - h) / 2.0 - BAND_PAD, view.x, h + BAND_PAD * 2.0)
		_menu_button.position = Vector2(bx, _band.end.y - BAND_PAD - FLIP_BUTTON_SIZE.y)
		_over_options_button.position = _menu_button.position - Vector2(0, FLIP_BUTTON_SIZE.y + gap)
		_retry_button.position = _over_options_button.position - Vector2(0, FLIP_BUTTON_SIZE.y + gap)
		if _pause_dim.visible:
			_over_t += delta
			_pause_dim.queue_redraw()
			_menu_button.modulate.a = _over_fade()
			_retry_button.modulate.a = _over_fade()
			_over_options_button.modulate.a = _over_fade()
	else:
		_band = Rect2(0, (view.y - PAUSE_TITLE_H - col) / 2.0 - BAND_PAD, view.x, PAUSE_TITLE_H + col + BAND_PAD * 2.0)
		var y := _band.position.y + BAND_PAD + PAUSE_TITLE_H
		for b in shown:
			b.position = Vector2(bx, y)
			y += FLIP_BUTTON_SIZE.y + gap
		if _pause_dim.visible:
			_pause_dim.queue_redraw()   # (the band follows the buttons shown)


## True on a touch device (phone, tablet): instructions say "Tap"; else they
## name keys. (Checked once.)
## True while the game is shown turned (a phone held upright): the screens
## then offer "Flip Screen". Updated every frame (see _process).
static var rotated := false


## Turns the game 180 degrees (upright phones; remembered by the page).
static func flip_screen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.redFlashSetFlip(!window.redFlashFlip)", true)


static var _touch := -1
static func is_touch() -> bool:
	if _touch < 0:
		if OS.has_feature("web"):
			_touch = int(JavaScriptBridge.eval("(('ontouchstart' in window) || navigator.maxTouchPoints > 0) ? 1 : 0", true))
		else:
			_touch = 1 if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() else 0
	return _touch == 1


## Opens the Options screen. over_game: from the pause screen, see-through
## (the game shows behind it, so a colour can be seen as it's picked; the
## pause screen's own text and buttons step aside while it's open).
func open_options(over_game: bool) -> void:
	options.see_through = over_game
	if _on_over_screen:
		# From the game-over screen: it steps aside while Options is open.
		options.see_through = true
		for b in [_pause_dim, _retry_button, _over_options_button, _menu_button]:
			b.visible = false
	elif over_game:
		_message.visible = false
		_pause_dim.visible = false
		_flip_button.visible = false
		_options_button.visible = false
		_pause_menu_button.visible = false
		_pause_skip_button.visible = false
		_resume_button.visible = false
	options.open()


func _on_options_closed() -> void:
	if _on_over_screen:
		_pause_dim.visible = true
		_retry_button.visible = not is_touch()
		_over_options_button.visible = true
		_menu_button.visible = true
		_redraw_over_buttons()
	elif _on_pause_screen:
		show_paused(true, _pause_can_flip)


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
	# The bolt and the streak out toward the edges; the level and the katana
	# centred between them.
	# The level and the katana a little left of centre (room for the streak);
	# the bolt halfway between the screen's left edge and the level; the
	# streak toward the right edge.
	var streak_left := view.x - 190.0
	var ext := _top.extent()
	_top.position = Vector2(view.x / 2.0 - 22.0 - (ext.x + ext.y) / 2.0, maxf(ceiling_y * 0.5, 34.0) - TopBar.BLADE.y / 2.0)
	var level_left := _top.position.x + ext.x
	_top.bolt_x = level_left / 2.0 - TopBar.BOLT_SIZE.x / 2.0 - _top.position.x
	_top.streak_x = streak_left - _top.position.x


## The power-up meter: value out of full; charged = full and ready.
## The power-up's auto-chain playing: lightning crackles over the katana.
func set_auto(on: bool) -> void:
	_top.auto_on = on


## boosted: golden (her PERFECT chains charge double).
func set_charge(value: int, full: int, charged: bool, boosted := false) -> void:
	_top.set_charge(value, full, charged, boosted)


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
		lines += "Level Reached  %d\n" % stats["level"]
		lines += "Peak Flawless Streak  %d\n" % stats["best_sweep"]
	if SHOW_SCORE_UI:
		lines += "Kills  %d      Best chain  x%d\n\n" % [stats["kills"], stats["best_chain"]]
		lines += "Score  %d\n" % stats["score"]
		lines += ("NEW BEST!\n" if stats["new_best"] else "Best  %d\n" % stats["best"])
	lines += "\n"
	lines += "Tap Anywhere To Retry" if is_touch() else "Press Any Key To Retry"
	_menu_button.visible = true
	if SHOW_SCORE_UI or SHOW_DISTANCE_UI:   # (the old text screen)
		_message.text = lines
		_message.visible = true
		return
	_over_stats = [[stats["kills"], "KILLS"], [stats["level"], "LEVEL"], [stats["best_sweep"], "PEAK FLAWLESS"]]
	# A run that didn't start at level 1 says where it did, under its level.
	var start: int = stats.get("start_level", 1)
	_over_start_note = "Started At %d" % start if start > 1 else ""
	_over_hint = "Tap Anywhere To Retry" if is_touch() else ""
	_over_sel = 0
	_retry_button.visible = not is_touch()
	_over_options_button.visible = true
	_on_over_screen = true
	_redraw_over_buttons()
	_backdrop_mode = "over"
	_over_t = 0.0
	_pause_dim.visible = true
	_pause_dim.queue_redraw()


func menu_button_contains(pos: Vector2) -> bool:
	return _menu_button.visible and not options.visible and _menu_button.get_rect().has_point(pos)


func _draw_menu_button() -> void:
	_draw_menu_style_button(_menu_button, "Main Menu", false, not is_touch() and _retry_button.visible and _over_sel == 2)


## The game-over screen's buttons (computer): Up/Down.
func over_move(dir: int) -> void:
	_over_sel = posmod(_over_sel + dir, 3)
	_redraw_over_buttons()


## What the picked game-over button does: "retry", "options" or "menu".
func over_selected() -> String:
	return ["retry", "options", "menu"][clampi(_over_sel, 0, 2)]


## The game-over button under a click, or "".
func over_button_at(pos: Vector2) -> String:
	if _retry_button.visible and _retry_button.get_rect().has_point(pos):
		return "retry"
	if over_options_button_contains(pos):
		return "options"
	if menu_button_contains(pos):
		return "menu"
	return ""


func over_options_button_contains(pos: Vector2) -> bool:
	return _over_options_button.visible and not options.visible and _over_options_button.get_rect().has_point(pos)


func _redraw_over_buttons() -> void:
	_retry_button.queue_redraw()
	_over_options_button.queue_redraw()
	_menu_button.queue_redraw()


## A button as the title screen draws them; `primary` = red (as its PLAY).
func _draw_menu_style_button(b: Control, text: String, primary: bool, picked: bool) -> void:
	var r := Rect2(Vector2.ZERO, FLIP_BUTTON_SIZE)
	var fill := Color(MainMenu.TITLE_RED, 0.3) if primary else Color(1, 1, 1, 0.07)
	if picked:
		fill = Color(fill, fill.a + 0.12)
	b.draw_rect(r, Color(0.04, 0.03, 0.04, 0.6))   # (so the game doesn't show through the text)
	b.draw_rect(r, fill)
	var border := Color(1, 0.45, 0.5, 0.95) if primary else Color(1, 1, 1, 0.55)
	b.draw_rect(r, Color.WHITE if picked else border, false, 2.0)
	var font := ThemeDB.fallback_font
	var size := 30 if primary else MainMenu.LABEL_SIZE
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	b.draw_string(font, Vector2((r.size.x - w) / 2.0, r.size.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _over_fade() -> float:
	return clampf(_over_t / 0.35, 0.0, 1.0)


func _draw_backdrop() -> void:
	var c := _pause_dim
	var view := c.size
	var a := _over_fade() if _backdrop_mode == "over" else 1.0
	c.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.3 * a))
	# The band, its top and bottom edges soft.
	var soft := 18.0
	var dark := Color(0.03, 0.02, 0.03, 0.72 * a)
	var clear := Color(dark, 0.0)
	c.draw_rect(_band, dark)
	var t := _band.position.y
	var bt := _band.end.y
	c.draw_polygon(PackedVector2Array([Vector2(0, t - soft), Vector2(view.x, t - soft), Vector2(view.x, t), Vector2(0, t)]), PackedColorArray([clear, clear, dark, dark]))
	c.draw_polygon(PackedVector2Array([Vector2(0, bt), Vector2(view.x, bt), Vector2(view.x, bt + soft), Vector2(0, bt + soft)]), PackedColorArray([dark, dark, clear, clear]))
	var top := t + BAND_PAD
	if _backdrop_mode == "pause":
		_draw_glow_title(c, "PAUSED", 60, top + 62.0, view.x, a)
		return
	_draw_glow_title(c, "GAME OVER", 66, top + 64.0, view.x, a)
	# The stats: small labels over big numbers, side by side.
	var font := ThemeDB.fallback_font
	var col_w := 210.0
	var x0 := (view.x - col_w * _over_stats.size()) / 2.0
	var sy := top + OVER_TITLE_H
	for i in _over_stats.size():
		var cx := x0 + col_w * (i + 0.5)
		var value := str(_over_stats[i][0])
		var label: String = _over_stats[i][1]
		var vw := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		c.draw_string(font, Vector2(cx - lw / 2.0, sy + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55 * a))   # (the label over its number)
		c.draw_string(font, Vector2(cx - vw / 2.0, sy + 72.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1, 1, 1, a))
		if label == "LEVEL" and _over_start_note != "":
			var nw := font.get_string_size(_over_start_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			c.draw_string(font, Vector2(cx - nw / 2.0, sy + 94.0), _over_start_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MainMenu.TITLE_RED.lightened(0.25), 0.9 * a))
		if i > 0:   # thin dividers between them
			var dx := x0 + col_w * i
			c.draw_line(Vector2(dx, sy + 10.0), Vector2(dx, sy + 78.0), Color(1, 1, 1, 0.15 * a), 1.0)
	if _over_hint == "":
		return
	# "Tap anywhere to retry": big, in the title's red, glowing and
	# breathing, so it reads as what to do (not the buttons under it).
	var beat := 0.5 + 0.5 * sin(_over_t * OVER_HINT_PULSE)
	var hs := int(OVER_HINT_SIZE * (1.0 + 0.06 * beat))
	var hy := sy + OVER_STATS_H + 34.0
	var hw := font.get_string_size(_over_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
	var hpos := Vector2((view.x - hw) / 2.0, hy)
	var red := MainMenu.TITLE_TEXT_RED
	for j in 12:   # a glow, as the title's
		c.draw_string(font, hpos + Vector2.RIGHT.rotated(j * TAU / 12.0) * 5.0, _over_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(red, (0.05 + 0.07 * beat) * a))
	c.draw_string(font, hpos, _over_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(red.lerp(Color.WHITE, 0.25 * beat), a))


## A title in the title screen's red, with its soft glow.
func _draw_glow_title(c: Control, text: String, size: int, baseline: float, width: float, a: float) -> void:
	var font: Font = menu.title_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2((width - w) / 2.0, baseline)
	for i in 12:
		var o := Vector2.RIGHT.rotated(i * TAU / 12.0) * 5.0
		c.draw_string(font, base + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(MainMenu.TITLE_RED, 0.07 * a))
	c.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(MainMenu.TITLE_RED, a))
	c.draw_string(font, base + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.65, 0.68, 0.3 * a))


func set_pause_button_visible(value: bool) -> void:
	_pause_button.visible = value


## The drawn button: a tap has to land on it.
func pause_button_contains(pos: Vector2) -> bool:
	return _pause_button.visible and _pause_button.get_rect().has_point(pos)


## can_flip: show the "Flip screen" button (upright phones only).
func show_paused(paused: bool, can_flip: bool = false) -> void:
	_backdrop_mode = "pause"
	_pause_dim.visible = paused
	_pause_dim.queue_redraw()
	_pause_button.visible = not paused
	_flip_button.visible = paused and can_flip
	_pause_can_flip = can_flip
	_options_button.visible = paused
	_pause_menu_button.visible = paused
	_pause_skip_button.visible = false   # (Skip Tutorial is only on screen, not on the pause screen)
	_coach.modulate.a = 0.0 if paused else 1.0   # (the lesson's words wait behind the pause screen)
	_skip_button.visible = _skip_on and not paused
	_resume_button.visible = paused
	if paused:
		if not _on_pause_screen:   # (not again on coming back from Options)
			_message_before_pause = _message.text
			_message_visible_before_pause = _message.visible
			_pause_sel = 0   # Resume
		_message.visible = false
	else:
		_message.text = _message_before_pause
		_message.visible = _message_visible_before_pause
	_on_pause_screen = paused
	_redraw_pause_buttons()


## The pause screen's buttons, top to bottom (those showing).
func pause_buttons() -> Array[Control]:
	var out: Array[Control] = []
	for b in [_resume_button, _options_button, _flip_button, _pause_skip_button, _pause_menu_button]:
		if b.visible and _on_pause_screen:
			out.append(b)
	return out


## Up/Down on the pause screen.
func pause_move(dir: int) -> void:
	var n := pause_buttons().size()
	if n > 0:
		_pause_sel = posmod(_pause_sel + dir, n)
	_redraw_pause_buttons()


## What the picked pause button does: "resume", "options", "flip" or "menu".
func pause_selected() -> String:
	var b := pause_buttons()
	if b.is_empty():
		return "resume"
	return _pause_id(b[clampi(_pause_sel, 0, b.size() - 1)])


## The pause button at a tap, or "".
func pause_button_at(pos: Vector2) -> String:
	if options.visible:
		return ""
	for b in pause_buttons():
		if b.get_rect().has_point(pos):
			return _pause_id(b)
	return ""


func _pause_id(b: Control) -> String:
	if b == _options_button: return "options"
	if b == _flip_button: return "flip"
	if b == _pause_menu_button: return "menu"
	if b == _pause_skip_button: return "skip"
	return "resume"


func _redraw_pause_buttons() -> void:
	for b in [_resume_button, _options_button, _flip_button, _pause_skip_button, _pause_menu_button]:
		b.queue_redraw()


func _draw_pause_btn(b: Control, text: String) -> void:
	var list := pause_buttons()
	# The keyboard's pick is lit (not on touch screens: there you just tap).
	var picked := not is_touch() and list.find(b) == clampi(_pause_sel, 0, list.size() - 1)
	_draw_menu_style_button(b, text, b == _resume_button, picked)


func options_button_contains(pos: Vector2) -> bool:
	return _options_button.visible and not options.visible and _options_button.get_rect().has_point(pos)


func pause_menu_button_contains(pos: Vector2) -> bool:
	return _pause_menu_button.visible and not options.visible and _pause_menu_button.get_rect().has_point(pos)


func flip_button_contains(pos: Vector2) -> bool:
	return _flip_button.visible and _flip_button.get_rect().has_point(pos)


func _draw_pause_button() -> void:
	var s := PAUSE_BUTTON_SIZE
	_pause_button.draw_rect(Rect2(0, 0, s, s), Color(0, 0, 0, 0.35))
	_pause_button.draw_rect(Rect2(0, 0, s, s), Color(1, 1, 1, 0.5), false, 2.0)
	var bar := Vector2(s * 0.14, s * 0.5)
	_pause_button.draw_rect(Rect2(Vector2(s * 0.3, s * 0.25), bar), Color(1, 1, 1, 0.85))
	_pause_button.draw_rect(Rect2(Vector2(s * 0.56, s * 0.25), bar), Color(1, 1, 1, 0.85))


func hide_message() -> void:
	_message.visible = false
	_retry_button.visible = false
	if _backdrop_mode == "over":
		_pause_dim.visible = false
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


## The "turn your phone" screen (phones held sideways).
func _draw_rotate() -> void:
	if not needs_portrait():
		return   # (never anywhere but a phone held sideways)
	var c := _rotate
	var v := c.size
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), v, Vector2(0, v.y)]),
			PackedColorArray([MainMenu.BG_TOP, MainMenu.BG_TOP, MainMenu.BG_BOTTOM, MainMenu.BG_BOTTOM]))
	# A soft red glow behind the frog, breathing.
	var t := Time.get_ticks_msec() / 1000.0
	var centre := Vector2(v.x * 0.2, v.y * 0.5)
	for i in 10:
		var k := 1.0 - i / 10.0
		c.draw_circle(centre, 40.0 + 150.0 * k, Color(MainMenu.TITLE_RED, (0.035 + 0.01 * sin(t * 2.6)) * (1.0 - k * 0.5)))
	# The words, centred in the space right of her.
	var left := v.x * 0.38
	var w := v.x * 0.58
	var font: Font = menu.title_font
	var hs := 56
	while hs > 24 and font.get_string_size(PORTRAIT_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x > w:
		hs -= 2
	var y := v.y * 0.5 - 30.0
	var hw := font.get_string_size(PORTRAIT_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
	var base := Vector2(left + (w - hw) / 2.0, y)
	for i in 12:
		c.draw_string(font, base + Vector2.RIGHT.rotated(i * TAU / 12.0) * 5.0, PORTRAIT_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(MainMenu.TITLE_TEXT_RED, 0.07))
	c.draw_string(font, base, PORTRAIT_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, MainMenu.TITLE_TEXT_RED)
	var bs := 24
	while bs > 14 and _rotate_font.get_string_size(PORTRAIT_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x > w:
		bs -= 1
	var lw := _rotate_font.get_string_size(PORTRAIT_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
	c.draw_string(_rotate_font, Vector2(left + (w - lw) / 2.0, y + 50.0), PORTRAIT_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color.WHITE)
	var ns := maxi(bs - 4, 12)
	var nw := _rotate_font.get_string_size(PORTRAIT_NOTE, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
	c.draw_string(_rotate_font, Vector2(left + (w - nw) / 2.0, y + 88.0), PORTRAIT_NOTE, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(1, 1, 1, 0.5))


# --- the tutorial's lessons (main.gd): a heading and a line, centred ---------
# above the play, and arrows up to the katana or the power-up bolt.

var _coach: Control
var _coach_title := ""
var _coach_line := ""
var _coach_points: Array = []   # "katana", "bolt"
var coach_dim := true   # the spotlight dims around what it's about (false: just the glowing boxes)
var _coach_t := 0.0
var _coach_shake := 0.0
var _coach_beat := 0.0
const COACH_BEAT := 0.55   # seconds between the pops of what it's about
const COACH_SHAKE_TIME := 0.3


## `line`: the move to make (in her red), or "". `points`: what in the top
## bar it's about ("katana", "bolt", "streak"): that pops, over and over.
func show_coach(title: String, line := "", points: Array = []) -> void:
	if title != _coach_title or line != _coach_line:
		_coach_t = 0.0
	_coach_title = title
	_coach_line = line
	_coach_points = points
	_coach.visible = true
	_coach.queue_redraw()


func hide_coach() -> void:
	_coach.visible = false


func set_level_quietly(lv: int) -> void:
	_top.set_level_quietly(lv)


## "Skip Tutorial" pulses (grows and glows red) for `seconds`, to be seen.
var _skip_pulse := 0.0
const SKIP_PULSE_RATE := 6.0   # radians per second of the pulse

func pulse_skip(seconds: float) -> void:
	_skip_pulse = seconds


func set_skip_visible(on: bool) -> void:
	_skip_on = on
	_skip_button.visible = on and not get_tree().paused


func skip_button_contains(pos: Vector2) -> bool:
	return _skip_button.visible and _skip_button.get_rect().has_point(pos)


## 0..1: how lit the skip button's pulse is right now (0 when not pulsing).
func _skip_glow() -> float:
	if _skip_pulse <= 0.0:
		return 0.0
	var fade := minf(_skip_pulse / 0.4, 1.0)   # (eases out at the end)
	return fade * (0.5 - 0.5 * cos(_skip_pulse * SKIP_PULSE_RATE))


func _draw_skip_button() -> void:
	var r := Rect2(Vector2.ZERO, SKIP_BUTTON_SIZE)
	var glow := _skip_glow()
	var red := MainMenu.TITLE_TEXT_RED
	_skip_button.draw_rect(r, Color(0.04, 0.03, 0.04, 0.6).lerp(Color(red, 0.95), glow))
	for k in 3:   # a red glow round it while it pulses
		_skip_button.draw_rect(r.grow(2.0 + k * 3.0), Color(red, (0.7 - k * 0.2) * glow), false, 3.0)
	_skip_button.draw_rect(r, Color(1, 1, 1, 0.5 + 0.5 * glow), false, 2.0)
	var font := ThemeDB.fallback_font
	var size := 20
	var text := "Skip Tutorial"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_skip_button.draw_string(font, Vector2((r.size.x - w) / 2.0, r.size.y / 2.0 + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.85))


## The wrong move: the words shake.
func coach_shake() -> void:
	_coach_shake = COACH_SHAKE_TIME


## The screen dims around what the words are about (the katana, the bolt,
## the flawless number), each lit in a softly glowing box.
func _draw_spotlight(c: Control, v: Vector2) -> void:
	var holes: Array[Rect2] = []
	var mid := TopBar.BLADE.y / 2.0
	for what in _coach_points:
		var r := Rect2()
		if what is Rect2:   # (a spot in the play: main.gd works out where)
			r = what
		match what:
			"katana":
				var ext := _top.extent()
				r = Rect2(_top.position + Vector2(ext.x, mid - 22.0), Vector2(ext.y - ext.x, 44.0))
			"bolt":
				r = Rect2(_top.position + _top._bolt_origin(), TopBar.BOLT_SIZE)
			"streak":
				r = Rect2(_top.position + Vector2(_top.streak_x - 6.0, mid - 26.0), Vector2(84.0, 56.0))
		holes.append(r.grow(12.0))
	# The dark, in strips around the holes.
	var dark := Color(0, 0, 0, (0.62 if coach_dim else 0.0) * minf(_coach_t / 0.3, 1.0))
	var ys: Array[float] = [0.0, v.y]
	for h in holes:
		ys.append(clampf(h.position.y, 0.0, v.y))
		ys.append(clampf(h.end.y, 0.0, v.y))
	ys.sort()
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		if y1 - y0 < 0.5:
			continue
		var spans: Array = []   # the holes' x spans in this strip
		for h in holes:
			if h.position.y <= y0 and h.end.y >= y1:
				spans.append(Vector2(h.position.x, h.end.x))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var x := 0.0
		for sp in spans:
			if sp.x > x:
				c.draw_rect(Rect2(x, y0, sp.x - x, y1 - y0), dark)
			x = maxf(x, sp.y)
		if x < v.x:
			c.draw_rect(Rect2(x, y0, v.x - x, y1 - y0), dark)
	# A soft glowing edge round each.
	var pulse := 0.55 + 0.45 * sin(_coach_t * 5.0)
	for h in holes:
		for k in 3:
			c.draw_rect(h.grow(k * 3.0), Color(1, 1, 1, (0.35 - k * 0.1) * pulse), false, 2.0)


func _draw_coach() -> void:
	var c := _coach
	var v := c.size
	var font := ThemeDB.fallback_font
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - _coach_t / 0.2)   # a pop as it appears
	var shake := Vector2(sin(_coach_shake * 90.0) * 12.0 * (_coach_shake / COACH_SHAKE_TIME), 0.0)
	# Under the floor (the play stays clear); with arrows, just under the top
	# bar (nothing else is on screen then).
	var cy := v.y * 0.86
	if not _coach_points.is_empty():
		_draw_spotlight(c, v)
	var title_size := int(34 * pop)
	var tw := font.get_string_size(_coach_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var tpos := Vector2((v.x - tw) / 2.0, cy) + shake
	# A dark band behind it, so it reads over the game.
	var band_h := 104.0 if _coach_line != "" else 60.0
	var band_y := cy - 46.0
	var big := _coach_title == "" and _coach_line != ""   # (just the red word, big: "Start!")
	if big:
		band_h = 96.0
		band_y = cy - 62.0
	c.draw_rect(Rect2(0, band_y, v.x, band_h), Color(0.03, 0.02, 0.03, 0.55))
	c.draw_string(font, tpos, _coach_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)
	if _coach_line != "":
		var red := MainMenu.TITLE_TEXT_RED
		if _coach_shake > 0.0:
			red = Color(1, 0.25, 0.25)
		var ls := int((72 if big else 30) * pop)
		var lw := font.get_string_size(_coach_line, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
		var lpos := Vector2((v.x - lw) / 2.0, (cy + 10.0) if big else (cy + 44.0)) + shake
		for j in 12:   # a glow, as the title screen's
			c.draw_string(font, lpos + Vector2.RIGHT.rotated(j * TAU / 12.0) * 5.0, _coach_line, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Color(red, 0.08))
		c.draw_string(font, lpos, _coach_line, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, red)


# --- the first-time tutorial --------------------------------------------------

var _tut_count := {}   # key -> times done so far (shown "1/3")
var _tut_bump := {}    # key -> seconds since its count went up (a small pop)
var tutorial_reps := 3

func show_tutorial(on_floor: bool) -> void:
	tutorial_on_floor = on_floor
	_tut_lit.clear()
	_tut_count.clear()
	_tut_bump.clear()
	_tut_fizzle = -1.0
	_tut_rng.randomize()
	_tut.visible = true


func tutorial_done(key: String) -> void:
	_tut_lit[key] = 0.0


## One more of a move: its count goes up (and it lights once it's done enough).
func tutorial_count(key: String, n: int) -> void:
	_tut_count[key] = n
	_tut_bump[key] = 0.0
	if n >= tutorial_reps:
		_tut_lit[key] = 0.0


func finish_tutorial() -> void:
	_tut_fizzle = 0.0


func _draw_tutorial() -> void:
	var c := _tut
	var v := c.size
	var font := ThemeDB.fallback_font
	var touch := is_touch()
	var up := tutorial_on_floor
	var prompts := [
		["left", "Tap Left" if touch else "Left", Vector2(0, -1) if up else Vector2(0, 1)],
		["right", "Tap Right" if touch else "Right", Vector2(1, 0)],
		["both", "Tap Both" if touch else "Both", (Vector2(1, -1) if up else Vector2(1, 1)).normalized()],
	]
	for p in prompts:   # how many of each so far
		p[1] += "  %d/%d" % [mini(int(_tut_count.get(p[0], 0)), tutorial_reps), tutorial_reps]
	const SIZE := 34
	const LINE := 58.0
	const ARROW := 30.0   # the arrow's box (it's drawn in this square, left of the words)
	const GAP := 18.0
	var widest := 0.0
	for p in prompts:
		widest = maxf(widest, font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x)
	# The block, centred on the right side (where "Tap Right" was), its lines centred on the middle.
	var left := v.x * 0.8 - (ARROW + GAP + widest) / 2.0
	var top := v.y * 0.5 - LINE
	var fade := 1.0
	var drift := 0.0
	if _tut_fizzle >= 0.0:
		var k := clampf(_tut_fizzle / TUT_FIZZLE_TIME, 0.0, 1.0)
		fade = (1.0 - k) * (0.55 + 0.45 * _tut_rng.randf())   # flickering out
		drift = 30.0 * _tut_fizzle   # drifting up
	for i in prompts.size():
		var p: Array = prompts[i]
		var key: String = p[0]
		var text: String = p[1]
		var dir: Vector2 = p[2]
		var lit := _tut_lit.has(key)
		var t: float = _tut_lit.get(key, 0.0)
		var pop := 1.0 + 0.3 * maxf(0.0, 1.0 - t / 0.25) if lit else 1.0   # a pop as it lights
		if not lit and _tut_bump.has(key):   # (a smaller one as its count goes up)
			pop = 1.0 + 0.15 * maxf(0.0, 1.0 - float(_tut_bump[key]) / 0.2)
		var size := int(SIZE * pop)
		var cy := top + i * LINE - drift
		var col := Color(MainMenu.TITLE_TEXT_RED, fade) if lit else Color(1, 1, 1, 0.3 * fade)
		# The arrow.
		var centre := Vector2(left + ARROW / 2.0, cy)
		var half := dir * ARROW * 0.5 * pop
		var a := centre - half
		var b := centre + half
		var w := 4.0
		if lit:
			c.draw_line(a, b, Color(col, 0.25 * fade), w * 3.0, true)   # a glow
		c.draw_line(a, b, col, w, true)
		var head := 11.0 * pop
		c.draw_colored_polygon(PackedVector2Array([b + dir * 2.0, b - dir * head + dir.orthogonal() * head * 0.7, b - dir * head - dir.orthogonal() * head * 0.7]), col)
		# The words.
		var pos := Vector2(left + ARROW + GAP, cy + size * 0.35)
		if lit:
			for j in 12:   # a glow, as the title's
				c.draw_string(font, pos + Vector2.RIGHT.rotated(j * TAU / 12.0) * 5.0, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(MainMenu.TITLE_TEXT_RED, 0.08 * fade))
		c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		if lit and _tut_fizzle >= 0.0:   # sparks off it as it goes
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			for n in 3:
				var s0 := pos + Vector2(_tut_rng.randf() * tw, -_tut_rng.randf() * size)
				var pts := PackedVector2Array([s0])
				for m in 3:
					pts.append(pts[-1] + Vector2(_tut_rng.randf_range(-10, 10), _tut_rng.randf_range(-14, -4)))
				c.draw_polyline(pts, Color(1, 0.4, 0.4, fade), 2.0)

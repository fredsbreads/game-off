extends Node2D
## Game flow, input, scoring and the per-frame rules.
##
## The per-frame order in _step() must match ChunkSolver.step(), so the
## pattern validator's "this chains" proof applies to the real game.
##
## Controls: forward (right half / Right, K, D, R-Shift), vertical (left
## half / Left, Up, J, A, W, L-Shift), diagonal = both at once.

enum State { READY, PLAYING, DYING, OVER }

const START_X := 3.0
# >>> The start screen's level chooser: true = shown (for testing), false =
# hidden and every run starts at level 1 (for playtesters). <<<
const LEVEL_CHOICE := true
# The levels it offers (5: straight to the knight's debut, 10: the ninja's);
# the pick is kept between visits.
const START_LEVELS := [1, 5, 10]
# Every kill gets a short hit freeze (invert flash).
const KILL_HIT := 0.06
# If another enemy is under any marker where you land, the
# freeze extends into a "your move" pause: grey world, lit markers, zoom.
# The camera keeps catching up during it, so the screen settles first.
const KILL_PAUSE := 0.7
# ...shrinking by this much per kill in the chain so far (resets with the
# chain), down to KILL_PAUSE_FLOOR.
const KILL_PAUSE_STEP := 0.01
const KILL_PAUSE_FLOOR := 0.4
# Pressing during the pause ends it (after this minimum, to keep the hit's
# impact) and the press becomes your next teleport.
const KILL_PAUSE_MIN := 0.05
# Pause visuals: inverted colours for a moment, then the world goes grey
# until play resumes. Kill effects play briefly, then hang mid-air.
const INVERT_FLASH := false     # inverted-colour flash on kills (off: too aggressive in long chains)
const INVERT_TIME := 0.05
const FX_FREEZE_AFTER := 0.08
const RESUME_GUARD := 0.15       # ignore presses this soon after pausing
# Pressing forward and vertical within this many frames of each other counts
# as a diagonal. Single presses wait this long before firing (4 frames = 67 ms).
const DIAGONAL_WINDOW_FRAMES := 4
# Phone browsers send a fake mouse click after a finger lifts; ignore mouse
# clicks this soon after any touch so a tap never counts twice.
const MOUSE_AFTER_TOUCH_IGNORE_MS := 1000
const DEATH_ANIM_TIME := 0.7
# The death moment (she only dies once, so it's big): a hard freeze on the
# slash, zoomed in, world grey, then a slow-motion release.
const DEATH_FREEZE := 0.9       # seconds everything holds still
const DEATH_SLOWMO := 1.8       # seconds of slow motion after the freeze
const DEATH_SLOW_SPEED := 0.03  # slow motion starts at this speed, eases back to 1
const DEATH_ZOOM_HOLD := 0.7    # seconds into the slow motion before the zoom starts easing out
const DEATH_ZOOM := 0.45        # 45 % closer during the freeze
const DEATH_FOCUS_X := 0.45     # ...with the clash moved to 45 % across the screen
const DEATH_ZOOM_OUT := -0.15   # then out to 15 % wider than normal, centred on it
const PRUNE_BEHIND_TILES := 12.0 # enemies/bodies are removed this far behind the screen
const DEATH_FLASH := Color(1, 1, 1, 0.4)
const DEATH_FLASH_TIME := 0.15
const DEATH_ZOOM_RATE := 7.0      # how fast the camera pushes in (lower = slower, smoother)
const DEATH_GREY_IN := 0.15       # seconds for the world to fade to grey
var _killer: Enemy = null
var _second_killer: Enemy = null   # two knights at once: the one behind her
var _death_focus := Vector2.ZERO
var _death_released := false
const RETRY_DELAY := 0.5
const SAVE_PATH := "user://save.cfg"

@onready var level: Level = $Level
@onready var player: Player = $PlayerLayer/Player
@onready var cam: CameraRig = $Camera
@onready var fx: Fx = $FX
# Blood gets its own effects node on the enemy layer, so it stays red during
# the grey "your move" freeze.
var blood_fx: Fx
var text_fx: Fx
var _kill_sound: AudioStreamPlayer
var _death_sound: AudioStreamPlayer
var _level_up_sound: AudioStreamPlayer
var _perfect_sound: AudioStreamPlayer
var _dropped_sound: AudioStreamPlayer
var _teleport_sound: AudioStreamPlayer
var _clash_sound: AudioStreamPlayer
var _knight_kill_sound: AudioStreamPlayer   # the sword impact when a knight goes down
var _pink_shift_sound: AudioStreamPlayer   # her colour sweeping from red to pink
var _lose_colour_sound: AudioStreamPlayer  # the streak breaks: back to red
var _charge_sound: AudioStreamPlayer       # the power-up meter is full
var _auto_finale_layer: AudioStreamPlayer
var _ninja_alert_sound: AudioStreamPlayer
var _auto_finale_sound: AudioStreamPlayer  # thunder at the end of an auto-chain
var _warn_sound: AudioStreamPlayer   # a knight winding up to strike
const KILL_STRIKE_FPS := 5.0         # the knight's teleport onto the player lingers (normal: 18)
const WARN_PEAK := 0.33              # seconds into it where the swish peaks
var _clashed := false                # this teleport hit a knight who blinked away
var _knight_felled := false          # this teleport finished a knight off
var _felled_knight: Knight = null
var _last_felled: Enemy = null   # the last enemy killed (the finisher plays on them)
# The streak finisher (see _finisher): her blinking back and forth across the
# enemy in each of her three strike poses, the last held as a freeze frame
# while she takes on her reward colour.
# Played slow, like the death moment: grey world, zoomed in, her lightning
# ring, slow lightning, blood hanging in the air.
const FINISHER_HOP := 0.6          # seconds between her strikes
const FINISHER_STRIKE_FPS := 6.0   # her blink lightning, slowed (normal: 18)
const FINISHER_STRIKE_FLASH := Color(1, 1, 1, 0.35)
# Each blink also brings a bolt straight down onto her spot (Fx.Bolt.BIG_STRIKE),
# slow enough that the last one is still up as she turns pink (and turns with her).
const FINISHER_BOLT_FPS := 4.5
const FINISHER_BOLT_SIZE := Vector2(1.2, 1.4)
const BIG_STRIKE_BURST_Y := 225.0   # pixels down its frame where the ground burst is
const BIG_STRIKE_FULL_FRAME := 2     # its frame with the whole bolt and the sparks
const FINISHER_SWEEP_AFTER := 0.3  # on the last pose, this long before the colour sweeps
const FINISHER_SWEEP_TIME := 1.1   # her new colour sweeps across the screen, right to left, over this long
const FINISHER_HOLD := 0.8         # after the level-up, the freeze frame holds this long
# Every finisher after the first in a run is the quick one: the same three
# slashes and colour change, at about the power-up finish's pace.
const FINISHER_QUICK_HOP := 0.2
const FINISHER_QUICK_BOLT_FPS := 12.0
const FINISHER_QUICK_AFTER := 0.1
const FINISHER_QUICK_SWEEP := 0.35
const FINISHER_QUICK_HOLD := 0.2
var _finished_before := false   # the whole finisher has played once this run
var _fin_hop := FINISHER_HOP
var _fin_strike_fps := FINISHER_STRIKE_FPS
var _fin_bolt_fps := FINISHER_BOLT_FPS
var _fin_after := FINISHER_SWEEP_AFTER
var _fin_sweep := FINISHER_SWEEP_TIME
var _fin_hold := FINISHER_HOLD
# The reward: a flawless streak (kills in a row, no enemy let go, no chain
# dropped) this long; the next chain that ends on a kill plays the finisher.
const STREAK_REWARD := 50
# The auto-chain power-up: a meter filled by finished chains (CLEAN 1,
# PERFECT 2, CHARGE_FULL to fill). Full = she's charged; her next kill that
# has a chain after it sets it off: the rest of that chain plays itself,
# perfectly and fast, then a lightning finale and a breather before the
# next chain.
const CHARGE_FULL := 10
const CHARGE_GAIN := {"PERFECT": 2, "CLEAN": 1}
const AUTO_STEP := 0.1          # seconds between her auto-chain hops
const AUTO_DUEL_STEP := 0.32    # ...after a clash or a knight's last hit: the duel gets its weight
const AUTO_GAP_TILES := 12.0    # extra empty run after an auto-chain
const AUTO_FINALE_FREEZE := 0.3  # (no last enemy to slash: the last kill holds this long, crackling, before the big strike)
const AUTO_FINALE_CRACKLE := 0.05 # ...a crackle of lightning on her this often while it holds
const NINJA_ALERT_PITCH := 1.35  # his alert: the knight's swish, higher and sharper
const AUTO_SLASH_HOP := 0.2      # the finish's three slashes (the streak finisher's, at full speed): seconds between them
const AUTO_SLASH_TO_BANG := 0.2  # ...and from the third to the big strike
const AUTO_FINALE_IMPACT := 0.14  # the big strike lands on a frozen, white-hot frame this long
const AUTO_FINALE_DUCK_DB := -22.0 # the music drops by this through the hold (silence before the bang)
const AUTO_FINALE_DB := 1.0       # the thunder (the loudest thing in the game)
const AUTO_FINALE_SHAKE := 14.0   # the bang's screen shake: strength (pixels)...
const AUTO_FINALE_SHAKE_TIME := 0.4 # ...and seconds
const AUTO_FINALE_ZOOM := 0.25   # how much closer that hold is (0.25 = 25 %)
var charge := 0                 # the meter (0..CHARGE_FULL)
var _charged := false           # full: the next chainable kill sets it off
var _auto := false              # an auto-chain is playing
var _finale_hold := false       # its last kill's freeze, before the big strike
var _finale_crackle := 0.0
var _finale_home_x := 0.0
var _finale_slashing := false   # the finish's three slashes are playing (no crackle)
var _auto_ending := false       # the auto-chain's own result is being counted (adds no charge)
const LOSE_COLOUR_TIME := 0.3     # back to red when the streak breaks
const FINISHER_ZOOM := 0.35
const FINISHER_SIDE := 2.2          # tiles either side of the enemy she strikes from
var _finishing := false
const CLASH_PAUSE_FACTOR := 1.5    # the freeze after a clash is this much longer
# A clash gets its moment: both hold still mid-swing for this long (a press
# can't skip it), with a zoom and a shake, before the knight blinks away.
const CLASH_BEAT := 0.12
const CLASH_REAPPEAR := 0.0  # the knight shows at her new spot this soon (the clash plays on behind)
const CLASH_ZOOM := 0.1   # how much closer the clash zooms at its peak (0.1 = 10 %)
const CLASH_FLASH := Color(1, 1, 1, 0.22)
var _pause_min := KILL_PAUSE_MIN
var _drop_pounce := false            # a chain just dropped: check for a knight across
var _cut_pending := false
var _pause_length := KILL_PAUSE   # this freeze's full length (for the marker fill)
# Kill blood starts this far (seconds) into its flight, so it's already
# spread out behind the enemy when the "your move" freeze holds it.
const BLOOD_BURST := 0.35
@onready var hud: Hud = $HUD
@onready var freeze_effect: FreezeEffect = $FreezeEffect

var state := State.READY
var distance := 0.0
var kills := 0
var kill_score := 0
var chain := 0                  # kills in the current chain (each hit on a knight counts)
var chain_points := 0           # what the chain is worth on the bar (knight hits count double)
# Sweep: kills in a row without letting a single enemy get away (one left
# behind alive, out of reach). The longest is on the game-over screen.
var sweep := 0
var best_sweep := 0
var best_chain := 0             # longest chain this run
var perfect_chains := 0         # PERFECT chains this run (on the game-over screen)
var progression := Progression.new()
var best_score := 0
var debug: DebugTools = null

var _pending_forward := false
var _pending_vertical := false
var _pending_frames := 0
# The buttons the last teleport used. Pressing one of them again during the
# cooldown that follows is ignored (a quick double press is spam, not intent).
var _last_forward := false
var _last_vertical := false
# Where she was when a pending press could first fire. A single press waits
# DIAGONAL_WINDOW_FRAMES in case it's a diagonal. While it waits she's
# committed: running into an enemy doesn't count. When it fires, it hits if
# it would have hit from anywhere between here and where she is now (so a
# marker lit at any point during the wait means a hit).
var _press_x := 0.0
var _press_x_set := false
var _last_touch_msec := -100000
# Which Shift keys are down, by location (see _shift_press_is_fresh).
var _shift_held := {}
var _hitstop := 0.0
var _pause_elapsed := 0.0
var _pause_is_chain := false    # true = the longer "your move" pause
# Chain tracking (see Progression for the rules):
var _chain_awaiting := false     # an enemy is under a marker: your move
var _pressed_during_pause := false
var _chain_killed: Array[int] = []   # instance ids killed in this chain
var _state_time := 0.0
var _paused_at_msec := 0


func _ready() -> void:
	# Main and the HUD keep running while the game is paused (to read the
	# resume press and show the pause screen); the world stops.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node in [level, fx, cam, freeze_effect, $EnemyLayer, $PlayerLayer]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_kill_sound = AudioStreamPlayer.new()
	_kill_sound.stream = preload("res://assets/sounds/saber_cut.ogg")
	_kill_sound.max_polyphony = 6   # chained kills overlap
	_kill_sound.volume_db = KILL_CUT_DB
	add_child(_kill_sound)
	_death_sound = AudioStreamPlayer.new()
	_death_sound.stream = preload("res://assets/sounds/death_slash.ogg")
	add_child(_death_sound)
	_level_up_sound = AudioStreamPlayer.new()
	_level_up_sound.stream = preload("res://assets/sounds/level_up.ogg")
	_level_up_sound.volume_db = -3.0   # same as PERFECT: it's that sound plus an impact
	add_child(_level_up_sound)
	_perfect_sound = AudioStreamPlayer.new()
	_perfect_sound.stream = preload("res://assets/sounds/perfect.ogg")
	_perfect_sound.volume_db = -3.0
	add_child(_perfect_sound)
	_dropped_sound = AudioStreamPlayer.new()
	_dropped_sound.stream = preload("res://assets/sounds/too_slow.ogg")
	_dropped_sound.volume_db = 0.0
	add_child(_dropped_sound)
	# One player, one voice: each move's strike cuts off the last one, so a
	# chain is a run of cracks rather than a wash.
	_teleport_sound = AudioStreamPlayer.new()
	add_child(_teleport_sound)
	_knight_kill_sound = AudioStreamPlayer.new()
	_knight_kill_sound.stream = preload("res://assets/sounds/knight_kill.ogg")
	_knight_kill_sound.volume_db = KILL_CUT_DB
	add_child(_knight_kill_sound)
	_charge_sound = AudioStreamPlayer.new()
	_charge_sound.stream = preload("res://assets/sounds/charge_ready.ogg")
	_charge_sound.volume_db = 2.0
	add_child(_charge_sound)
	_auto_finale_sound = AudioStreamPlayer.new()
	_auto_finale_sound.stream = preload("res://assets/sounds/auto_finale.ogg")
	_auto_finale_sound.volume_db = AUTO_FINALE_DB
	# A limiter on everything: the loudest moments (the power-up's bang) get
	# loud without distorting. (Added once: the bus outlives a retry.)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, limiter)
	_auto_finale_layer = AudioStreamPlayer.new()   # a heavy hit under the thunder
	_auto_finale_layer.stream = preload("res://assets/sounds/knight_kill.ogg")
	_auto_finale_layer.volume_db = 0.0
	add_child(_auto_finale_layer)
	add_child(_auto_finale_sound)
	_lose_colour_sound = AudioStreamPlayer.new()
	_lose_colour_sound.stream = preload("res://assets/sounds/streak_break.ogg")
	_lose_colour_sound.volume_db = -4.0
	add_child(_lose_colour_sound)
	_pink_shift_sound = AudioStreamPlayer.new()
	_pink_shift_sound.stream = preload("res://assets/sounds/pink_shift.ogg")
	add_child(_pink_shift_sound)
	_clash_sound = AudioStreamPlayer.new()
	_clash_sound.stream = preload("res://assets/sounds/clash.ogg")
	_clash_sound.volume_db = KILL_CUT_DB
	add_child(_clash_sound)
	_ninja_alert_sound = AudioStreamPlayer.new()   # the ninja's alert (his swish, higher and sharper)
	_ninja_alert_sound.stream = preload("res://assets/sounds/knight_warn.ogg")
	add_child(_ninja_alert_sound)
	_warn_sound = AudioStreamPlayer.new()
	_warn_sound.stream = preload("res://assets/sounds/knight_warn.ogg")
	add_child(_warn_sound)
	if not OS.get_cmdline_user_args().is_empty():
		debug = DebugTools.new()
		debug.main = self
		add_child(debug)
	if LEVEL_CHOICE and progression.level == 1:   # (not set by the debug --level option)
		progression.level = _load_setting("start_level", 1)
		level.level = progression.level
	Palette.use_colour(_load_colour())   # the one picked last (pause screen / C), else COLOUR
	Palette.set_pink(0.0)   # every run starts red (her colour is the streak reward)
	player.x = START_X
	level.start_x = START_X
	level.enemy_parent = $EnemyLayer
	blood_fx = Fx.new()
	$EnemyLayer.add_child(blood_fx)
	# Her colour on everything these draw (sparks, slashes; the blood too if it
	# follows her colour), so the change-over sweep turns them as it passes.
	fx.material = Palette.sprite_material()
	if Palette.BLOOD_FOLLOWS_COLOUR:
		blood_fx.material = Palette.sprite_material()
	# Floating words (PERFECT, TOO SLOW, MISSED...) on their own layer, above
	# her, the enemies and every slash and bolt.
	var front_layer := CanvasLayer.new()   # a knight's body mid-clash, over her
	front_layer.layer = 7
	front_layer.follow_viewport_enabled = true
	front_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(front_layer)
	Knight.front_parent = front_layer
	var text_layer := CanvasLayer.new()
	text_layer.layer = 8
	text_layer.follow_viewport_enabled = true
	text_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(text_layer)
	text_fx = Fx.new()
	text_layer.add_child(text_fx)
	# Her effects too sit above the grey freeze filter, so they stay red in
	# the "your move" pause instead of turning grey.
	fx.reparent($EnemyLayer)
	level.bar_room = progression.bar_size() - progression.bar
	level.ensure_generated(player.x)
	cam.snap(player.x)
	best_score = _load_best()
	hud.show_start(best_score)
	_prewarm()
	if LEVEL_CHOICE:
		hud.show_level_choice(progression.level)
	hud.set_enemies_off(Level.enemies_off)   # practice mode stays on across retries


func score() -> int:
	return int(distance) + kill_score


func begin() -> void:
	state = State.PLAYING
	player.running = true
	_start_music()
	hud.hide_message()
	hud.set_pause_button_visible(true)


# --- input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Only real new presses do anything: no key repeats, no fake click after a tap.
	if not _is_fresh_press(event):
		return
	if get_tree().paused:
		# The "Flip screen" button (upright phones) turns the game 180 degrees.
		var tap: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
		if tap and hud.flip_button_contains(_screen_pos(event)):
			get_viewport().set_input_as_handled()
			JavaScriptBridge.eval("window.redFlashSetFlip(!window.redFlashFlip)", true)
			return
		if tap and hud.colour_button_contains(_screen_pos(event)):
			get_viewport().set_input_as_handled()
			Palette.next_colour()
			_save_colour()
			hud.refresh_colour_button()
			return
		if (tap and hud.enemies_button_contains(_screen_pos(event))) or _is_enemies_key(event):
			get_viewport().set_input_as_handled()
			_toggle_enemies()
			return
		# Any other key, click or tap resumes (it doesn't also teleport).
		if _is_press(event):
			get_viewport().set_input_as_handled()
			if Time.get_ticks_msec() - _paused_at_msec >= RESUME_GUARD * 1000.0:
				_set_paused(false)
		return
	if _is_enemies_key(event):
		get_viewport().set_input_as_handled()
		_toggle_enemies()
		return
	if Palette.CYCLE_KEY and event is InputEventKey and event.pressed and event.physical_keycode == KEY_C:
		get_viewport().set_input_as_handled()
		_cycle_colour()
		return
	if state == State.PLAYING and (event.is_action_pressed("pause") or _is_pause_button_press(event)):
		get_viewport().set_input_as_handled()
		_set_paused(true)
		return
	if LEVEL_CHOICE and state == State.READY and _start_level_input(event):
		get_viewport().set_input_as_handled()
		return
	var button := _button_from_event(event)
	if button == Rules.Move.NONE:
		return
	get_viewport().set_input_as_handled()
	match state:
		State.READY:
			if not hud.needs_portrait():
				_request_fullscreen()
				begin()
		State.PLAYING:
			if _auto or _finale_hold:
				return   # the auto-chain plays itself
			if player.cooldown > 0 and ((button == Rules.Move.FORWARD and _last_forward) or (button == Rules.Move.VERTICAL and _last_vertical)):
				return   # same button again right after a teleport: ignored
			if not _pending_forward and not _pending_vertical:
				_pending_frames = DIAGONAL_WINDOW_FRAMES
			if button == Rules.Move.FORWARD:
				_pending_forward = true
			else:
				_pending_vertical = true
			# Skip the rest of the kill pause.
			if _hitstop > 0.0:
				_pressed_during_pause = true
			_hitstop = minf(_hitstop, maxf(_pause_min - _pause_elapsed, 0.0))
		State.OVER:
			if _state_time >= RETRY_DELAY:
				get_tree().reload_current_scene()


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	if value:
		_paused_at_msec = Time.get_ticks_msec()
		_clear_pending()
	hud.show_paused(value, _web_canvas_rotated())


## Auto-pause when the window/tab/app loses focus (not during bot runs).
func _notification(what: int) -> void:
	if debug or state != State.PLAYING or get_tree().paused:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		_set_paused(true)
		_shift_held.clear()


## True only for a real new press. Key repeats are dropped (`echo`), and so
## is the fake mouse click a phone browser sends after a tap. The Shift keys
## get extra handling (see _shift_press_is_fresh).
func _is_fresh_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == KEY_SHIFT:
			return _shift_press_is_fresh(key)
		if not key.shift_pressed:
			_shift_held.clear()   # any key event with no Shift down: none is held
		return key.pressed and not key.echo
	if event is InputEventScreenTouch:
		_last_touch_msec = Time.get_ticks_msec()
		return event.pressed
	if event is InputEventMouseButton:
		if Time.get_ticks_msec() - _last_touch_msec < MOUSE_AFTER_TOUCH_IGNORE_MS:
			return false
		return event.pressed
	if event is InputEventAction:
		return event.pressed
	return false


## With both Shifts held, releasing one makes some systems report that Shift
## as pressed AGAIN (and never report its release). So a Shift press only
## counts if that Shift isn't already down. Because the release can go
## missing, the held state is cleared whenever no Shift is down at all
## (checked every frame in _physics_process, and on other key events).
func _shift_press_is_fresh(key: InputEventKey) -> bool:
	var side := key.location
	if not key.pressed:
		_shift_held.erase(side)
		return false
	if key.echo or _shift_held.has(side):
		return false
	_shift_held[side] = true
	return true


func _forget_shift_if_none_down() -> void:
	if not _shift_held.is_empty() and not Input.is_key_pressed(KEY_SHIFT) \
			and not Input.is_physical_key_pressed(KEY_SHIFT):
		_shift_held.clear()


func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		return event.pressed
	return false


func _is_pause_button_press(event: InputEvent) -> bool:
	var touch: bool = event is InputEventScreenTouch and event.pressed
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return (touch or click) and hud.pause_button_contains(_screen_pos(event))


## Must run inside an input event: browsers only allow fullscreen on a tap/press.
## iPhone Safari never allows it; there, "Add to Home Screen" gives fullscreen.
func _request_fullscreen() -> void:
	# Fullscreen would undo the page's 90-degree turn of the canvas
	# (browsers draw a fullscreen element unrotated), so skip it then.
	if _web_canvas_rotated():
		return
	if OS.has_feature("web") and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Left half of the screen = vertical, right half = forward.
## Returns Rules.Move.FORWARD, Rules.Move.VERTICAL or Rules.Move.NONE.
func _is_enemies_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.physical_keycode == KEY_N


## Practice mode: no enemies (or back on: they spawn just off screen).
func _toggle_enemies() -> void:
	var off := not Level.enemies_off
	level.set_enemies_off(off, cam.left() / Rules.TILE + CameraRig.VIEW_TILES + 1.0)
	hud.set_enemies_off(off)
	if off:
		# Drop any chain in progress without grading it.
		chain = 0
		_chain_awaiting = false
		_pressed_during_pause = false
		_chain_killed.clear()
		_hitstop = 0.0


func _button_from_event(event: InputEvent) -> int:
	if event is InputEventScreenTouch and event.pressed:
		return _button_for_screen_x(_screen_pos(event).x)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return _button_for_screen_x(_screen_pos(event).x)
	if event.is_action_pressed("tp_vertical"):
		return Rules.Move.VERTICAL
	if event.is_action_pressed("tp_forward"):
		return Rules.Move.FORWARD
	return Rules.Move.NONE


## On phones held upright, the web page turns the game's canvas 90 degrees
## so it shows as landscape (see html/head_include in export_presets.cfg).
## Godot doesn't know it's turned, so tap positions arrive along the wrong
## axes; this turns them back into game-screen positions.
func _screen_pos(event: InputEvent) -> Vector2:
	var pos: Vector2 = event.position
	if not _web_canvas_rotated():
		return pos
	var size := get_viewport().get_visible_rect().size
	var fx := pos.x / size.x
	var fy := pos.y / size.y
	if _web_canvas_flipped():   # turned the other way (game left at the bottom)
		return Vector2((1.0 - fy) * size.x, fx * size.y)
	return Vector2(fy * size.x, (1.0 - fx) * size.y)


func _web_canvas_flipped() -> bool:
	return int(JavaScriptBridge.eval("window.redFlashFlip === true ? 1 : 0", true)) == 1


func _web_canvas_rotated() -> bool:
	if not OS.has_feature("web"):
		return false
	# The browser bridge hands back JS booleans as 1 / 0, so ask for a number.
	return int(JavaScriptBridge.eval("window.redFlashRotated === true ? 1 : 0", true)) == 1


func _button_for_screen_x(screen_x: float) -> int:
	return Rules.Move.VERTICAL if screen_x < get_viewport().get_visible_rect().size.x * 0.5 else Rules.Move.FORWARD


func _clear_pending() -> void:
	_pending_forward = false
	_pending_vertical = false
	_pending_frames = 0
	_press_x_set = false


## The move to make this frame from the buttons pressed, waiting a few
## frames after a single press in case the other button follows (diagonal).
## The diagonal window keeps counting down during the cooldown, so a press
## that waited out the cooldown fires the moment it ends (can_fire).
func _take_pending_move(can_fire: bool) -> int:
	if not _pending_forward and not _pending_vertical:
		return Rules.Move.NONE
	var move := Rules.Move.NONE
	if _pending_forward and _pending_vertical:
		move = Rules.Move.DIAGONAL
	elif _pending_frames <= 0:
		move = Rules.Move.FORWARD if _pending_forward else Rules.Move.VERTICAL
	else:
		_pending_frames -= 1
		return Rules.Move.NONE
	if not can_fire:
		return Rules.Move.NONE
	_clear_pending()
	return move


# --- per frame -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_forget_shift_if_none_down()
	if get_tree().paused:
		return
	_state_time += delta
	var moving := false
	match state:
		State.PLAYING:
			if hud.needs_portrait():
				pass
			elif _hitstop > 0.0:
				_bot_acts_in_pause()
				_hitstop -= delta
				_pause_elapsed += delta
				var auto_wait := AUTO_DUEL_STEP if (_clashed or _knight_felled) else AUTO_STEP
				if _auto and not _finishing and _pause_elapsed >= auto_wait:
					_auto_hop()
					return
				if _hitstop <= 0.0 and _pause_is_chain and _chain_awaiting \
						and not _pressed_during_pause and not _pending_forward and not _pending_vertical:
					_end_chain("DROPPED", "TOO SLOW")   # waited too long in the "your move" freeze
					# A knight she's fighting (or straight across from her) strikes
					# right now: a press after TOO SLOW is too late.
					var ks := _knights_after_drop()
					if not ks.is_empty():
						_clear_pending()
						_knights_strike(ks)
			else:
				_step()
				moving = state == State.PLAYING
		State.DYING:
			var speed := _death_speed()
			player.animate_death(delta * speed)
			if _state_time >= DEATH_FREEZE + DEATH_SLOWMO + DEATH_ANIM_TIME * 0.4:
				_game_over()

	_update_knight_threats()
	_update_pause_visuals()
	var run_px := Rules.RUN_SPEED * Rules.TILE if moving else 0.0
	cam.follow(player.x, run_px, delta)
	# The real top-left of the view (a zoom can pan it left of cam.left()).
	level.set_view(minf(cam.left(), cam.position.x), cam.shown_world_size())
	hud.set_stats(score(), distance, kills, chain, 0.0)
	hud.set_streak(sweep)   # the flawless streak so far
	hud.set_charge(charge, CHARGE_FULL, _charged)
	var to_screen := get_viewport_rect().size.x / (CameraRig.VIEW_TILES * Rules.TILE)
	hud.set_progress(progression.level, progression.bar, progression.bar_size(), chain_points,
		(Rules.CEILING_Y - cam.top()) * to_screen)


func _update_pause_visuals() -> void:
	if state == State.DYING:
		_update_death_visuals()
		return
	var paused := state == State.PLAYING and _hitstop > 0.0
	var flashing := paused and INVERT_FLASH and _pause_elapsed < INVERT_TIME
	var chain_pause := paused and (_pause_is_chain or _finishing or _finale_hold)   # the finishers too
	freeze_effect.set_state(1.0 if flashing else 0.0, 1.0 if chain_pause and not flashing else 0.0)
	fx.frozen = paused and _pause_elapsed >= FX_FREEZE_AFTER
	blood_fx.frozen = fx.frozen
	text_fx.frozen = fx.frozen
	# Lit markers drain during the "your move" freeze as the time runs out.
	player.marker_fill = clampf(_hitstop / _pause_length, 0.0, 1.0) if chain_pause else 1.0
	if _finale_hold and not _finale_slashing:
		_finale_crackle -= get_physics_process_delta_time()
		if _finale_crackle <= 0.0:
			_finale_crackle = AUTO_FINALE_CRACKLE
			var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
			player.zap_fx.zap(body, 2, Vector2.ZERO, Vector2(24, 38), 3)
	player.freeze_ring = chain_pause and not _finishing and not _finale_hold   # her lightning circles her for the whole freeze (not the finisher)
	player.target_x = [_slash_target_x(Rules.Move.FORWARD), _slash_target_x(Rules.Move.VERTICAL),
		_slash_target_x(Rules.Move.DIAGONAL)]
	# Every enemy a teleport would slash right now gets a red glint.
	for e in level.enemies:
		e.targeted = false
	if state == State.PLAYING and player.alive and not _finishing:
		for move in [Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL]:
			var tx: float = player.x + Rules.move_dx(move)
			var trow: int = (1 - player.row) if Rules.move_flips_row(move) else player.row
			for e in level.enemies_hit_by(move, tx, trow):
				e.targeted = e.visible
	player.frozen = paused


## True if teleporting with `move` from x (default: where she is now) would
## land on an enemy.
func _would_slash(move: int, from_x: float = NAN) -> bool:
	if state != State.PLAYING or not player.alive:
		return false
	var x := player.x if is_nan(from_x) else from_x
	var tx: float = x + Rules.move_dx(move)
	var trow: int = (1 - player.row) if Rules.move_flips_row(move) else player.row
	return not level.enemies_hit_by(move, tx, trow).is_empty()


## The x (tiles) of the enemy teleporting with `move` right now would slash
## (the nearest to the landing spot), or NAN if none.
func _slash_target_x(move: int) -> float:
	if state != State.PLAYING or not player.alive:
		return NAN
	var tx: float = player.x + Rules.move_dx(move)
	var trow: int = (1 - player.row) if Rules.move_flips_row(move) else player.row
	var best := NAN
	for e in level.enemies_hit_by(move, tx, trow):
		if not e.visible:
			continue   # a knight mid-clash: don't give away where she's going
		if is_nan(best) or absf(e.tile_x - tx) < absf(best - tx):
			best = e.tile_x
	return best


func _step() -> void:
	# A press during the cooldown waits (stays pending) and fires as soon as
	# the cooldown ends, so mashing is rate-limited, never swallowed.
	var move := Rules.Move.NONE
	if debug and debug.bot:
		move = debug.think()
	else:
		# The press arrived since the last frame, so this is where she was.
		if (_pending_forward or _pending_vertical) and not _press_x_set and player.cooldown == 0:
			_press_x = player.x
			_press_x_set = true
		var waited := _press_x_set
		var press_x := _press_x
		move = _take_pending_move(player.cooldown == 0)
		if move != Rules.Move.NONE and player.cooldown == 0 and waited:
			# From the press point if that hits, else from here (a hit from
			# here, or a plain miss). Checking both ends covers the whole
			# stretch between them: it's shorter than a landing zone.
			if _would_slash(move, press_x):
				player.x = press_x

	# 1. teleport (ignored while on cooldown)
	if move != Rules.Move.NONE and player.cooldown == 0:
		_last_forward = move == Rules.Move.FORWARD or move == Rules.Move.DIAGONAL
		_last_vertical = move == Rules.Move.VERTICAL or move == Rules.Move.DIAGONAL
		_teleport(move)
		if _hitstop > 0.0:
			return   # killed: stay exactly on the enemy, so the markers line up

	# A chain just dropped (TOO SLOW, or this teleport MISSED) with her
	# straight across from a knight: the knight strikes at once.
	if _drop_pounce and not (_press_x_set and player.cooldown == 0):
		_drop_pounce = false
		if _knight_across():
			_knights_strike(_strikers())
			return

	# 2. run
	var run_from := player.x
	player.x += Rules.RUN_SPEED / Rules.PHYSICS_FPS
	distance = player.x - START_X

	# 3. running into an enemy in your row
	var touching := level.enemies_at(player.x, Rules.HIT_RADIUS, player.row)
	if not touching.is_empty():
		# A press waiting for a possible diagonal: she's already committed to
		# teleporting, so contact doesn't count until it fires.
		if not (_press_x_set and player.cooldown == 0):
			var k := touching[0] as Knight
			if k:
				# Another knight that would strike now comes from behind her.
				var others := _strikers(run_from).filter(func(o: Knight) -> bool: return o != k)
				if not others.is_empty():
					var back: Knight = others[0]
					var from := back.pounce(player.x, player.row, -1.0)
					fx.strike(from, Vector2(back.tile_x * Rules.TILE, Rules.body_center_y(back.row)), back.lightning(), KILL_STRIKE_FPS)
					_second_killer = back
				k.slash(player.x)   # the same killing blow as when the knight teleports to the player
				_warn_sound.play(WARN_PEAK)
				_die("knight", k)
			else:
				touching[0].attack()   # he cuts her down
				_die("hit", touching[0])
			return

	# 4. a knight she ran on past across the rows, or one she's fighting
	# that's within a teleport of her, teleports to her (same as ChunkSolver).
	# (Not while a press waits to fire: she's committed to teleporting, same
	# as running into an enemy.)
	var pouncer: Knight = null if (_press_x_set and player.cooldown == 0) else _pouncing_knight(run_from)
	if pouncer:
		_knights_strike(_strikers(run_from))   # with a second one, if there is
		return
	# 4b. a ninja she's running at, straight ahead in his reach: NINJA_AGGRO_DELAY
	# there and he strikes; at once if he'd already alerted and she came back.
	if not (_press_x_set and player.cooldown == 0) and _ninja_strikes():
		_knights_strike(_strikers(run_from))
		return
	_note_escapes()

	# 5. timers
	if player.cooldown > 0:
		player.cooldown -= 1

	level.ensure_generated(player.x)
	# Keep enemies and bodies a while after they scroll off the left: the
	# death camera pulls back and shows that stretch again.
	level.prune(cam.left() / Rules.TILE - PRUNE_BEHIND_TILES)


func _teleport(move: int) -> void:
	var from := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	var from_feet := Vector2(player.x * Rules.TILE, Rules.surface_y(player.row))
	var from_row := player.row
	var to_x := player.x + Rules.move_dx(move)
	var to_row := (1 - player.row) if Rules.move_flips_row(move) else player.row
	var hit := level.enemies_hit_by(move, to_x, to_row)
	if not hit.is_empty():
		# Land a fixed distance short of the enemy you hit (STRIKE_OFFSET), so
		# chains can't drift and she slashes him at sword's length.
		var target := hit[0]
		for e in hit:
			if absf(e.tile_x - to_x) < absf(target.tile_x - to_x):
				target = e
		var strike_x: float = target.tile_x - Rules.STRIKE_OFFSET
		# Except an across teleport: it only pulls you back if that lets you
		# chain on; otherwise you stay where you landed.
		var pulls_back: bool = move == Rules.Move.VERTICAL and strike_x < to_x
		if not pulls_back or not _chain_targets(strike_x, to_row).is_empty():
			to_x = strike_x
	player.x = to_x
	player.row = to_row
	# A combo never runs a frame, so build the level ahead here too (otherwise
	# a long chain outruns it and the next enemies pop in when it ends).
	level.ensure_generated(player.x)
	distance = to_x - START_X
	var to := Vector2(to_x * Rules.TILE, Rules.body_center_y(to_row))
	if move != Rules.Move.VERTICAL:
		# Forward and diagonal: the line runs at sword height, along the throw.
		from = player.sword_point(move, from_feet, from_row)
		to = player.sword_point(move, Vector2(to_x * Rules.TILE, Rules.surface_y(to_row)), to_row)
	_teleport_lightning(move, from, to, not hit.is_empty())
	player.teleport_afterimages(move, from_feet, from_row)

	if hit.is_empty():
		player.cooldown = Rules.cooldown_frames()
		if _chain_awaiting:
			_end_chain("DROPPED", "MISSED")   # teleported into empty space while an enemy was in reach
		# A teleport that hits nothing (a miss too): the full lightning strike.
		_play_strike(false)
		_note_escapes()
	else:
		player.cooldown = 0
		_drop_pounce = false   # a press that waited out the freeze hit after all
		player.strike()
		_play_strike(true)
		_clashed = false
		_knight_felled = false
		for e in hit:
			_kill(e)
		_note_escapes()   # one she just went past (skipped) breaks the streak now, mid-chain
		var targets := _chain_targets(to_x, to_row)
		_pause_is_chain = not targets.is_empty()
		_pause_length = maxf(KILL_PAUSE - KILL_PAUSE_STEP * (chain - 1), KILL_PAUSE_FLOOR)
		_pause_min = KILL_PAUSE_MIN
		if _clashed:
			# You can't see where the knight will blink to; and the clash itself plays first.
			_pause_length = _pause_length * CLASH_PAUSE_FACTOR + CLASH_BEAT
			_pause_min = maxf(KILL_PAUSE_MIN, CLASH_REAPPEAR)   # the player can go as soon as the knight shows where she went
		_hitstop = _pause_length if _pause_is_chain else KILL_HIT
		_pause_elapsed = 0.0
		if _pause_is_chain and _charged and not _auto and not _has_debut(hit) and not _has_debut(targets):
			_start_auto()   # (never on her debut knight: the player meets her by hand)
		if _pause_is_chain:
			if not _clashed and not _knight_felled:   # those have their own, bigger zoom
				cam.punch(to)
			_chain_awaiting = true
			_pressed_during_pause = false
		else:
			# Nothing left to chain: the chain ends here, on a kill.
			# PERFECT only if this chain killed the whole spawned chain, first
			# enemy to last; otherwise CLEAN. (A knight counts once she's dead:
			# hitting her and leaving her behind doesn't, see _kill.)
			var whole := not _chain_killed.is_empty()
			for id in level.section_ids_of(_chain_killed.back()):
				if not _chain_killed.has(id):
					whole = false
			var grade := "SINGLE" if chain == 1 else ("PERFECT" if whole else "CLEAN")
			# The reward: a flawless streak of STREAK_REWARD, and this chain ends on
			# a kill (whoever it is): the triple slash, and she takes on her colour.
			if _auto:
				_auto_finale(grade)   # (never the streak finisher: only her own chains earn that)
			elif sweep >= STREAK_REWARD and Palette.pink <= 0.0 and is_instance_valid(_last_felled):
				_finisher(_last_felled, grade)
			else:
				_end_chain(grade)


## The streak finisher (a flawless streak of STREAK_REWARD, then a chain that
## ends on a kill). Her hit has landed (pose one, left of the enemy): she blinks
## to the enemy's other side in her next pose, then back in the last, which holds as a
## freeze frame while her colour sweeps across the screen; then the chain
## ends. The enemy stays standing until it's over, then falls. She keeps the colour
## until the streak breaks (_break_streak).
func _finisher(k: Enemy, grade: String) -> void:
	# The whole thing the first time in a run; after that, the quick one.
	var quick := _finished_before
	_finished_before = true
	_fin_hop = FINISHER_QUICK_HOP if quick else FINISHER_HOP
	_fin_strike_fps = 18.0 if quick else FINISHER_STRIKE_FPS
	_fin_bolt_fps = FINISHER_QUICK_BOLT_FPS if quick else FINISHER_BOLT_FPS
	_fin_after = FINISHER_QUICK_AFTER if quick else FINISHER_SWEEP_AFTER
	_fin_sweep = FINISHER_QUICK_SWEEP if quick else FINISHER_SWEEP_TIME
	_fin_hold = FINISHER_QUICK_HOLD if quick else FINISHER_HOLD
	_finishing = true
	player.cinematic = true
	_hitstop = 999.0   # held until _finisher_done; a press can't cut it short
	_pause_min = 999.0
	_pause_is_chain = false
	_pause_elapsed = 0.0
	k.take_hit()   # (her first strike) the enemy recoils, and stays standing until it's over
	# Far enough either side of the enemy that it's seen between her strikes.
	var left_x := k.tile_x - FINISHER_SIDE
	var right_x := k.tile_x + FINISHER_SIDE
	# The first slash too: her hit landed at the usual strike distance (close
	# to the enemy); on this same frame she's put back to where the others are.
	player.x = left_x
	player.strike(player.last_pose())
	player.hold_slash(_fin_hop)
	_finisher_bolt()
	var poses: Array = []
	for p in Player.ATTACK_COUNT:
		if p != player.last_pose():
			poses.append(p)
	var focus := Vector2(k.tile_x * Rules.TILE, Rules.body_center_y(k.row))
	cam.hold_zoom(focus, FINISHER_ZOOM, 10.0, 0.5)   # centred on the enemy
	var t := create_tween()
	t.tween_interval(_fin_hop)
	t.tween_callback(_finisher_strike.bind(k, right_x, -1.0, poses[0], ""))
	t.tween_interval(_fin_hop)
	t.tween_callback(_finisher_strike.bind(k, left_x, 1.0, poses[1], grade))
	# The freeze frame: pink sweeps across her, then the level-up.
	t.tween_interval(_fin_after)
	# A wave across the whole screen, right to left.
	var sweep := func(at: float) -> void:
		var x := lerpf(1.03, -0.03, at)
		Palette.sweep_to(x)
		hud.show_sweep(x, Palette.flash_colour())
	t.tween_callback(_pink_shift_sound.play)
	t.tween_method(sweep, 0.0, 1.0, _fin_sweep)
	t.tween_callback(_finisher_level_up.bind(grade))
	t.tween_interval(_fin_hold)
	t.tween_callback(_finisher_done.bind(k, focus))


## One of the finisher's blinks: to to_x, facing `face`, in `pose`. The last
## one (`grade` given) ends the chain and turns her pink.
func _finisher_strike(k: Enemy, to_x: float, face: float, pose: int, grade: String) -> void:
	if state != State.PLAYING:
		return
	var from := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	var from_feet := Vector2(player.x * Rules.TILE, Rules.surface_y(player.row))
	var dir := signf(to_x - player.x)
	player.x = to_x
	player.facing = face
	fx.strike(from, Vector2(to_x * Rules.TILE, Rules.body_center_y(player.row)), false, _fin_strike_fps)
	player.strike_from(from_feet)
	player.strike(pose)
	# Her slash stays up until the next strike (the last one: through the sweep).
	player.hold_slash(_fin_hop if grade == "" else _fin_after + _fin_sweep + _fin_hold)
	_play_strike(true)
	# The last pose's bolt stays up until she's finished turning pink.
	_finisher_bolt(0.0 if grade == "" else _fin_after + _fin_sweep)
	hud.flash(FINISHER_STRIKE_FLASH, 0.15)
	var pos := Vector2(k.tile_x * Rules.TILE, Rules.body_center_y(k.row))
	blood_fx.blood(pos, dir, 30, BLOOD_BURST, 1.0 if k.row == Rules.Row.CEILING else -1.0)
	fx.kill_burst(pos, 6)
	cam.shake(0.15, 14.0)
	if is_instance_valid(k):
		k.take_hit()
		k.modulate = Color(2.5, 2.5, 2.5)
		k.create_tween().tween_property(k, "modulate", Color.WHITE, 0.12)
	if grade == "":
		_kill_sound.pitch_scale = _jitter()
		_kill_sound.play()
		return
	_knight_kill_sound.pitch_scale = _jitter()
	_knight_kill_sound.play()


## A bolt straight down onto where she is (up from the floor when she's on the
## ceiling), its burst at her feet.
## `hold`: seconds the bolt stays at full strength before it fades (the last
## one stays up through her colour change).
func _finisher_bolt(hold := 0.0) -> void:
	var feet := Vector2(player.x * Rules.TILE, Rules.surface_y(player.row))
	var up := -1.0 if player.row == Rules.Row.FLOOR else 1.0   # toward the other row
	var centre := feet + Vector2(0, up * (BIG_STRIKE_BURST_Y - 128.0) * FINISHER_BOLT_SIZE.y)
	fx.bolt(Fx.Bolt.BIG_STRIKE, centre, 0.0 if player.row == Rules.Row.FLOOR else PI, FINISHER_BOLT_SIZE, _fin_bolt_fps,
		0, false, BIG_STRIKE_FULL_FRAME if hold > 0.0 else -1, hold)


## The sweep is done: she's pink, with a flash, and the chain ends (the
## level-up into 10).
func _finisher_level_up(grade: String) -> void:
	Palette.set_pink(1.0)
	hud.show_sweep(-1.0, Color.WHITE)
	hud.flash(Palette.flash_colour(), 0.6)   # in her new colour
	cam.shake(0.25, 14.0)
	var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	fx.bolt(Fx.Bolt.RING, body, randf() * TAU, Vector2.ONE * 2.2, 12.0)
	_end_chain(grade)   # the level-up (its jingle, the bar)


## Testing colours: the C key switches her level-10 colour to the next one
## in Palette.COLOURS (shown at once, at any level, with its name).
func _cycle_colour() -> void:
	var name := Palette.next_colour()
	_save_colour()
	hud.refresh_colour_button()
	Palette.set_pink(1.0)
	var above := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row) - Rules.TILE * 1.8)
	if player.row == Rules.Row.CEILING:
		above.y += Rules.TILE * 3.6
	text_fx.text(above, name.replace("_", " ").to_upper(), 26, Color.WHITE, Rules.RUN_SPEED * Rules.TILE if state == State.PLAYING else 0.0, 1.2)


## The power-up meter: CLEAN / PERFECT chains add to it; full = charged.
func _add_charge(n: int) -> void:
	if n <= 0 or _charged:
		return
	charge = mini(charge + n, CHARGE_FULL)
	if charge >= CHARGE_FULL:
		_charged = true
		player.charged = true
		_sync_debut_wait()
		_charge_sound.play()
		var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
		player.zap_fx.zap(body, 6, Vector2.ZERO, Vector2(26, 40), 6)
		hud.flash(Color(0.75, 0.9, 1.0, 0.25), 0.25)


## A charged kill with a chain after it: the rest of the chain plays itself.
func _start_auto() -> void:
	_auto = true
	_charged = false
	# Nothing new is laid until it's over (chains not on screen yet go too).
	level.spawn_hold = true
	level.rebuild_ahead(cam.left() / Rules.TILE + CameraRig.VIEW_TILES + 3.0)
	_sync_debut_wait()
	charge = 0
	player.charged = false
	player.auto_chain = true
	_clear_pending()
	hud.flash(Color(0.8, 0.95, 1.0, 0.35), 0.15)
	cam.shake(0.2, 10.0)


## The auto-chain's next move (also the bot's in the freeze): see _auto_hop.
func _auto_pick(skip_debut := true) -> int:
	var best_move := Rules.Move.NONE
	var best_x := INF
	var best_enemy: Enemy = null
	for move in [Rules.Move.VERTICAL, Rules.Move.FORWARD, Rules.Move.DIAGONAL]:   # (ties: across first)
		var tx: float = player.x + Rules.move_dx(move)
		var trow: int = (1 - player.row) if Rules.move_flips_row(move) else player.row
		for e in level.enemies_hit_by(move, tx, trow):
			if skip_debut and e is Knight and (e as Knight).debut:
				continue   # her debut: the auto-chain stops short of her
			if e.tile_x < best_x - 0.01:
				best_move = move
				best_x = e.tile_x
				best_enemy = e
	# A knight ahead and a plain enemy in the other row about level with her
	# (one by FORWARD, one by DIAGONAL): the plain one first, if the knight is
	# still straight across from where that lands (nothing skipped), so the
	# knight's hits then come one after another.
	if best_enemy is Knight and best_move != Rules.Move.VERTICAL:
		for move in [Rules.Move.FORWARD, Rules.Move.DIAGONAL]:
			if move == best_move:
				continue
			var tx: float = player.x + Rules.move_dx(move)
			var trow: int = (1 - player.row) if Rules.move_flips_row(move) else player.row
			for e in level.enemies_hit_by(move, tx, trow):
				if e is Knight:
					continue
				if Rules.in_kill_zone(Rules.Move.VERTICAL, best_enemy.tile_x, e.tile_x - Rules.STRIKE_OFFSET):
					best_move = move
					best_x = e.tile_x
					best_enemy = e
					break
	return best_move


## One hop of the auto-chain: onto the nearest enemy under a marker, so none
## is ever left behind (a knight she's fighting waits her turn); one straight
## across from her goes first, and a plain enemy before a knight level with him.
func _auto_hop() -> void:
	var best_move := _auto_pick()
	if best_move == Rules.Move.NONE:
		_auto = false
		player.auto_chain = false
		level.spawn_hold = false
		_sync_debut_wait()
		return
	_hitstop = 0.0
	_pressed_during_pause = true
	_clear_pending()
	player.cooldown = 0
	_teleport(best_move)
	# Every hop crackles.
	var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	player.zap_fx.zap(body, 3, Vector2.ZERO, Vector2(20, 34), 3)
	hud.flash(Color(0.85, 0.95, 1.0, 0.12), 0.08)


## The auto-chain's end: its last kill holds, zoomed in on her, then a big
## strike of lightning onto her and thunder; the chain counts (as she'd have
## played it), then a breather before the next.
func _auto_finale(grade: String) -> void:
	_auto = false
	_finale_hold = true
	_finale_crackle = 0.0
	_hitstop = AUTO_FINALE_FREEZE + 1.0   # (ended by the strike)
	_pause_min = 999.0
	_pause_is_chain = false
	_chain_awaiting = false
	_pause_elapsed = 0.0
	player.hold_slash(AUTO_FINALE_FREEZE)
	var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	cam.hold_zoom(body, AUTO_FINALE_ZOOM, 16.0)
	cam.shake(0.1, 12.0)
	_duck_music(MUSIC_DB + AUTO_FINALE_DUCK_DB, 0.12)
	hud.flash(Color(1, 1, 1, 0.3), 0.1)
	var k := _last_felled
	if not is_instance_valid(k):
		get_tree().create_timer(AUTO_FINALE_FREEZE, false).timeout.connect(_auto_finale_strike.bind(grade, null))
		return
	# The three slashes of the streak finisher, at full speed: her hit has
	# landed (pose one, left of the enemy), she blinks to his other side, then
	# back; he stays standing through them and falls with the big strike.
	_finale_slashing = true
	player.cinematic = true
	k.take_hit()
	var left_x := k.tile_x - FINISHER_SIDE
	var right_x := k.tile_x + FINISHER_SIDE
	_finale_home_x = player.x   # (back here under the big strike's flash)
	player.x = left_x
	player.strike(player.last_pose())
	player.hold_slash(AUTO_SLASH_HOP)
	var poses: Array = []
	for p in Player.ATTACK_COUNT:
		if p != player.last_pose():
			poses.append(p)
	cam.hold_zoom(Vector2(k.tile_x * Rules.TILE, Rules.body_center_y(k.row)), AUTO_FINALE_ZOOM, 16.0, 0.5)
	var t := create_tween()
	t.tween_interval(AUTO_SLASH_HOP)
	t.tween_callback(_auto_slash.bind(k, right_x, -1.0, poses[0]))
	t.tween_interval(AUTO_SLASH_HOP)
	t.tween_callback(_auto_slash.bind(k, left_x, 1.0, poses[1]))
	t.tween_interval(AUTO_SLASH_TO_BANG)
	t.tween_callback(_auto_finale_strike.bind(grade, k))


## One of the finish's blinks: to to_x, facing `face`, in `pose` (the streak
## finisher's, at full speed).
func _auto_slash(k: Enemy, to_x: float, face: float, pose: int) -> void:
	if state != State.PLAYING:
		return
	var from := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	var from_feet := Vector2(player.x * Rules.TILE, Rules.surface_y(player.row))
	var dir := signf(to_x - player.x)
	player.x = to_x
	player.facing = face
	fx.strike(from, Vector2(to_x * Rules.TILE, Rules.body_center_y(player.row)))
	player.strike_from(from_feet)
	player.strike(pose)
	player.hold_slash(AUTO_SLASH_HOP)
	_play_strike(true)
	hud.flash(FINISHER_STRIKE_FLASH, 0.1)
	if is_instance_valid(k):
		var pos := Vector2(k.tile_x * Rules.TILE, Rules.body_center_y(k.row))
		blood_fx.blood(pos, dir, 24, BLOOD_BURST, 1.0 if k.row == Rules.Row.CEILING else -1.0)
		fx.kill_burst(pos, 6)
		k.take_hit()
		k.modulate = Color(2.5, 2.5, 2.5)
		k.create_tween().tween_property(k, "modulate", Color.WHITE, 0.1)
	cam.shake(0.1, 10.0)
	_kill_sound.pitch_scale = _jitter()
	_kill_sound.play()


func _auto_finale_strike(grade: String, k: Enemy) -> void:
	_finale_hold = false
	_finale_slashing = false
	player.cinematic = false
	player.facing = 1.0
	player.auto_chain = false
	_hitstop = 0.0
	_pause_min = KILL_PAUSE_MIN
	if is_instance_valid(k):
		k.fall()   # now the last one falls
		player.x = _finale_home_x
	if state != State.PLAYING:
		return
	var feet := Vector2(player.x * Rules.TILE, Rules.surface_y(player.row))
	var up := -1.0 if player.row == Rules.Row.FLOOR else 1.0
	fx.bolt(Fx.Bolt.BIG_STRIKE, feet + Vector2(0, up * (BIG_STRIKE_BURST_Y - 128.0) * 2.0), 0.0 if player.row == Rules.Row.FLOOR else PI, Vector2(1.8, 2.0), 7.0)
	var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	fx.bolt(Fx.Bolt.RING, body, randf() * TAU, Vector2.ONE * 3.2, 12.0)
	player.zap_fx.zap(body, 12, Vector2.ZERO, Vector2(36, 54), 10)
	hud.flash(Color(1.0, 1.0, 1.0, 0.9), 0.55)
	cam.hold_zoom(body, 0.0, 3.0)
	cam.punch(body, 0.15, 0.6)
	cam.shake(AUTO_FINALE_SHAKE_TIME, AUTO_FINALE_SHAKE)
	_auto_finale_sound.play()
	_auto_finale_layer.pitch_scale = 0.85   # deeper than a knight's last hit
	_auto_finale_layer.play()
	_duck_music(MUSIC_DB, 1.6, 0.35)
	_auto_ending = true
	_end_chain(grade)   # (adds no charge: the meter starts again from empty)
	_auto_ending = false
	# The bang lands on a short frozen frame.
	_hitstop = AUTO_FINALE_IMPACT
	_pause_min = AUTO_FINALE_IMPACT
	_pause_is_chain = false
	_pause_elapsed = 0.0
	# Anyone still standing ahead of her on screen (on screen before it began)
	# is struck down by it too (no points), so the screen is clear.
	var right := cam.left() / Rules.TILE + CameraRig.VIEW_TILES + 2.0
	for e in level.enemies:
		if e.alive and e.tile_x > player.x and e.tile_x < right:
			var pos := Vector2(e.tile_x * Rules.TILE, Rules.body_center_y(e.row))
			fx.strike(pos + Vector2(0, -260.0 if e.row == Rules.Row.FLOOR else 260.0), pos)
			fx.kill_burst(pos, 3)
			blood_fx.blood(pos, 1.0, 20, BLOOD_BURST, 1.0 if e.row == Rules.Row.CEILING else -1.0)
			e.die()
	# A breather: nothing was laid during the auto-chain, and the next chain
	# comes in well past the screen's right edge.
	level.spawn_hold = false
	level.push_cursor(cam.left() / Rules.TILE + CameraRig.VIEW_TILES + AUTO_GAP_TILES)
	_sync_debut_wait()
	level.ensure_generated(player.x)


## The first time a shader (or a kind of draw with it) is used, the browser
## compiles it, which made the first kill hitch. So on the start screen every
## effect is drawn once into an off-screen picture that's never shown, then
## thrown away.
func _prewarm() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var at := Vector2(128, 128)
	var warm := Fx.new()
	warm.material = Palette.sprite_material()
	view.add_child(warm)
	warm.kill_burst(at, 3)
	warm.blood(at, 1.0, 8, 0.1)
	warm.zap(at, 2)
	warm.zap_line(at, at + Vector2(80, 0))
	warm.strike(at - Vector2(100, 0), at)
	warm.strike(at - Vector2(100, 0), at, true)
	for kind in Fx.Bolt.values():
		warm.bolt(kind, at)
	warm.bolt(Fx.Bolt.SPARKS, at, 0.0, Vector2.ONE, 20.0, 0, true)
	warm.bolt(Fx.Bolt.SPARKS, at, 0.0, Vector2.ONE, 20.0, 0, "cyan")
	warm.strike(at - Vector2(100, 0), at, "cyan")
	warm.text(at, "PERFECT", 30, Color.WHITE)
	var plain := Fx.new()   # blood / sparks without her colour material
	view.add_child(plain)
	plain.blood(at, 1.0, 8, 0.1)
	plain.kill_burst(at, 1)
	for shader in [Player.ARC_SHADER, Player.GHOST_SHADER, Player.MARKER_SHADER, Player.DISSOLVE_SHADER,
			Enemy.OUTLINE_SHADER, Palette.SHADER]:
		var m := ShaderMaterial.new()
		m.shader = shader
		var spr := Sprite2D.new()
		spr.texture = Fx.BOLT_SHEETS[0]
		spr.material = m
		spr.position = at
		view.add_child(spr)
	var grey := ColorRect.new()   # the "your move" filter (it reads the screen)
	grey.size = Vector2(256, 256)
	grey.material = ShaderMaterial.new()
	grey.material.shader = FreezeEffect.SHADER
	view.add_child(grey)
	freeze_effect.prewarm(0.5)   # (that one reads the real screen, so it warms up there, at 0.2 %: unseen)
	get_tree().create_timer(0.5).timeout.connect(view.queue_free)


## Fades the music to `db` over `seconds`, after `delay`.
func _duck_music(db: float, seconds: float, delay := 0.0) -> void:
	var music := get_tree().root.get_node_or_null("Music") as AudioStreamPlayer
	if music == null:
		return
	var t := music.create_tween()
	t.tween_interval(delay)
	t.tween_property(music, "volume_db", db, seconds)


## Her knight debut waits while the power-up is charged or playing (so it
## never plays through her). If it's already laid but not on screen yet, it's
## taken back (and comes later); see Level.debut_wait.
func _sync_debut_wait() -> void:
	var wait := _charged or _auto
	if wait and not level.debut_wait and level.debut_pending():
		level.debut_wait = true
		level.rebuild_ahead(cam.left() / Rules.TILE + CameraRig.VIEW_TILES + 3.0)
		level.ensure_generated(player.x)
	level.debut_wait = wait


func _has_debut(enemies: Array) -> bool:
	for e in enemies:
		if e is Knight and (e as Knight).debut:
			return true
	return false


## The flawless streak is over (an enemy got away, or a chain was dropped):
## back to 0, and if she had her colour, she loses it, with a crack.
func _break_streak() -> void:
	sweep = 0
	if Palette.pink > 0.0 and not _finishing:
		_lose_colour_sound.pitch_scale = _jitter()
		_lose_colour_sound.play()
		create_tween().tween_method(Palette.set_pink, Palette.pink, 0.0, LOSE_COLOUR_TIME)


func _finisher_done(k: Enemy, focus: Vector2) -> void:
	_finishing = false
	player.cinematic = false
	player.facing = 1.0
	if is_instance_valid(k):
		k.fall()   # now the enemy falls
	cam.hold_zoom(focus, 0.0, 4.0)
	_hitstop = 0.0
	_pause_min = KILL_PAUSE_MIN
	_clear_pending()


## A knight that comes for her after she ran from run_from to where she is:
## one she ran on past while straight across from the knight, or one she's hit
## that's within a teleport of her (same rules as ChunkSolver).
func _pouncing_knight(run_from: float) -> Knight:
	for e in level.enemies:
		var k := e as Knight
		if k == null or not k.alive:
			continue
		if k.engaged and Rules.knight_in_reach(k.tile_x - player.x):
			return k
		if Rules.knight_runs_past(k.tile_x, k.row, run_from, player.x, player.row):
			return k
	return null


## A knight that strikes the moment a chain drops: one she's fighting within
## a teleport of her, or one straight across from her.
## Every knight that strikes when the freeze runs out: ones she's fighting
## within a teleport of her, and ones straight across from her. At most two
## (the nearest); they come at her from both sides (see _knights_strike).
func _knights_after_drop() -> Array[Knight]:
	return _strikers()


## Every knight that comes for her when one strikes: ones she's fighting
## within a teleport of her, ones straight across from her, and (running from
## run_from) ones she just ran past across the rows. The nearest two; they
## come at her from both sides (see _knights_strike).
func _strikers(run_from := NAN) -> Array[Knight]:
	var found: Array[Knight] = []
	for e in level.enemies:
		var k := e as Knight
		if k == null or not k.alive:
			continue
		var fighting := k.engaged and Rules.knight_in_reach(k.tile_x - player.x)
		var passed := not is_nan(run_from) and Rules.knight_runs_past(k.tile_x, k.row, run_from, player.x, player.row)
		var ahead := k.forward_aggro and not k.engaged and Rules.ninja_ahead(k.tile_x, k.row, player.x, player.row)
		if fighting or passed or ahead or Rules.knight_across(k.tile_x, k.row, player.x, player.row):
			found.append(k)
	found.sort_custom(func(a: Knight, b: Knight) -> bool:
		return absf(a.tile_x - player.x) < absf(b.tile_x - player.x))
	return found.slice(0, 2)


## One knight strikes from the front; two: the one further ahead from the
## front, the other from behind her, at the same moment.
func _knights_strike(ks: Array[Knight]) -> void:
	if ks.size() == 1:
		_knight_strikes(ks[0])
		return
	var front: Knight = ks[0] if ks[0].tile_x >= ks[1].tile_x else ks[1]
	var back: Knight = ks[1] if front == ks[0] else ks[0]
	var from := back.pounce(player.x, player.row, -1.0)
	fx.strike(from, Vector2(back.tile_x * Rules.TILE, Rules.body_center_y(back.row)), back.lightning(), KILL_STRIKE_FPS)
	_second_killer = back
	_knight_strikes(front)


## Every running frame: each ninja she's in front of (in his row, in her
## forward reach) counts the time; true if one strikes now (his delay is up,
## or he'd alerted before and she's come back into his reach).
func _ninja_strikes() -> bool:
	var strike := false
	for e in level.enemies:
		var k := e as Knight
		if k == null or not k.alive or not k.forward_aggro or k.engaged:
			continue
		var now := Rules.ninja_ahead(k.tile_x, k.row, player.x, player.row)
		if now and not k.ahead and k.alerted:
			strike = true   # she left his reach after his alert, and came back
		if now:
			k.aggro_time += 1.0 / Rules.PHYSICS_FPS
			if k.aggro_time >= Rules.NINJA_AGGRO_DELAY - 0.0001:
				strike = true
		k.ahead = now
	return strike


## A knight straight across from her right now, or null.
func _knight_across() -> Knight:
	for e in level.enemies:
		var k := e as Knight
		if k and k.alive and Rules.knight_across(k.tile_x, k.row, player.x, player.row):
			return k
		if k and k.alive and k.forward_aggro and not k.engaged and Rules.ninja_ahead(k.tile_x, k.row, player.x, player.row):
			return k   # (a ninja: straight ahead of her)
	return null


## Every frame (freezes too): a knight she's straight across from winds up
## (sword raised, the swish starts); one she's no longer across from relaxes.
func _update_knight_threats() -> void:
	var any := false
	for e in level.enemies:
		var k := e as Knight
		if k == null or not k.alive:
			continue
		# Once you're fighting a knight she's past warning you (no wind-up, no swish).
		var across := state == State.PLAYING and not k.engaged \
				and Rules.knight_across(k.tile_x, k.row, player.x, player.row)
		# A ninja also watches straight ahead (see ninja.gd).
		var ahead := state == State.PLAYING and k.forward_aggro and not k.engaged \
				and Rules.ninja_ahead(k.tile_x, k.row, player.x, player.row)
		if ahead:
			k.alerted = true
		across = across or ahead
		if across and not k.threat:
			k.warn()
			if not k.warned:   # the swish only the first time the knight is aggroed
				k.warned = true
				var snd := _ninja_alert_sound if k.forward_aggro else _warn_sound
				snd.pitch_scale = _jitter() * (NINJA_ALERT_PITCH if k.forward_aggro else 1.0)
				snd.play()
		elif not across and k.threat:
			k.calm()
		any = any or across
	if not any and _warn_sound.playing and state == State.PLAYING:
		_warn_sound.stop()


func _knight_strikes(k: Knight) -> void:
	var from := k.pounce(player.x, player.row)
	# Slower than a teleport, so it's still there through the death freeze.
	fx.strike(from, Vector2(k.tile_x * Rules.TILE, Rules.body_center_y(k.row)), k.lightning(), KILL_STRIKE_FPS)
	# The knight's swish lands with the slash: skip to its peak if it isn't there yet.
	if not _warn_sound.playing or _warn_sound.get_playback_position() < WARN_PEAK:
		_warn_sound.play(WARN_PEAK)
	_die("knight", k)


## An enemy left behind alive, out of reach, got away: the sweep is over.
func _note_escapes() -> void:
	for e in level.enemies:
		if e.alive and not e.escaped and Rules.knight_passed(e.tile_x - player.x):
			e.escaped = true
			_break_streak()


## Live enemies under any marker at this spot, i.e. what one more press
## right now could chain onto.
func _chain_targets(x: float, row: int) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for move in [Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL]:
		var tx: float = x + Rules.move_dx(move)
		var trow: int = (1 - row) if Rules.move_flips_row(move) else row
		for e in level.enemies_hit_by(move, tx, trow):
			if not found.has(e):
				found.append(e)
	return found


## The bot (debug only) can't press during the freeze through think(), so
## here it chains onto whatever is under a marker, like a player would.
func _bot_acts_in_pause() -> void:
	if not (debug and debug.bot) or not _pause_is_chain or _pressed_during_pause or _auto:
		return
	# The same pick as the auto-chain (nearest first, across first, a plain
	# enemy before a knight level with him), so nothing is let go.
	var move := _auto_pick(false)
	if move == Rules.Move.NONE:
		return
	debug.force_move(move)
	_pressed_during_pause = true
	_hitstop = minf(_hitstop, maxf(_pause_min - _pause_elapsed, 0.0))


# Every move crackles: strike 16 for a move that hits nothing; strike 13's
# first crack, quieter, under the saber cut on a kill (the cut carries the hit).
const STRIKE_MOVE := preload("res://assets/sounds/strike_16.ogg")
const STRIKE_KILL := preload("res://assets/sounds/strike_13_short.ogg")
const STRIKE_DB := -4.0
const STRIKE_UNDER_CUT_DB := -7.0
const KILL_CUT_DB := -6.0   # the saber cut on a kill (the crack above sits just under it)
# Every sound that repeats a lot gets a small random pitch offset, so repeats
# don't sound identical. PERFECT and level-up sit a step above the plain cut.
const PITCH_JITTER := 0.04
const JINGLE_PITCH := 1.1


func _jitter() -> float:
	return randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)


func _play_strike(kills: bool) -> void:
	_teleport_sound.stream = STRIKE_KILL if kills else STRIKE_MOVE
	_teleport_sound.volume_db = STRIKE_UNDER_CUT_DB if kills else STRIKE_DB
	_teleport_sound.pitch_scale = _jitter()
	_teleport_sound.play()


## The teleport's lightning, the same for every direction: a strike along the
## throw that bursts where she lands.
func _teleport_lightning(_move: int, from: Vector2, to: Vector2, _kills: bool) -> void:
	fx.strike(from, to)


func _kill(e: Enemy) -> void:
	var knight := e as Knight
	chain += 1
	chain_points += Rules.KNIGHT_POINTS if knight else 1
	# The bar room the level builder sees includes this chain's kills so far
	# (at their best: a PERFECT), so it stops laying chains in time.
	level.bar_room = progression.bar_size() - progression.bar - chain_points * float(Progression.MULTIPLIER["PERFECT"])
	best_chain = maxi(best_chain, chain)
	var points := Rules.KILL_POINTS * chain
	kill_score += points
	sweep += 1
	best_sweep = maxi(best_sweep, sweep)
	if knight and knight.hits_left() > 1:
		_clash(knight)
		return
	_chain_killed.append(e.get_instance_id())   # dead (a knight only on her last hit)
	_last_felled = e
	e.die()
	level.enemies.erase(e)   # out of the game now; the body stays (level.corpses)
	level.corpses.append(e)
	kills += 1

	var c := mini(chain, 6)
	var pos := Vector2(e.tile_x * Rules.TILE, Rules.body_center_y(e.row))
	# Saber cut, played at the end of the frame: if this kill ends the chain
	# as a PERFECT or a level-up, that sound plays instead.
	_kill_sound.pitch_scale = _jitter()
	if not _cut_pending:
		_cut_pending = true
		_play_pending_cut.call_deferred()
	if knight:
		_knight_kill_sound.pitch_scale = _jitter()
		_knight_kill_sound.play()
		# The last hit gets the clash's zoom, on the two of them.
		_knight_felled = true
		_felled_knight = knight
		var her := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
		cam.punch((pos + her) * 0.5, CLASH_ZOOM, CLASH_BEAT + 0.15)
	cam.shake(0.06, 4.0 + 1.5 * c)   # only during the flash, so the freeze reads as still
	fx.kill_burst(pos, chain)
	blood_fx.blood(pos, 1.0, 22 + 3 * c, BLOOD_BURST,
		1.0 if e.row == Rules.Row.CEILING else -1.0)   # flung the way she was going
	if Hud.SHOW_SCORE_UI:
		text_fx.text(pos - Vector2(0, 60), "+%d" % points, 22 + 2 * c, Color(1, 0.95, 0.8))



## A hit on a knight that doesn't finish her: swords clash, the knight flashes
## and blinks (green lightning) to her next spot, under one of the player's markers.
func _clash(knight: Knight) -> void:
	_clashed = true
	player.hold_slash(CLASH_BEAT)   # her big slash stays up through the beat
	var from := knight.blink(CLASH_BEAT, player.last_pose(), CLASH_REAPPEAR)
	_clash_sound.pitch_scale = _jitter()
	_clash_sound.play()
	cam.shake(0.3, 16.0)
	# The zoom eases out only after the knight has reappeared and her lightning is done.
	cam.punch((from + Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))) * 0.5, CLASH_ZOOM, CLASH_BEAT + 0.15)
	hud.flash(CLASH_FLASH, 0.12)
	# The knight blinks away at once: a quick green strike to her new spot, so
	# the player sees where she went straight away (her swing stays behind as a fading
	# afterimage, see Knight.blink).
	var to := Vector2(knight.tile_x * Rules.TILE, Rules.body_center_y(knight.row))
	var reappear := func() -> void:
		if is_instance_valid(knight) and state == State.PLAYING:
			fx.strike(from, to, knight.lightning())   # exactly her teleport's strike, in her colour (the ninja's cyan)
	if CLASH_REAPPEAR > 0.0:
		get_tree().create_timer(CLASH_REAPPEAR).timeout.connect(reappear)
	else:
		reappear.call()


func _play_jingle(sound: AudioStreamPlayer) -> void:
	_cut_pending = false
	_perfect_sound.stop()
	_level_up_sound.stop()
	sound.play()


func _play_pending_cut() -> void:
	if _cut_pending:
		_cut_pending = false
		_kill_sound.play()

const GRADE_COLORS := {
	"PERFECT": Color(1.0, 0.85, 0.3), "CLEAN": Color(1, 1, 1),
	"DROPPED": Color(0.65, 0.65, 0.7), "SINGLE": Color(1, 1, 1),
}

## A chain is over: add it to the progression bar (see Progression for the
## grades), show how it went, and level up if earned.
const GRADE_TEXT_LIFE := 1.1   # seconds the grade word stays up


## word: what to show instead of the grade (a dropped chain says why it
## dropped: TOO SLOW or MISSED).
func _end_chain(grade: String, word: String = "") -> void:
	if chain > 0:
		var old_bar := progression.bar
		var old_size := progression.bar_size()
		var old_level := progression.level
		var levelled := progression.add_chain(chain_points, grade)
		level.bar_room = progression.bar_size() - progression.bar
		if grade == "PERFECT":
			perfect_chains += 1
		hud.show_chain_result(grade, chain_points, old_bar, old_size, old_level)
		# One sound: a level-up outranks the PERFECT that earned it, and
		# either replaces the last kill's saber cut.
		if levelled:
			# The PERFECT sound with an impact under it.
			_level_up_sound.pitch_scale = JINGLE_PITCH * _jitter()
			_play_jingle(_level_up_sound)
		elif grade == "PERFECT":
			# The saber cut with a shimmer.
			_perfect_sound.pitch_scale = JINGLE_PITCH * _jitter()
			_play_jingle(_perfect_sound)
		elif grade == "DROPPED" and word == "TOO SLOW":
			_dropped_sound.play()   # a muted thud: the chance passed
		# TOO SLOW with the player straight across from a knight: the knight strikes at once.
		# A MISSED teleport that lands her across from one gets the usual
		# warning and grace instead (as if she'd run there).
		if grade == "DROPPED" and word == "TOO SLOW":
			_drop_pounce = true
		if grade == "DROPPED":
			_break_streak()   # a dropped chain ends the flawless streak
		if not _auto and not _auto_ending:
			_add_charge(int(CHARGE_GAIN.get(grade, 0)))
		if grade != "SINGLE":
			var above := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row) - Rules.TILE * 1.4)
			if player.row == Rules.Row.CEILING:
				above.y += Rules.TILE * 2.8
			text_fx.text(above, word if word != "" else grade, 30, GRADE_COLORS[grade], Rules.RUN_SPEED * Rules.TILE, GRADE_TEXT_LIFE,
					-1.0 if player.row == Rules.Row.CEILING else 1.0)   # drift away from her row
		if levelled:
			level.level = progression.level
			# Only groups well past the right edge get rebuilt (a sprite reaches
			# beyond its spot, so one just off screen could already show).
			level.rebuild_ahead(cam.left() / Rules.TILE + CameraRig.VIEW_TILES + 3.0)
			level.ensure_generated(player.x)
			if debug:
				debug.on_level_up(progression.level)
	chain = 0
	chain_points = 0
	_chain_awaiting = false
	_pressed_during_pause = false
	_chain_killed.clear()


func _die(kind: String, killer: Enemy = null) -> void:
	state = State.DYING
	hud.set_pause_button_visible(false)
	_state_time = 0.0
	_killer = killer
	_death_released = false
	player.running = false
	player.die(kind)
	_death_sound.play()
	for e in level.enemies:
		e.clear_glint()   # no red glints lingering on the death moment
	var body := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	_death_focus = body
	if killer and not is_instance_valid(_second_killer):
		_death_focus = (body + Vector2(killer.tile_x * Rules.TILE, Rules.body_center_y(killer.row))) * 0.5
	if kind == "hit" or kind == "knight":   # cut down from the front: blood sprays back, already bursting out
		blood_fx.blood(body, -1.0, 50, 0.25, 1.0 if player.row == Rules.Row.CEILING else -1.0)
	# Two knights, one either side: centred on her.
	cam.hold_zoom(_death_focus, DEATH_ZOOM, DEATH_ZOOM_RATE, 0.5 if is_instance_valid(_second_killer) else DEATH_FOCUS_X)
	cam.shake(0.2, 18.0)
	hud.flash(DEATH_FLASH, DEATH_FLASH_TIME)
	if debug:
		debug.on_death(kind)


## How fast the world runs during the death moment: 0 (frozen), then slow
## motion easing back to 1.
func _death_speed() -> float:
	if _state_time < DEATH_FREEZE:
		return 0.0
	var k := clampf((_state_time - DEATH_FREEZE) / DEATH_SLOWMO, 0.0, 1.0)
	return lerpf(DEATH_SLOW_SPEED, 1.0, k * k * k)   # stays very slow, then speeds up


func _update_death_visuals() -> void:
	var speed := _death_speed()
	var frozen := speed == 0.0
	if _state_time >= DEATH_FREEZE + DEATH_ZOOM_HOLD and not _death_released:
		_death_released = true
		# Ease back out, past normal, staying centred on the death.
		cam.hold_zoom(_death_focus, DEATH_ZOOM_OUT, 2.5, 0.5)
	player.frozen = frozen
	fx.frozen = frozen
	blood_fx.frozen = frozen
	text_fx.frozen = frozen
	player.zap_fx.frozen = frozen
	fx.time_scale = speed
	blood_fx.time_scale = speed
	text_fx.time_scale = speed
	player.zap_fx.time_scale = speed
	if is_instance_valid(_killer):
		_killer.set_anim_speed(speed)
	if is_instance_valid(_second_killer):
		_second_killer.set_anim_speed(speed)
	# Grey world, the player, her killer and the blood in colour; fades out with the slow motion.
	var grey := clampf(_state_time / DEATH_GREY_IN, 0.0, 1.0) if frozen else clampf(1.0 - (_state_time - DEATH_FREEZE) / DEATH_SLOWMO, 0.0, 1.0)
	freeze_effect.set_state(0.0, grey)


func _game_over() -> void:
	state = State.OVER
	_state_time = 0.0
	var final_score := score()
	var new_best := final_score > best_score
	if new_best:
		best_score = final_score
		_save_best(best_score)
	hud.show_game_over({
		"distance": distance, "kills": kills, "best_chain": best_chain, "perfect_chains": perfect_chains, "best_sweep": best_sweep, "level": progression.level,
		"score": final_score, "best": best_score, "new_best": new_best,
	})


# --- save ------------------------------------------------------------------

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("scores", "best", 0))


func _save_best(value: int) -> void:
	if debug:
		return  # don't let bot runs overwrite the real best score
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # keep the other settings
	cfg.set_value("scores", "best", value)
	cfg.save(SAVE_PATH)


# Background music: "Suspense Tension Building" (Monume). Its quiet intro
# plays once; then the body loops (from MUSIC_LOOP_FROM to the end of the
# file, seven 16 s phrases with a crossfade baked into the end). Its quiet
# fade-out was cut.
const MUSIC := preload("res://assets/music/background.ogg")
const MUSIC_DB := -9.0
const MUSIC_LOOP_FROM := 9.0   # seconds: where the end of the file joins up again


## Starts the music with the first run (browsers only allow sound after a
## press). It lives outside the scene, so it carries on through retries.
func _start_music() -> void:
	var music := get_tree().root.get_node_or_null("Music") as AudioStreamPlayer
	if music == null:
		music = AudioStreamPlayer.new()
		music.name = "Music"
		var stream: AudioStreamOggVorbis = MUSIC
		stream.loop = true
		stream.loop_offset = MUSIC_LOOP_FROM
		music.stream = stream
		music.volume_db = MUSIC_DB
		music.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(music)
	if not music.playing:
		music.play()


## Her level-10 colour (picked on the pause screen) is kept between visits.
func _save_colour() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "colour", Palette.colour_name)
	cfg.save(SAVE_PATH)


func _load_colour() -> String:
	return String(_load_setting("colour", Palette.colour_name))


func _load_setting(key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return default
	return cfg.get_value("settings", key, default)


## The start screen's level choice: tap its button (or L) to switch between
## the start levels, or press 1 / 5 / 0 (10). The run is rebuilt at that level.
## Returns true if the event was that.
func _start_level_input(event: InputEvent) -> bool:
	var tap: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	var want := -1
	if tap and hud.level_button_contains(_screen_pos(event)):
		want = 0
	elif event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_L: want = 0
			KEY_1: want = 1
			KEY_5: want = 5
			KEY_0: want = 10
	if want < 0:
		return false
	if want == 0:   # the next one
		want = START_LEVELS[(START_LEVELS.find(progression.level) + 1) % START_LEVELS.size()]
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "start_level", want)
	cfg.save(SAVE_PATH)
	if want != progression.level:
		# A fresh run at that level (after this input is done with).
		get_tree().reload_current_scene.call_deferred()
	return true

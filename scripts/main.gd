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
# Every kill gets a short hit freeze (invert flash).
const KILL_HIT := 0.06
# If another enemy is under any marker where you land, the
# freeze extends into a "your move" pause: grey world, lit markers, zoom.
# The camera keeps catching up during it, so the screen settles first.
const KILL_PAUSE := 0.7
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
# TEMPORARY: on-screen + Output-panel log of how fast you press (cooldown tuning).
const PRESS_RATE_LOG := true
const DEATH_ANIM_TIME := 0.7
const RETRY_DELAY := 0.5
const SAVE_PATH := "user://save.cfg"

@onready var level: Level = $Level
@onready var player: Player = $PlayerLayer/Player
@onready var cam: CameraRig = $Camera
@onready var fx: Fx = $FX
@onready var hud: Hud = $HUD
@onready var freeze_effect: FreezeEffect = $FreezeEffect

var state := State.READY
var distance := 0.0
var kills := 0
var kill_score := 0
var chain := 0
var chain_timer := 0.0
var best_chain := 0
var best_score := 0
var debug: DebugTools = null

var _pending_forward := false
var _pending_vertical := false
var _pending_frames := 0
var _last_touch_msec := -100000
var _press_log: PressRateLog = null
# Which Shift keys are down, by location (see _shift_press_is_fresh).
var _shift_held := {}
var _hitstop := 0.0
var _pause_elapsed := 0.0
var _pause_is_chain := false    # true = the longer "your move" pause
var _state_time := 0.0
var _paused_at_msec := 0


func _ready() -> void:
	# Main and the HUD keep running while the game is paused (to read the
	# resume press and show the pause screen); the world stops.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node in [level, fx, cam, freeze_effect, $EnemyLayer, $PlayerLayer]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	if PRESS_RATE_LOG:
		_press_log = PressRateLog.new()
		add_child(_press_log)
	if not OS.get_cmdline_user_args().is_empty():
		debug = DebugTools.new()
		debug.main = self
		add_child(debug)
	player.x = START_X
	level.start_x = START_X
	level.enemy_parent = $EnemyLayer
	level.ensure_generated(player.x)
	cam.snap(player.x)
	best_score = _load_best()
	hud.show_start(best_score)


func score() -> int:
	return int(distance) + kill_score


func begin() -> void:
	state = State.PLAYING
	player.running = true
	hud.hide_message()
	hud.set_pause_button_visible(true)


# --- input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Only real new presses do anything: no key repeats, no fake click after a tap.
	if not _is_fresh_press(event):
		return
	if get_tree().paused:
		# Any key, click or tap resumes (it doesn't also teleport).
		if _is_press(event):
			get_viewport().set_input_as_handled()
			if Time.get_ticks_msec() - _paused_at_msec >= RESUME_GUARD * 1000.0:
				_set_paused(false)
		return
	if state == State.PLAYING and (event.is_action_pressed("pause") or _is_pause_button_press(event)):
		get_viewport().set_input_as_handled()
		_set_paused(true)
		return
	var button := _button_from_event(event)
	if button == Rules.Move.NONE:
		return
	if _press_log:
		_press_log.record("forward" if button == Rules.Move.FORWARD else "vertical")
	get_viewport().set_input_as_handled()
	match state:
		State.READY:
			if not hud.is_portrait():
				_request_fullscreen()
				begin()
		State.PLAYING:
			if not _pending_forward and not _pending_vertical:
				_pending_frames = DIAGONAL_WINDOW_FRAMES
			if button == Rules.Move.FORWARD:
				_pending_forward = true
			else:
				_pending_vertical = true
			# Skip the rest of the kill pause.
			_hitstop = minf(_hitstop, maxf(KILL_PAUSE_MIN - _pause_elapsed, 0.0))
		State.OVER:
			if _state_time >= RETRY_DELAY:
				get_tree().reload_current_scene()


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	if value:
		_paused_at_msec = Time.get_ticks_msec()
		_clear_pending()
	hud.show_paused(value)


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
	return (touch or click) and hud.pause_button_contains(event.position)


## Must run inside an input event: browsers only allow fullscreen on a tap/press.
## iPhone Safari never allows it; there, "Add to Home Screen" gives fullscreen.
func _request_fullscreen() -> void:
	if OS.has_feature("web") and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Left half of the screen = vertical, right half = forward.
## Returns Rules.Move.FORWARD, Rules.Move.VERTICAL or Rules.Move.NONE.
func _button_from_event(event: InputEvent) -> int:
	if event is InputEventScreenTouch and event.pressed:
		return _button_for_screen_x(event.position.x)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return _button_for_screen_x(event.position.x)
	if event.is_action_pressed("tp_vertical"):
		return Rules.Move.VERTICAL
	if event.is_action_pressed("tp_forward"):
		return Rules.Move.FORWARD
	return Rules.Move.NONE


func _button_for_screen_x(screen_x: float) -> int:
	return Rules.Move.VERTICAL if screen_x < get_viewport().get_visible_rect().size.x * 0.5 else Rules.Move.FORWARD


func _clear_pending() -> void:
	_pending_forward = false
	_pending_vertical = false
	_pending_frames = 0


## The move to make this frame from the buttons pressed, waiting a few
## frames after a single press in case the other button follows (diagonal).
func _take_pending_move() -> int:
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
			if hud.is_portrait():
				pass
			elif _hitstop > 0.0:
				_hitstop -= delta
				_pause_elapsed += delta
			else:
				_step()
				moving = state == State.PLAYING
		State.DYING:
			player.animate_death(delta)
			if _state_time >= DEATH_ANIM_TIME:
				_game_over()

	_update_pause_visuals()
	var run_px := Rules.RUN_SPEED * Rules.TILE if moving else 0.0
	cam.follow(player.x, run_px, delta)
	level.set_view(cam.left(), cam.visible_world_size())
	hud.set_stats(score(), distance, chain, chain_timer / Rules.COMBO_WINDOW)


func _update_pause_visuals() -> void:
	var paused := state == State.PLAYING and _hitstop > 0.0
	var flashing := paused and INVERT_FLASH and _pause_elapsed < INVERT_TIME
	var chain_pause := paused and _pause_is_chain
	freeze_effect.set_state(1.0 if flashing else 0.0, 1.0 if chain_pause and not flashing else 0.0)
	fx.frozen = paused and _pause_elapsed >= FX_FREEZE_AFTER
	player.markers_lit = chain_pause


func _step() -> void:
	var move := debug.think() if debug and debug.bot else _take_pending_move()

	# 1. teleport (ignored while on cooldown)
	if move != Rules.Move.NONE and player.cooldown == 0:
		_teleport(move)
		if _hitstop > 0.0:
			return   # killed: stay exactly on the enemy, so the markers line up

	# 2. run
	player.x += Rules.RUN_SPEED / Rules.PHYSICS_FPS
	distance = player.x - START_X

	# 3. running into an enemy in your row
	if not level.enemies_at(player.x, Rules.HIT_RADIUS, player.row).is_empty():
		_die("hit")
		return

	# 4. timers
	if player.cooldown > 0:
		player.cooldown -= 1
	if chain > 0:
		chain_timer -= 1.0 / Rules.PHYSICS_FPS
		if chain_timer <= 0.0:
			_end_chain()

	level.ensure_generated(player.x)
	level.prune(cam.left() / Rules.TILE - 2.0)


func _teleport(move: int) -> void:
	var from := Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row))
	var to_x := player.x + Rules.move_dx(move)
	var to_row := (1 - player.row) if Rules.move_flips_row(move) else player.row
	var hit := level.enemies_at(to_x, Rules.KILL_RADIUS, to_row)
	if not hit.is_empty():
		# Land exactly on the enemy you hit, so chains can't drift.
		var target := hit[0]
		for e in hit:
			if absf(e.tile_x - to_x) < absf(target.tile_x - to_x):
				target = e
		to_x = target.tile_x
	player.x = to_x
	player.row = to_row
	distance = to_x - START_X
	var to := Vector2(to_x * Rules.TILE, Rules.body_center_y(to_row))
	fx.teleport_trail(from, to)

	if hit.is_empty():
		player.cooldown = Rules.cooldown_frames(Rules.RUN_SPEED)
		fx.landing_ring(to)
	else:
		player.cooldown = 0
		for e in hit:
			_kill(e)
		_pause_is_chain = _chain_target_in_reach(to_x, to_row)
		_hitstop = KILL_PAUSE if _pause_is_chain else KILL_HIT
		_pause_elapsed = 0.0
		if _pause_is_chain:
			cam.punch(to)


## True if a live enemy is under any marker at this spot, i.e. one more
## press right now would chain another kill.
func _chain_target_in_reach(x: float, row: int) -> bool:
	for move in [Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL]:
		var tx: float = x + Rules.move_dx(move)
		var trow: int = (1 - row) if Rules.move_flips_row(move) else row
		if not level.enemies_at(tx, Rules.KILL_RADIUS, trow).is_empty():
			return true
	return false


func _kill(e: Enemy) -> void:
	e.die()
	kills += 1
	chain += 1
	best_chain = maxi(best_chain, chain)
	chain_timer = Rules.COMBO_WINDOW
	var points := Rules.KILL_POINTS * chain
	kill_score += points

	var c := mini(chain, 6)
	var pos := Vector2(e.tile_x * Rules.TILE, Rules.body_center_y(e.row))
	cam.shake(0.06, 4.0 + 1.5 * c)   # only during the flash, so the freeze reads as still
	fx.kill_burst(pos, chain)
	if Hud.SHOW_SCORE_UI:
		fx.text(pos - Vector2(0, 60), "+%d" % points, 22 + 2 * c, Color(1, 0.95, 0.8))


func _end_chain() -> void:
	if Hud.SHOW_SCORE_UI and chain >= 3:
		fx.text(Vector2(player.x * Rules.TILE, Rules.body_center_y(player.row) - Rules.TILE * 1.7), "CHAIN x%d" % chain, 30, Color(1, 0.7, 0.4))
	chain = 0
	chain_timer = 0.0


func _die(kind: String) -> void:
	state = State.DYING
	hud.set_pause_button_visible(false)
	_state_time = 0.0
	player.running = false
	player.die(kind)
	cam.shake(0.3, 12.0)
	hud.flash(Color(1, 0.2, 0.2, 0.35), 0.3)
	if debug:
		debug.on_death(kind)


func _game_over() -> void:
	state = State.OVER
	_state_time = 0.0
	var final_score := score()
	var new_best := final_score > best_score
	if new_best:
		best_score = final_score
		_save_best(best_score)
	hud.show_game_over({
		"distance": distance, "kills": kills, "best_chain": best_chain,
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
	cfg.set_value("scores", "best", value)
	cfg.save(SAVE_PATH)

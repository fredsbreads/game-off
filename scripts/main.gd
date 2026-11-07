extends Node2D
## Game flow, input, scoring and the per-frame rules.
##
## The per-frame order in _step() must match ChunkSolver.step(), so the
## chunk validator's "this is survivable" proof applies to the real game.

enum State { READY, PLAYING, DYING, OVER }

const START_X := 3.0
const HITSTOP_BASE := 0.05
const HITSTOP_PER_CHAIN := 0.01
const DEATH_ANIM_TIME := 0.7
const RETRY_DELAY := 0.5
const SAVE_PATH := "user://save.cfg"

@onready var level: Level = $Level
@onready var player: Player = $Player
@onready var cam: CameraRig = $Camera
@onready var fx: Fx = $FX
@onready var hud: Hud = $HUD

var state := State.READY
var distance := 0.0
var kills := 0
var kill_score := 0
var chain := 0
var chain_timer := 0.0
var best_chain := 0
var best_score := 0
var debug: DebugTools = null

var _queued_jump := 0.0
var _hitstop := 0.0
var _state_time := 0.0


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		debug = DebugTools.new()
		debug.main = self
		add_child(debug)
	player.x = START_X
	level.start_x = START_X
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


# --- input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var jump := _jump_from_event(event)
	if jump == 0.0:
		return
	get_viewport().set_input_as_handled()
	match state:
		State.READY:
			if not hud.is_portrait():
				begin()
		State.PLAYING:
			if _queued_jump == 0.0:
				_queued_jump = jump
		State.OVER:
			if _state_time >= RETRY_DELAY:
				get_tree().reload_current_scene()


## Left half of the screen = short, right half = long.
func _jump_from_event(event: InputEvent) -> float:
	if event is InputEventScreenTouch and event.pressed:
		return _jump_for_screen_x(event.position.x)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return _jump_for_screen_x(event.position.x)
	if event.is_action_pressed("tp_short"):
		return Rules.SHORT
	if event.is_action_pressed("tp_long"):
		return Rules.LONG
	return 0.0


func _jump_for_screen_x(screen_x: float) -> float:
	return Rules.SHORT if screen_x < get_viewport().get_visible_rect().size.x * 0.5 else Rules.LONG


# --- per frame -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_state_time += delta
	var moving := false
	match state:
		State.PLAYING:
			if hud.is_portrait():
				pass
			elif _hitstop > 0.0:
				_hitstop -= delta
			else:
				_step()
				moving = state == State.PLAYING
		State.DYING:
			player.animate_death(delta)
			if _state_time >= DEATH_ANIM_TIME:
				_game_over()

	var run_px := Rules.speed_at(distance) * Rules.TILE if moving else 0.0
	cam.follow(player.x, run_px, delta)
	level.set_view(cam.left(), get_viewport_rect().size)
	hud.set_stats(score(), distance, chain, chain_timer / Rules.COMBO_WINDOW)


func _step() -> void:
	if debug and _queued_jump == 0.0:
		_queued_jump = debug.think()
	var jump := _queued_jump
	_queued_jump = 0.0

	# 1. teleport (ignored while on cooldown)
	if jump > 0.0 and player.cooldown == 0:
		_teleport(jump)
		if state != State.PLAYING:
			return

	# 2. run
	player.x += Rules.speed_at(player.x - START_X) / Rules.PHYSICS_FPS
	distance = player.x - START_X

	# 3. hazards and enemies
	if Rules.is_hazard(level.tile_at(player.x)):
		_die("fall")
		return
	if not level.enemies_at(player.x, Rules.HIT_RADIUS).is_empty():
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


func _teleport(dist: float) -> void:
	var from := player.x
	var to := from + dist
	player.x = to
	distance = to - START_X
	fx.teleport_trail(from, to)

	if Rules.is_hazard(level.tile_at(to)):
		_die("fall")
		return

	var hit := level.enemies_at(to, Rules.KILL_RADIUS)
	if hit.is_empty():
		player.cooldown = Rules.cooldown_frames(Rules.speed_at(to - START_X))
		fx.landing_ring(to)
		# Clearing a hazard keeps the chain alive (doesn't add to it).
		if chain > 0 and level.hazard_between(from, to):
			chain_timer = Rules.COMBO_WINDOW
	else:
		player.cooldown = 0
		for e in hit:
			_kill(e)


func _kill(e: Enemy) -> void:
	e.die()
	kills += 1
	chain += 1
	best_chain = maxi(best_chain, chain)
	chain_timer = Rules.COMBO_WINDOW
	var points := Rules.KILL_POINTS * chain
	kill_score += points

	var c := mini(chain, 6)
	_hitstop = HITSTOP_BASE + HITSTOP_PER_CHAIN * c
	cam.shake(0.15, 4.0 + 1.5 * c)
	var pos := Vector2(e.tile_x * Rules.TILE, Rules.GROUND_Y - Rules.TILE * 0.45)
	fx.kill_burst(pos, chain)
	if Hud.SHOW_SCORE_UI:
		fx.text(pos - Vector2(0, 60), "+%d" % points, 22 + 2 * c, Color(1, 0.95, 0.8))
	hud.flash(Color(1, 1, 1, 0.08 + 0.025 * c), 0.1)


func _end_chain() -> void:
	if Hud.SHOW_SCORE_UI and chain >= 3:
		fx.text(Vector2(player.x * Rules.TILE, Rules.GROUND_Y - Rules.TILE * 2.2), "CHAIN x%d" % chain, 30, Color(1, 0.7, 0.4))
	chain = 0
	chain_timer = 0.0


func _die(kind: String) -> void:
	state = State.DYING
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

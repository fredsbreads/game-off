class_name DebugTools
extends Node
## Only created when the game is launched with user args after `--`, e.g.
##   godot --path . -- --bot --soak=3000 --seed=7
##
##   --bot          a ChunkSolver-driven bot plays the game
##   --autostart    start without pressing anything (and without the bot)
##   --soak=N       quit with "SOAK OK" once N metres are reached, or
##                  "SOAK FAIL" if the bot dies (exit code 1)
##   --seed=N       fixed level seed
##   --shots=DIR    save a screenshot every --shot-every frames (default 45)
##   --shot-count=N how many screenshots before quitting (default 8)

const PLAN_AHEAD_TILES := 24.0
const REPLAN_EVERY := 20
const KEEP_TAIL_FRAMES := 10

var main: Node
var bot := false
var autostart := false
var soak_target := 0.0
var shots_dir := ""
var shot_every := 45
var shot_count := 8

var _frame := 0
var _shots_taken := 0
var _plan: Array = []
var _predicted: Array = []
var _replan_in := 0
var _next_report := 500.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"bot": bot = true
			"autostart": autostart = true
			"soak": soak_target = float(value)
			"seed": main.level.set_seed(int(value))
			"shots": shots_dir = value
			"shot-every": shot_every = int(value)
			"shot-count": shot_count = int(value)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if (bot or autostart) and _frame == 30 and main.state == main.State.READY:
		main.begin()

	if soak_target > 0.0 and main.distance >= _next_report:
		print("  ... %d m, kills %d, best chain %d" % [main.distance, main.kills, main.best_chain])
		_next_report += 500.0
	if soak_target > 0.0 and main.distance >= soak_target:
		print("SOAK OK: %d m, kills %d, best chain %d, score %d" % [main.distance, main.kills, main.best_chain, main.score()])
		get_tree().quit(0)

	if shots_dir != "" and _frame % shot_every == 0 and _shots_taken < shot_count:
		_shots_taken += 1
		_save_shot.call_deferred(_shots_taken)


func _save_shot(n: int) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/shot_%02d.png" % [shots_dir, n]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	if n >= shot_count and soak_target <= 0.0:
		get_tree().quit(0)


## Called by main each playing frame; returns the jump to make (0 = none).
func think() -> float:
	if not bot:
		return 0.0
	# Never play out the tail of a plan: its last jump only has to reach the
	# goal, not survive what comes after it.
	if _plan.size() <= KEEP_TAIL_FRAMES or _replan_in <= 0:
		_replan()
	_replan_in -= 1
	if _plan.is_empty():
		return 0.0
	if soak_target > 0.0 and not _predicted.is_empty():
		var expect: Array = _predicted.pop_front()
		if absf(expect[0] - main.player.x) > 0.001 or expect[1] != main.player.cooldown:
			print("  MISMATCH predicted x=%.4f cd=%d actual x=%.4f cd=%d" % [expect[0], expect[1], main.player.x, main.player.cooldown])
	return _plan.pop_front()


func _replan() -> void:
	var px: float = main.player.x
	var enemy_x: Array[float] = []
	for e in main.level.enemies:
		if e.alive and e.tile_x > px - 1.0 and e.tile_x < px + PLAN_AHEAD_TILES + 8.0:
			enemy_x.append(e.tile_x)
	var result := ChunkSolver.search(main.level.tiles, enemy_x, px, main.player.cooldown,
		px + PLAN_AHEAD_TILES, func(_x: float) -> float: return Rules.RUN_SPEED)
	_plan = result["actions"]
	_predicted.clear()
	var st: Array = [px, main.player.cooldown, 0]
	for act in _plan:
		_predicted.append([st[0], st[1]])
		var nxt := ChunkSolver.step(main.level.tiles, enemy_x, st, act, func(_x: float) -> float: return Rules.RUN_SPEED)
		if nxt.is_empty():
			break
		st = nxt
	if not result["ok"] and soak_target > 0.0:
		print("  bot: no plan at x=%.2f cd=%d (%s)" % [px, main.player.cooldown, main.level.chunk_name_at(px)])
	_replan_in = REPLAN_EVERY


func on_death(kind: String) -> void:
	if soak_target > 0.0:
		print("SOAK FAIL: died (%s) at %.2f m in chunk %s" % [kind, main.distance, main.level.chunk_name_at(main.player.x)])
		get_tree().quit(1)

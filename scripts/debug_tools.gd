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
##   --level=N      start the run at level N

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
var _forced: int = Rules.Move.NONE


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
			"level":
				main.progression.level = int(value)
				main.level.level = int(value)
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
		print("SOAK OK: %d m, kills %d, best chain %d, level %d" % [main.distance, main.kills, main.best_chain, main.progression.level])
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


## Called by main each playing frame; returns the Rules.Move to make.
func think() -> int:
	if not bot:
		return Rules.Move.NONE
	if _forced != Rules.Move.NONE:
		var move := _forced
		_forced = Rules.Move.NONE
		_plan.clear()
		_replan_in = 0
		return move
	# Never play out the tail of a plan: its last jump only has to reach the
	# goal, not survive what comes after it.
	if _plan.size() <= KEEP_TAIL_FRAMES or _replan_in <= 0:
		_replan()
	_replan_in -= 1
	if _plan.is_empty():
		return Rules.Move.NONE
	if soak_target > 0.0 and not _predicted.is_empty():
		var expect: Array = _predicted.pop_front()
		if absf(expect[0] - main.player.x) > 0.001 or expect[1] != main.player.row or expect[2] != main.player.cooldown:
			print("  MISMATCH predicted x=%.4f row=%d cd=%d actual x=%.4f row=%d cd=%d" % [expect[0], expect[1], expect[2], main.player.x, main.player.row, main.player.cooldown])
	return _plan.pop_front()


func _replan() -> void:
	var px: float = main.player.x
	var near: Array[Vector2] = []
	var knights: Array = []
	var group := 0
	for e in main.level.enemies:
		if not e.alive or e.tile_x <= px - 1.0 or e.tile_x >= px + PLAN_AHEAD_TILES + 8.0:
			continue
		var k := e as Knight
		if k:
			# Every spot he'll still be in, in order (one entry each).
			for i in range(k.step_index, k.path.size()):
				near.append(k.path[i])
				knights.append(group)
			group += 1
		else:
			near.append(Vector2(e.tile_x, e.row))
			knights.append(-1)
	var start := [px, main.player.row, main.player.cooldown]
	var limit := px + PLAN_AHEAD_TILES + 30.0
	# Play like a person going for chains: try to kill every enemy in range,
	# and only fall back to just surviving if that's impossible.
	var goal := px + PLAN_AHEAD_TILES
	var wanted := 0
	for i in near.size():
		# A knight in range: all of him (his later spots can be further on).
		var first_of_knight := i
		while first_of_knight > 0 and knights[i] >= 0 and knights[first_of_knight - 1] == knights[i]:
			first_of_knight -= 1
		if near[first_of_knight].x < goal:
			wanted |= 1 << i
	var result := ChunkSolver.search(near, start, goal, limit, Rules.RUN_SPEED, 3000, wanted, knights)
	if not result["ok"]:
		result = ChunkSolver.search(near, start, goal, limit, Rules.RUN_SPEED, 3000, 0, knights)
	_plan = result["actions"]
	_predicted.clear()
	var st: Array = [px, main.player.row, main.player.cooldown, 0]
	for act in _plan:
		_predicted.append([st[0], st[1], st[2]])
		var nxt := ChunkSolver.step(near, st, act, Rules.RUN_SPEED, limit, knights)
		if nxt.is_empty():
			break
		st = nxt
	if not result["ok"] and soak_target > 0.0:
		print("  bot: no plan at x=%.2f row=%d (%s)" % [px, main.player.row, main.level.section_name_at(px)])
	_replan_in = REPLAN_EVERY


## main.gd: the bot chose a move during the "your move" freeze; it's made on
## the next playing frame, before the plan (which is then rebuilt).
func force_move(move: int) -> void:
	_forced = move
	_predicted.clear()


func on_level_up(level: int) -> void:
	if soak_target > 0.0:
		print("  LEVEL %d at %d m (kills %d)" % [level, main.distance, main.kills])


func on_death(kind: String) -> void:
	if soak_target > 0.0:
		print("SOAK FAIL: died (%s) at %.2f m in %s" % [kind, main.distance, main.level.section_name_at(main.player.x)])
		get_tree().quit(1)

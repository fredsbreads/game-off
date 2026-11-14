class_name ChunkSolver
extends RefCounted
## Brute-force search over every physics frame: "is there ANY sequence of
## presses that gets from the start to goal_x?" (optionally killing a given
## set of enemies on the way).
##
## It mirrors main.gd's per-frame order exactly:
##   1. optional teleport (only if cooldown is 0): forward, vertical or
##      diagonal. Landing on an enemy in the target row kills it, snaps you
##      exactly onto it and ends the frame there.
##   2. run forward one frame along your row
##   3. running into a live enemy in your row kills you
##   4. tick the cooldown down
##
## Enemies are Vector2(x, row). States are [x, row, cooldown, killed_mask].
##
## Used by tools/validate_patterns.gd to prove patterns chain, and by the
## debug bot to play the game for soak tests and screenshots.

const ACTIONS := [Rules.Move.NONE, Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL]
const MAX_STATES := 300000
const DEDUP_PER_TILE := 20.0    # positions within 0.05 tiles count as the same


## limit_x: teleports may not land at or past this (level not built there).
## required_kills: bitmask of enemies that must all be killed (0 = survive).
## Returns {"ok": bool, "actions": Array (one Move per frame)}.
static func search(enemies: Array[Vector2], start: Array, goal_x: float, limit_x: float, speed: float, max_frames: int = 3000, required_kills: int = 0) -> Dictionary:
	# Each history entry: [x, row, cooldown, killed_mask, parent_index, action]
	var first: Array = start.duplicate()
	first.append(0)
	first.append(-1)
	first.append(Rules.Move.NONE)
	var history: Array = [first]
	var frontier: Array[int] = [0]

	for _frame in max_frames:
		var seen := {}
		var next: Array[int] = []
		for index in frontier:
			var state: Array = history[index]
			for action in ACTIONS:
				var result := step(enemies, state, action, speed, limit_x)
				if result.is_empty():
					continue
				if required_kills != 0 and _left_required_behind(enemies, result, required_kills):
					continue   # passed a required enemy alive: can't go back for it
				result.append(index)
				result.append(action)
				history.append(result)
				var new_index := history.size() - 1
				if result[0] >= goal_x and (int(result[3]) & required_kills) == required_kills:
					return {"ok": true, "actions": _path(history, new_index)}
				# States at (almost) the same spot, row and kills are
				# interchangeable; keep the one that can teleport soonest.
				var key := "%d|%d|%d" % [roundi(result[0] * DEDUP_PER_TILE), result[1], result[3]]
				if seen.has(key):
					var slot: int = seen[key]
					var kept: Array = history[next[slot]]
					if int(kept[2]) <= int(result[2]):
						history.pop_back()
						continue
					next[slot] = new_index
					continue
				seen[key] = next.size()
				next.append(new_index)
		if next.is_empty() or history.size() > MAX_STATES:
			return {"ok": false, "actions": []}
		frontier = next
	return {"ok": false, "actions": []}


## One frame of the game rules. Returns [x, row, cooldown, killed_mask], or
## an empty array if the player dies or the action isn't allowed.
static func step(enemies: Array[Vector2], state: Array, move: int, speed: float, limit_x: float = INF) -> Array:
	var x: float = state[0]
	var row: int = state[1]
	var cooldown: int = state[2]
	var mask: int = state[3]

	if move != Rules.Move.NONE:
		if cooldown > 0:
			return []
		x += Rules.move_dx(move)
		if Rules.move_flips_row(move):
			row = 1 - row
		if x >= limit_x:
			return []
		var killed := false
		var snap_to := x
		for i in enemies.size():
			var bit := 1 << i
			var e := enemies[i]
			if (mask & bit) == 0 and int(e.y) == row and Rules.in_kill_zone(move, e.x, x):
				if not killed or absf(e.x - x) < absf(snap_to - x):
					snap_to = e.x
				mask |= bit
				killed = true
		if killed:
			return [snap_to, row, 0, mask]   # land exactly on it; no running this frame
		cooldown = Rules.cooldown_frames()

	x += speed / Rules.PHYSICS_FPS
	for i in enemies.size():
		var e := enemies[i]
		if (mask & (1 << i)) == 0 and int(e.y) == row and absf(e.x - x) < Rules.HIT_RADIUS:
			return []
	cooldown = maxi(cooldown - 1, 0)
	return [x, row, cooldown, mask]


## True if a required enemy is too far behind to ever be killed (teleports
## only go forward or straight across).
static func _left_required_behind(enemies: Array[Vector2], state: Array, required_kills: int) -> bool:
	var x: float = state[0]
	var mask: int = state[3]
	for i in enemies.size():
		var bit := 1 << i
		if (required_kills & bit) != 0 and (mask & bit) == 0 and enemies[i].x < x - Rules.KILL_RADIUS:
			return true
	return false


static func _path(history: Array, index: int) -> Array:
	var actions: Array = []
	while index > 0:
		var entry: Array = history[index]
		actions.push_front(entry[5])
		index = entry[4]
	return actions

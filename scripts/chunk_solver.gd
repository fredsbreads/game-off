class_name ChunkSolver
extends RefCounted
## Brute-force search over every physics frame: "is there ANY sequence of
## presses that survives from start_x to goal_x?"
##
## It mirrors main.gd's per-frame order exactly:
##   1. optional teleport (only if cooldown is 0), resolve the landing
##      (a kill snaps you exactly onto that enemy)
##   2. run forward one frame
##   3. check hazards and enemy collisions
##   4. tick the cooldown down
##
## Used by tools/validate_patterns.gd to prove patterns chain, and by the
## debug bot to play the game for soak tests and screenshots.

const ACTIONS := [0.0, Rules.SHORT, Rules.LONG]
const MAX_STATES := 200000
const DEDUP_PER_TILE := 20.0    # positions within 0.05 tiles count as the same


## speed_fn: Callable(x: float) -> tiles per second.
## Teleports that would land at or beyond tiles.size() are not allowed
## (that ground isn't known yet).
## required_kills: bitmask of enemies that must all be killed on the way
## (0 = just survive).
## Returns {"ok": bool, "actions": Array (one jump per frame, 0 = none)}.
static func search(tiles: PackedByteArray, enemies: Array[float], start_x: float, start_cooldown: int, goal_x: float, speed_fn: Callable, max_frames: int = 3000, required_kills: int = 0) -> Dictionary:
	# Each history entry: [x, cooldown, killed_mask, parent_index, action]
	var history: Array = [[start_x, start_cooldown, 0, -1, 0.0]]
	var frontier: Array[int] = [0]

	for _frame in max_frames:
		var seen := {}
		var next: Array[int] = []
		for index in frontier:
			var state: Array = history[index]
			for action in ACTIONS:
				var result := step(tiles, enemies, state, action, speed_fn)
				if result.is_empty():
					continue
				if required_kills != 0 and _left_required_behind(enemies, result, required_kills):
					continue   # passed a required enemy alive: can't go back for it
				result.append(index)
				result.append(action)
				history.append(result)
				var new_index := history.size() - 1
				if result[0] >= goal_x and (int(result[2]) & required_kills) == required_kills:
					return {"ok": true, "actions": _path(history, new_index)}
				# States at (almost) the same spot with the same kills are
				# interchangeable; keep the one that can teleport soonest.
				var key := "%d|%d" % [roundi(result[0] * DEDUP_PER_TILE), result[2]]
				if seen.has(key):
					var slot: int = seen[key]
					var kept: Array = history[next[slot]]
					if int(kept[1]) <= int(result[1]):
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


## One frame of the game rules. Returns [x, cooldown, killed_mask], or an
## empty array if the player dies or the action isn't allowed.
static func step(tiles: PackedByteArray, enemies: Array[float], state: Array, jump: float, speed_fn: Callable) -> Array:
	var x: float = state[0]
	var cooldown: int = state[1]
	var mask: int = state[2]
	var size := tiles.size()

	if jump > 0.0:
		if cooldown > 0:
			return []
		x += jump
		if x >= size:
			return []
		var killed := false
		var snap_to := x
		for i in enemies.size():
			var bit := 1 << i
			if (mask & bit) == 0 and absf(enemies[i] - x) < Rules.KILL_RADIUS:
				if not killed or absf(enemies[i] - x) < absf(snap_to - x):
					snap_to = enemies[i]
				mask |= bit
				killed = true
		if killed:
			x = snap_to   # land exactly on the enemy you hit
		elif Rules.is_hazard(tiles[int(x)]):
			return []
		cooldown = 0 if killed else Rules.cooldown_frames(float(speed_fn.call(x)))

	x += float(speed_fn.call(x)) / Rules.PHYSICS_FPS
	if x < size:
		if Rules.is_hazard(tiles[int(x)]):
			return []
		for i in enemies.size():
			if (mask & (1 << i)) == 0 and absf(enemies[i] - x) < Rules.HIT_RADIUS:
				return []
	cooldown = maxi(cooldown - 1, 0)
	return [x, cooldown, mask]


static func _left_required_behind(enemies: Array[float], state: Array, required_kills: int) -> bool:
	var x: float = state[0]
	var mask: int = state[2]
	for i in enemies.size():
		var bit := 1 << i
		if (required_kills & bit) != 0 and (mask & bit) == 0 and enemies[i] < x:
			return true
	return false


static func _path(history: Array, index: int) -> Array:
	var actions: Array = []
	while index > 0:
		var entry: Array = history[index]
		actions.push_front(entry[4])
		index = entry[3]
	return actions

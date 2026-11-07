class_name ChunkSolver
extends RefCounted
## Brute-force search over every physics frame: "is there ANY sequence of
## presses that survives from start_x to goal_x?"
##
## It mirrors main.gd's per-frame order exactly:
##   1. optional teleport (only if cooldown is 0), resolve the landing
##   2. run forward one frame
##   3. check hazards and enemy collisions
##   4. tick the cooldown down
##
## Used by tools/validate_chunks.gd to prove chunks are fair, and by the
## debug bot to play the game for soak tests and screenshots.

const ACTIONS := [0.0, Rules.SHORT, Rules.LONG]
const MAX_STATES := 200000


## speed_fn: Callable(x: float) -> tiles per second.
## Teleports that would land at or beyond tiles.size() are not allowed
## (that ground isn't known yet).
## Returns {"ok": bool, "actions": Array (one jump per frame, 0 = none)}.
static func search(tiles: PackedByteArray, enemies: Array[float], start_x: float, start_cooldown: int, goal_x: float, speed_fn: Callable, max_frames: int = 3000) -> Dictionary:
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
				result.append(index)
				result.append(action)
				history.append(result)
				var new_index := history.size() - 1
				if result[0] >= goal_x:
					return {"ok": true, "actions": _path(history, new_index)}
				var key := "%d|%d|%d" % [roundi(result[0] * 1000.0), result[1], result[2]]
				if seen.has(key):
					history.pop_back()
					continue
				seen[key] = true
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
		if Rules.is_hazard(tiles[int(x)]):
			return []
		var killed := false
		for i in enemies.size():
			var bit := 1 << i
			if (mask & bit) == 0 and absf(enemies[i] - x) < Rules.KILL_RADIUS:
				mask |= bit
				killed = true
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


static func _path(history: Array, index: int) -> Array:
	var actions: Array = []
	while index > 0:
		var entry: Array = history[index]
		actions.push_front(entry[4])
		index = entry[3]
	return actions

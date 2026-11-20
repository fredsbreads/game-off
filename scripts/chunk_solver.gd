class_name ChunkSolver
extends RefCounted
## Brute-force search over every physics frame: "is there ANY sequence of
## presses that gets from the start to goal_x?" (optionally killing a given
## set of enemies on the way).
##
## It mirrors main.gd's per-frame order exactly:
##   1. optional teleport (only if cooldown is 0): forward, vertical or
##      diagonal. Landing on an enemy in the target row kills it, snaps you
##      to STRIKE_OFFSET short of it and ends the frame there.
##   2. run forward one frame along your row
##   3. running into a live enemy in your row kills you
##   4. tick the cooldown down
##
## Enemies are Vector2(x, row). States are [x, row, cooldown, killed_mask,
## ninja_frames (running in a ninja's reach), alerted_mask (ninjas that have
## seen you ahead)]; the last two may be left off (0).
##
## Knights (optional `knights`, one entry per enemy: -1, or the knight's
## number) are listed as one entry per spot she'll be in, in order. A spot
## only exists once the one before it (same knight) is hit. And:
##   5. running on past a knight straight across from you (out of reach of
##      your across teleport) makes her teleport to you: you die
##   6. a knight you've hit is within a teleport of you while you run: same
##   7. a ninja (knight group >= Patterns.NINJA_GROUP) straight in front of you
##      in your row but too close to teleport to: he strikes (after running,
##      or where a teleport lands); and once he's seen you under your forward
##      marker, coming back under it does at once (a master, group >=
##      Patterns.MASTER_GROUP: the same for her diagonal, in the other row)
## (both checked after running, so chaining on from a kill never triggers it;
## teleporting past a knight is fine).
##
## Used by tools/validate_patterns.gd to prove patterns chain, and by the
## debug bot to play the game for soak tests and screenshots.

const ACTIONS := [Rules.Move.NONE, Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL]
const MAX_STATES := 300000
const DEDUP_PER_TILE := 20.0    # positions within 0.05 tiles count as the same


## limit_x: teleports may not land at or past this (level not built there).
## required_kills: bitmask of enemies that must all be killed (0 = survive).
## Returns {"ok": bool, "actions": Array (one Move per frame)}.
static func search(enemies: Array[Vector2], start: Array, goal_x: float, limit_x: float, speed: float, max_frames: int = 3000, required_kills: int = 0, knights: Array = []) -> Dictionary:
	# Each history entry: [x, row, cooldown, killed_mask, parent_index, action]
	var first: Array = start.duplicate()
	first.append(0)
	first.append(0)
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
				var result := step(enemies, state, action, speed, limit_x, knights)
				if result.is_empty():
					continue
				if required_kills != 0 and _left_required_behind(enemies, result, required_kills, knights):
					continue   # passed a required enemy alive: can't go back for it
				result.append(index)
				result.append(action)
				history.append(result)
				var new_index := history.size() - 1
				if result[0] >= goal_x and (int(result[3]) & required_kills) == required_kills:
					return {"ok": true, "actions": _path(history, new_index)}
				# States at (almost) the same spot, row and kills are
				# interchangeable; keep the one that can teleport soonest.
				var key := "%d|%d|%d|%d|%d" % [roundi(result[0] * DEDUP_PER_TILE), result[1], result[3], result[4], result[5]]
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


## One frame of the game rules. Returns [x, row, cooldown, killed_mask,
## ninja_frames, alerted_mask], or an empty array if the player dies or the
## action isn't allowed.
static func step(enemies: Array[Vector2], state: Array, move: int, speed: float, limit_x: float = INF, knights: Array = []) -> Array:
	var x: float = state[0]
	var row: int = state[1]
	var cooldown: int = state[2]
	var mask: int = state[3]
	var ninja_frames: int = state[4] if state.size() > 4 else 0
	var alerted: int = state[5] if state.size() > 5 else 0
	var x0 := x   # (where she was before this frame: for "came back into a ninja's reach")
	var row0 := row

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
			if (mask & bit) == 0 and exists(i, mask, knights) and int(e.y) == row and Rules.in_kill_zone(move, e.x, x):
				if not killed or absf(e.x - x) < absf(snap_to - x):
					snap_to = e.x
				mask |= bit
				killed = true
		if killed:
			# Land STRIKE_OFFSET short of it (no running this frame), except:
			# an across teleport never pulls you back unless that lets you
			# chain on (same rule as main.gd _teleport).
			snap_to -= Rules.STRIKE_OFFSET
			if move == Rules.Move.VERTICAL and snap_to < x and not _can_chain(enemies, mask, snap_to, row, knights):
				snap_to = x
			if _ninja_too_close(enemies, mask, snap_to, row, knights):
				return []   # landed right in front of a ninja she can't reach
			return [snap_to, row, 0, mask, 0, alerted | _ninjas_ahead(enemies, mask, snap_to, row, knights)]
		cooldown = Rules.cooldown_frames()

	var run_from := x
	x += speed / Rules.PHYSICS_FPS
	for i in enemies.size():
		var e := enemies[i]
		if (mask & (1 << i)) == 0 and exists(i, mask, knights) and int(e.y) == row and absf(e.x - x) < Rules.HIT_RADIUS:
			return []
	if knight_pounces(enemies, mask, run_from, x, row, knights) >= 0:
		return []
	# 7. ninjas straight ahead
	var before := _ninjas_ahead(enemies, mask, x0, row0, knights)
	var ahead := _ninjas_ahead(enemies, mask, x, row, knights)
	if (ahead & alerted & ~before) != 0:
		return []   # back under her marker for one that had seen her
	if _ninja_too_close(enemies, mask, x, row, knights):
		return []   # ran on past her chance to reach him
	alerted |= ahead
	cooldown = maxi(cooldown - 1, 0)
	return [x, row, cooldown, mask, ninja_frames, alerted]


## True if an un-hit ninja is straight in front of (x, row) but too close to
## teleport to.
static func _ninja_too_close(enemies: Array[Vector2], mask: int, x: float, row: int, knights: Array) -> bool:
	if knights.is_empty():
		return false
	for i in enemies.size():
		var g := int(knights[i])
		if not Patterns.is_ninja_group(g) or (mask & (1 << i)) != 0 or not exists(i, mask, knights):
			continue
		if prev_spot(i, knights) >= 0:
			continue   # hit already: the knight rules
		if Rules.ninja_too_close(enemies[i].x, int(enemies[i].y), x, row):
			return true
		if Patterns.is_master_group(g) and Rules.master_diag_too_close(enemies[i].x, int(enemies[i].y), x, row):
			return true
		if Patterns.is_shadow_group(g) and Rules.shadow_behind(enemies[i].x, int(enemies[i].y), x, row):
			return true
	return false


## Bits (by spot index) of the un-hit ninjas straight ahead of (x, row), in
## the forward teleport's reach.
static func _ninjas_ahead(enemies: Array[Vector2], mask: int, x: float, row: int, knights: Array) -> int:
	if knights.is_empty():
		return 0
	var bits := 0
	for i in enemies.size():
		var g := int(knights[i])
		if not Patterns.is_ninja_group(g) or (mask & (1 << i)) != 0 or not exists(i, mask, knights):
			continue
		if prev_spot(i, knights) >= 0:
			continue   # hit already: he's fighting her (the knight rules)
		var e := enemies[i]
		if Rules.ninja_ahead(e.x, int(e.y), x, row) or (Patterns.is_master_group(g) and Rules.master_diag_ahead(e.x, int(e.y), x, row)):
			bits |= 1 << i
	return bits


## True if any live enemy is under one of the markers at (x, row).
static func _can_chain(enemies: Array[Vector2], mask: int, x: float, row: int, knights: Array = []) -> bool:
	for move in [Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL]:
		var tx: float = x + Rules.move_dx(move)
		var trow: int = (1 - row) if Rules.move_flips_row(move) else row
		for i in enemies.size():
			var e := enemies[i]
			if (mask & (1 << i)) == 0 and exists(i, mask, knights) and int(e.y) == trow and Rules.in_kill_zone(move, e.x, tx):
				return true
	return false


## True if a required enemy is too far behind to ever be killed (teleports
## only go forward or straight across).
static func _left_required_behind(enemies: Array[Vector2], state: Array, required_kills: int, knights: Array = []) -> bool:
	var x: float = state[0]
	var mask: int = state[3]
	for i in enemies.size():
		var bit := 1 << i
		if (required_kills & bit) != 0 and (mask & bit) == 0 and exists(i, mask, knights) and enemies[i].x < x - Rules.kill_zone(Rules.Move.FORWARD).x:
			return true
	return false


## True if spot i is there right now: a plain enemy always is; a knight's spot
## once her spot before it (wherever it is in the chain: two teleporters'
## duels can interleave) has been hit.
static func exists(i: int, mask: int, knights: Array) -> bool:
	var j := prev_spot(i, knights)
	return j < 0 or (mask & (1 << j)) != 0


## The index of the same knight's spot before spot i, or -1 (a plain enemy,
## or her first spot).
static func prev_spot(i: int, knights: Array) -> int:
	if knights.is_empty() or int(knights[i]) < 0:
		return -1
	var g := int(knights[i])
	for j in range(i - 1, -1, -1):
		if int(knights[j]) == g:
			return j
	return -1


## The index of a knight that teleports to the player as the player runs from
## `from_x` to x in `row`, or -1: one straight across that the player runs on
## past (in reach of the player's across teleport, and now not), or one the
## player has hit that's within a teleport. Same rules as main.gd.
static func knight_pounces(enemies: Array[Vector2], mask: int, from_x: float, x: float, row: int, knights: Array) -> int:
	if knights.is_empty():
		return -1
	for i in enemies.size():
		var g := int(knights[i])
		if g < 0 or (mask & (1 << i)) != 0 or not exists(i, mask, knights):
			continue
		var e := enemies[i]
		var engaged := prev_spot(i, knights) >= 0
		if engaged and Rules.knight_in_reach(e.x - x):
			return i
		if Rules.knight_runs_past(e.x, int(e.y), from_x, x, row):
			return i
	return -1


static func _path(history: Array, index: int) -> Array:
	var actions: Array = []
	while index > 0:
		var entry: Array = history[index]
		actions.push_front(entry[7])
		index = entry[6]
	return actions

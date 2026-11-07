class_name Chunks
extends RefCounted
## Hand-made level pieces. The endless level is built by stitching these
## together in random order, picking harder ones the further you get.
##
## Map legend (one character = one tile):
##   .  ground
##   E  enemy standing on ground
##   _  pit
##   ^  spikes
##
## Run `tools/validate_chunks.gd` after editing (see README). It checks the
## format rules AND proves every chunk can be survived at both the slowest
## and fastest run speed.

const LIST := [
	# --- difficulty 1: one idea at a time -------------------------------
	{"name": "lone_enemy", "difficulty": 1, "map": "......E......."},
	{"name": "pit", "difficulty": 1, "map": "......____......"},
	{"name": "spikes", "difficulty": 1, "map": "......^^^^......"},
	{"name": "two_apart", "difficulty": 1, "map": ".....E........E......"},

	# --- difficulty 2: two ideas back to back --------------------------
	{"name": "pit_then_enemy", "difficulty": 2, "map": ".....____......E......"},
	{"name": "enemy_then_pit", "difficulty": 2, "map": ".....E....____......"},
	{"name": "short_chain", "difficulty": 2, "map": ".....E..E.........."},
	{"name": "long_chain", "difficulty": 2, "map": ".....E.....E........"},
	{"name": "wide_pit", "difficulty": 2, "map": "....._____......"},

	# --- difficulty 3: short chains, double hazards --------------------
	{"name": "double_pit", "difficulty": 3, "map": ".....____.....____....."},
	{"name": "triple_short", "difficulty": 3, "map": ".....E..E..E........"},
	{"name": "long_short", "difficulty": 3, "map": ".....E.....E..E......"},
	{"name": "pit_landing_enemy", "difficulty": 3, "map": ".....____.E........."},
	{"name": "spike_pit", "difficulty": 3, "map": ".....^^^^^.....____....."},

	# --- difficulty 4: hazards and enemies mixed -----------------------
	{"name": "guarded_pit", "difficulty": 4, "map": "......E____......."},
	{"name": "pit_chain", "difficulty": 4, "map": ".....____.E..E......"},
	{"name": "long_long", "difficulty": 4, "map": ".....E.....E.....E......"},
	{"name": "spike_gauntlet", "difficulty": 4, "map": ".....^^^^.....^^^^^.....____....."},

	# --- difficulty 5: long chains that switch distance ----------------
	{"name": "mixed_chain", "difficulty": 5, "map": ".....E..E.....E..E......."},
	{"name": "pit_enemy_pit", "difficulty": 5, "map": ".....____.E..____......"},
	{"name": "dense", "difficulty": 5, "map": ".....E..E..E..E..........."},
	{"name": "over_and_on", "difficulty": 5, "map": ".....____.E.....E..____......"},
]


## Turns a map string into tile data plus enemy positions (tile centres).
static func parse(map: String) -> Dictionary:
	var tiles := PackedByteArray()
	var enemies: Array[float] = []
	for i in map.length():
		match map[i]:
			"_":
				tiles.append(Rules.Tile.PIT)
			"^":
				tiles.append(Rules.Tile.SPIKES)
			"E":
				tiles.append(Rules.Tile.GROUND)
				enemies.append(i + 0.5)
			_:
				tiles.append(Rules.Tile.GROUND)
	return {"tiles": tiles, "enemies": enemies}


## Format rules only. Solvability is checked separately by ChunkSolver.
static func validate(map: String) -> Array[String]:
	var errors: Array[String] = []
	for i in map.length():
		if not "._^E".contains(map[i]):
			errors.append("unknown character '%s' at %d" % [map[i], i])
	if map.length() < Rules.EDGE_PADDING * 2 + 1:
		errors.append("too short")
		return errors
	for i in Rules.EDGE_PADDING:
		if map[i] != "." or map[map.length() - 1 - i] != ".":
			errors.append("needs %d plain ground tiles at both ends" % Rules.EDGE_PADDING)
			break

	var i := 0
	var last_hazard_end := -1
	while i < map.length():
		if map[i] == "_" or map[i] == "^":
			var start := i
			while i < map.length() and (map[i] == "_" or map[i] == "^"):
				i += 1
			var width := i - start
			if width < Rules.HAZARD_MIN or width > Rules.HAZARD_MAX:
				errors.append("hazard at %d is %d wide (must be %d-%d)" % [start, width, Rules.HAZARD_MIN, Rules.HAZARD_MAX])
			# A shorter gap is OK if an enemy sits in it: killing it resets the cooldown.
			var gap_has_enemy := last_hazard_end >= 0 and map.substr(last_hazard_end, start - last_hazard_end).contains("E")
			if last_hazard_end >= 0 and start - last_hazard_end < Rules.MIN_HAZARD_GAP and not gap_has_enemy:
				errors.append("hazard at %d is only %d tiles after the previous one (min %d)" % [start, start - last_hazard_end, Rules.MIN_HAZARD_GAP])
			last_hazard_end = i
		else:
			i += 1
	return errors

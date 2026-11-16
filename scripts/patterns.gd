class_name Patterns
extends RefCounted
## Enemy chains in step notation, for two rows (floor and ceiling).
##
## Levels 1-3 use the hand-made patterns in LIST. From level 4 on, chains
## are generated (see generate()). Which ones can spawn at a level, and how
## long generated chains are, is decided here; level.gd lays them out.
##
## A pattern is a chain of enemies. The first enemy is the entry; each step
## places the next enemy relative to the previous one (after a kill you're
## standing exactly where it was):
##
##   F    forward    same row, one forward teleport ahead (6)
##   V    vertical   other row, straight across (0)
##   D    diagonal   other row, one forward teleport ahead (6)
##   F+   forward beat    same row, run a little, then forward   (6 + WAIT)
##   V+   vertical beat   other row, run a little, then across   (0 + WAIT)
##   D+   diagonal beat   other row, run a little, then diagonal (6 + WAIT)
##   |    break      same row, BREAK tiles ahead (chain ends on purpose)
##
## A pattern's entry enemy is in the row the previous pattern ended in, so
## every pattern also appears mirrored. Patterns are separated by a BREAK.
##
## Run tools/validate_patterns.gd after editing: it checks the notation,
## proves every enemy in every pattern can be chained, flags duplicate
## layouts, and test-generates chains for many levels.

const WAIT := 3.0       # half a forward teleport
const BREAK := 10.0     # past forward reach, so a break is unmistakable

# Hand-made patterns for the opening levels. Each level adds its patterns
# to the previous level's (a two-level window: see pool_for_level()).
const LIST := [
	# Level 1: forward and diagonal, so both rows get used early.
	{"name": "forward_pair", "level": 1, "steps": "F"},
	{"name": "diagonal_pair", "level": 1, "steps": "D"},
	# Level 2: the stacked pair, followed by a forward.
	{"name": "across_then_forward", "level": 2, "steps": "V F"},
	{"name": "forward_then_across", "level": 2, "steps": "F V"},
	# Level 3: three-enemy chains across the rows.
	{"name": "forward_then_diagonal", "level": 3, "steps": "F D"},
	{"name": "diagonal_then_forward", "level": 3, "steps": "D F"},
	{"name": "zigzag", "level": 3, "steps": "D D"},
]

# From this level on, chains are generated instead of hand-made.
const FIRST_GENERATED_LEVEL := 4
const GENERATED_STEPS := ["F", "V", "D"]
# How often a level's own (new) patterns appear vs. the previous level's.
const NEW_PATTERN_WEIGHT := 2.0
const OLD_PATTERN_WEIGHT := 1.0

# Knights (see knight.gd). Level 9 opens with one alone, and every chain in
# it ends with one, so the level-up into 10 is always on a knight. From level
# 10 any enemy in a chain can be a knight: KNIGHT_CHANCE, plus
# KNIGHT_CHANCE_STEP for every level after that.
const KNIGHT_DEBUT_LEVEL := 9
const KNIGHT_CHANCE := 0.05
const KNIGHT_CHANCE_STEP := 0.03
# A knight's blinks: to any of her three landing spots (across and back is
# fine: the spot he left is empty).
const KNIGHT_STEPS := ["F", "V", "D"]

# "Maybe" for later: off-beat patterns (with a visual cue). Not spawned.
const MAYBE_BEATS := [
	{"name": "forward_beat", "steps": "F+"},
	{"name": "across_beat", "steps": "V+"},
	{"name": "beat_then_across", "steps": "F+ V"},
	{"name": "diagonal_beat_forward", "steps": "D+ F"},
	{"name": "forward_across_beat", "steps": "F V+ F"},
	{"name": "two_beats", "steps": "V+ D+"},
]


## [distance ahead, switches row?] for one step token, or [] if unknown.
static func step_shape(token: String) -> Array:
	match token:
		"F":
			return [Rules.FORWARD, false]
		"V":
			return [0.0, true]
		"D":
			return [Rules.FORWARD, true]
		"F+":
			return [Rules.FORWARD + WAIT, false]
		"V+":
			return [WAIT, true]
		"D+":
			return [Rules.FORWARD + WAIT, true]
		"|":
			return [BREAK, false]
	return []


## Enemies as Vector2(x relative to the entry, row relative to the entry:
## 0 = same row as the entry, 1 = the other row), plus notation errors.
static func parse(steps: String) -> Dictionary:
	var enemies: Array[Vector2] = [Vector2(0, 0)]
	var errors: Array[String] = []
	for token in steps.split(" ", false):
		var shape := step_shape(token)
		if shape.is_empty():
			errors.append("unknown step '%s'" % token)
			continue
		var prev: Vector2 = enemies.back()
		var row := (1 - int(prev.y)) if shape[1] else int(prev.y)
		var e := Vector2(prev.x + float(shape[0]), row)
		for other in enemies:
			if other == e:
				errors.append("step '%s' puts two enemies in the same spot" % token)
		enemies.append(e)
	return {"enemies": enemies, "errors": errors}


## The hand-made patterns that can spawn at `level` (1-3), each with a
## weight: this level's new patterns, plus the previous level's.
static func pool_for_level(level: int) -> Array:
	var pool: Array = []
	for p in LIST:
		var introduced: int = p["level"]
		if introduced == level:
			pool.append({"pattern": p, "weight": NEW_PATTERN_WEIGHT})
		elif introduced == level - 1:
			pool.append({"pattern": p, "weight": OLD_PATTERN_WEIGHT})
	return pool


## Generated chain lengths at `level` (enemies), inclusive: x-2 to x+2,
## never fewer than 3. No cap.
static func chain_length_range(level: int) -> Vector2i:
	return Vector2i(maxi(3, level - 2), maxi(3, level + 2))


## The average number of enemies in a chain at `level` (used to size the
## progression bar).
static func average_chain_length(level: int) -> float:
	if level >= FIRST_GENERATED_LEVEL:
		var r := chain_length_range(level)
		return (r.x + r.y) / 2.0
	var total := 0.0
	var weights := 0.0
	for entry in pool_for_level(level):
		var parsed := parse(entry["pattern"]["steps"])
		total += float(entry["weight"]) * parsed["enemies"].size()
		weights += float(entry["weight"])
	return total / weights if weights > 0.0 else 2.0


## The chance that an enemy in a generated chain at `level` is a knight.
static func knight_chance(level: int) -> float:
	if level <= KNIGHT_DEBUT_LEVEL:
		return 0.0
	return KNIGHT_CHANCE + KNIGHT_CHANCE_STEP * (level - KNIGHT_DEBUT_LEVEL - 1)


## A random chain for a generated level: a length from chain_length_range,
## each step F, V or D with equal odds. Knights (see knight_chance; in level
## 9 the last enemy always is one) take KNIGHT_HITS_MIN-MAX spots: where he
## starts, then one blink per hit to a random landing spot. The length counts
## spots (every hit), so knights don't make chains any longer.
## Returns {enemies, knights, steps, name}: `knights` has one entry per spot,
## -1 for a plain enemy or the knight's number (his spots are consecutive).
## Chainable by construction: every step puts the next spot exactly under a
## marker, and no two things can be in one spot at the same time (see
## _overlaps). The validator runs the full solver check on samples.
static func generate(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var lengths := chain_length_range(level)
	var chance := knight_chance(level)
	for _attempt in 40:
		var n := rng.randi_range(lengths.x, lengths.y)
		# Spend n spots: a plain enemy takes one, a knight his hits.
		var hits: Array[int] = []   # per enemy: 1, or a knight's hits
		var last_knight := 0
		if level == KNIGHT_DEBUT_LEVEL:
			last_knight = rng.randi_range(Rules.KNIGHT_HITS_MIN, Rules.KNIGHT_HITS_MAX)
		var left := n - last_knight
		while left > 0:
			if left >= Rules.KNIGHT_HITS_MIN and rng.randf() < chance:
				var h := mini(rng.randi_range(Rules.KNIGHT_HITS_MIN, Rules.KNIGHT_HITS_MAX), left)
				hits.append(h)
				left -= h
			else:
				hits.append(1)
				left -= 1
		if last_knight > 0:
			hits.append(last_knight)
		var built := _build(hits, rng)
		if not built.is_empty():
			built["name"] = "generated L%d: %s" % [level, built["steps"]]
			return built
	push_error("couldn't generate a chainable chain for level %d" % level)
	var fallback := parse("F")
	fallback["name"] = "fallback"
	fallback["steps"] = "F"
	fallback["knights"] = [-1, -1]
	return fallback


## A lone knight (the start of level 9).
static func knight_alone(rng: RandomNumberGenerator) -> Dictionary:
	for _attempt in 40:
		var built := _build([rng.randi_range(Rules.KNIGHT_HITS_MIN, Rules.KNIGHT_HITS_MAX)], rng)
		if not built.is_empty():
			built["name"] = "knight alone: %s" % built["steps"]
			return built
	return {}


## Lays out one chain: `hits` has one entry per enemy, 1 for a plain enemy or
## a knight's number of hits. Returns {} if the random steps put two things in
## one spot.
static func _build(hits: Array[int], rng: RandomNumberGenerator) -> Dictionary:
	var enemies: Array[Vector2] = []
	var knights: Array[int] = []
	var tokens: PackedStringArray = []
	var group := 0
	for i in hits.size():
		if i > 0:
			var token: String = GENERATED_STEPS[rng.randi_range(0, GENERATED_STEPS.size() - 1)]
			enemies.append(_apply(enemies.back(), token))
			tokens.append(token)
		else:
			enemies.append(Vector2(0, 0))
		if hits[i] <= 1:
			knights.append(-1)
			continue
		knights.append(group)
		tokens.append("K(")
		for h in hits[i] - 1:
			var blink: String = KNIGHT_STEPS[rng.randi_range(0, KNIGHT_STEPS.size() - 1)]
			enemies.append(_apply(enemies.back(), blink))
			knights.append(group)
			tokens.append(blink.to_lower())
		tokens.append(")")
		group += 1
	if _overlaps(enemies, knights):
		return {}
	return {"enemies": enemies, "knights": knights, "steps": " ".join(tokens)}


static func _apply(prev: Vector2, token: String) -> Vector2:
	var shape := step_shape(token)
	var row := (1 - int(prev.y)) if shape[1] else int(prev.y)
	return Vector2(prev.x + float(shape[0]), row)


## True if two things would be in one spot at the same time. A knight's later
## spots only exist after everything before him is dead, so they may reuse
## those spots (and his own earlier ones); nothing else may share a spot.
static func _overlaps(enemies: Array[Vector2], knights: Array[int]) -> bool:
	for j in enemies.size():
		var later_knight_spot := knights[j] >= 0 and j > 0 and knights[j - 1] == knights[j]
		for i in j:
			if enemies[i] == enemies[j] and not later_knight_spot:
				return true
	return false


## True if every enemy in the chain can be killed, arriving with BREAK tiles
## of run-up in either row (the worse case: the row the entry isn't in).
static func is_chainable(shape: Array, knights: Array = []) -> bool:
	for entry_row in [Rules.Row.FLOOR, Rules.Row.CEILING]:
		var enemies: Array[Vector2] = []
		for rel in shape:
			var e: Vector2 = rel
			var row: int = entry_row if int(e.y) == 0 else 1 - entry_row
			enemies.append(Vector2(BREAK + e.x, row))
		var length: float = enemies.back().x + BREAK
		var all_killed := (1 << enemies.size()) - 1
		var start := [0.0, 1 - entry_row, Rules.cooldown_frames()]
		var result := ChunkSolver.search(enemies, start, length, length, Rules.RUN_SPEED, 3000, all_killed, knights)
		if not result["ok"]:
			return false
	return true

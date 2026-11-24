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
# The gap between two chains: BREAK, shorter at a slower speed (Rules.walk_scale),
# but never under BREAK_MIN (still past a forward teleport's reach and its kill
# zone, FORWARD + KILL_AHEAD + ENEMY_HALF_WIDTH = 7.55).
const BREAK_MIN := 8.0


static func break_gap(level: int) -> float:
	return maxf(BREAK * Rules.walk_scale(level), BREAK_MIN)

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

# Knights (see knight.gd). Her debut level opens with one alone; from then on
# any enemy in a generated chain can be a knight: KNIGHT_CHANCE at the debut
# level, plus KNIGHT_CHANCE_STEP for every level after that.
const KNIGHT_DEBUT_LEVEL := 5
const KNIGHT_CHANCE := 0.05
const KNIGHT_CHANCE_STEP := 0.02
# Teleporters (knights and ninjas together) never get more likely than this.
const TELEPORTER_CHANCE_MAX := 0.30
# Ninjas (see ninja.gd): his debut level opens with one alone; from then on a
# teleporter in a generated chain is a ninja with NINJA_SHARE at the debut
# level, plus NINJA_SHARE_STEP a level, up to NINJA_SHARE_MAX (the rest are
# knights). He takes knights' places, so teleporters don't get more common.
const NINJA_DEBUT_LEVEL := 10
const NINJA_SHARE := 0.25
const NINJA_SHARE_STEP := 0.05
const NINJA_SHARE_MAX := 0.5
# Masters (see master.gd): his debut level opens with one alone; from then on
# a teleporter is a master with MASTER_SHARE at the debut level, rising
# evenly to a third by MASTER_FULL_LEVEL (and staying there). The rest are
# knights and ninjas as above (from level 15, half and half).
const MASTER_DEBUT_LEVEL := 15
const MASTER_SHARE := 0.2
const MASTER_FULL_LEVEL := 20
# A teleporter's group number in a chain's `knights` list: a knight's is
# under NINJA_GROUP, a ninja's NINJA_GROUP or more, a master's MASTER_GROUP
# or more (a master has every ninja rule too): see is_ninja_group().
const NINJA_GROUP := 1000
const MASTER_GROUP := 2000
const SHADOW_GROUP := 3000   # (the Shadow: none of the others' rules)
# The Shadow (see shadow.gd): her own chain, alone. Her debut level opens
# with her; after it, a generated chain is hers with SHADOW_CHANCE, rising by
# SHADOW_CHANCE_STEP a level up to SHADOW_CHANCE_MAX. She fights in rounds
# (three at her debut, then two or three): each round she blinks SHADOW_BLINKS_MIN-MAX times
# through the three columns on screen (each a move the player could make),
# leaving a remnant on every spot but the last, where she waits.
const SHADOW_DEBUT_LEVEL := 20
const SHADOW_CHANCE := 0.1
const SHADOW_CHANCE_STEP := 0.02
const SHADOW_CHANCE_MAX := 0.25
const SHADOW_BLINKS_MIN := 4
const SHADOW_BLINKS_MAX := 5
## (Testing) every generated chain is the Shadow's.
static var force_shadows := false
const SHADOW_DEBUT_ROUNDS := 3
const SHADOW_ROUNDS_MIN := 2
const SHADOW_ROUNDS_MAX := 3
# Two teleporters side by side in a chain: this often their duels interleave
# (see _build): you fight both at once, but each one's every blink is one move
# from where you hit her, so neither needs the other to reach her next spot.
const PAIR_CHANCE := 0.8
# A knight's blinks: to any of her three landing spots, but never back to a
# spot she's been on (so never across twice in a row, see _overlaps).
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
## The chance that an enemy slot is a teleporter (a knight or a ninja).
static func knight_chance(level: int) -> float:
	if level < KNIGHT_DEBUT_LEVEL:
		return 0.0
	return minf(KNIGHT_CHANCE + KNIGHT_CHANCE_STEP * (level - KNIGHT_DEBUT_LEVEL), TELEPORTER_CHANCE_MAX)


## The share of teleporters that are ninjas.
static func ninja_share(level: int) -> float:
	if level < NINJA_DEBUT_LEVEL:
		return 0.0
	return minf(NINJA_SHARE + NINJA_SHARE_STEP * (level - NINJA_DEBUT_LEVEL), NINJA_SHARE_MAX)


## The share of teleporters that are masters.
static func master_share(level: int) -> float:
	if level < MASTER_DEBUT_LEVEL:
		return 0.0
	var t := clampf(float(level - MASTER_DEBUT_LEVEL) / float(MASTER_FULL_LEVEL - MASTER_DEBUT_LEVEL), 0.0, 1.0)
	return lerpf(MASTER_SHARE, 1.0 / 3.0, t)


## A ninja or a master (they both watch straight ahead).
static func is_ninja_group(group: int) -> bool:
	return group >= NINJA_GROUP and group < SHADOW_GROUP


static func is_master_group(group: int) -> bool:
	return group >= MASTER_GROUP and group < SHADOW_GROUP


static func is_shadow_group(group: int) -> bool:
	return group >= SHADOW_GROUP


## The chance that a generated chain is the Shadow's (after her debut).
static func shadow_chance(level: int) -> float:
	if level <= SHADOW_DEBUT_LEVEL:
		return 0.0
	return minf(SHADOW_CHANCE + SHADOW_CHANCE_STEP * (level - SHADOW_DEBUT_LEVEL - 1), SHADOW_CHANCE_MAX)


## The Shadow's chain: her spots, one a round apart (where you first clash
## with her, then where each round ends), and `shadow_paths`: for each round,
## the spots she blinks through (the last is where she waits; the others get
## her remnants), each one move on from the one before, never back. Relative
## to her first spot, like `enemies`.
static func shadow_chain(level: int, rng: RandomNumberGenerator, debut := false) -> Dictionary:
	var spots: Array[Vector2] = [Vector2(0, 0)]
	var paths: Array = []
	# Rounds: three the first time (her debut); after that, two or three.
	var rounds := SHADOW_DEBUT_ROUNDS if debut else rng.randi_range(SHADOW_ROUNDS_MIN, SHADOW_ROUNDS_MAX)
	for r in rounds:
		var blinks := rng.randi_range(SHADOW_BLINKS_MIN, SHADOW_BLINKS_MAX)
		# Three columns: an across in each (optional), a forward or diagonal
		# between them; as many acrosses as the blinks leave room for.
		var acrosses := [true, true, true]
		if blinks == 4:
			acrosses[rng.randi_range(0, 2)] = false
		var tokens: Array[String] = []
		for c in 3:
			if acrosses[c]:
				tokens.append("V")
			if c < 2:
				tokens.append(["F", "D"][rng.randi_range(0, 1)])
		var path: Array[Vector2] = []
		var at: Vector2 = spots.back()
		for t in tokens:
			at = _apply(at, t)
			path.append(at)
		paths.append(path)
		spots.append(at)
	var knights: Array[int] = []
	for i in spots.size():
		knights.append(SHADOW_GROUP)
	var name := "%s: %d rounds" % ["shadow alone" if debut else "shadow", paths.size()]
	# Empty run after her: the next chain doesn't show while she's fought.
	return {"enemies": spots, "knights": knights, "steps": "S(%d)" % paths.size(), "name": name, "shadow_paths": paths,
		"tail": Rules.FORWARD * 2.0}


## A random chain for a generated level: a length from chain_length_range,
## each step F, V or D with equal odds. Knights (see knight_chance) take
## KNIGHT_HITS_MIN-MAX spots (a ninja NINJA_HITS_MIN-MAX): where she
## starts, then one blink per hit to a random landing spot. The length counts
## spots (every hit), so knights don't make chains any longer.
## Returns {enemies, knights, steps, name}: `knights` has one entry per spot,
## -1 for a plain enemy or the knight's number (her spots are consecutive).
## Chainable by construction: every step puts the next spot exactly under a
## marker, and no two things can be in one spot at the same time (see
## _overlaps). The validator runs the full solver check on samples.
## knights = false: no knights in it (before her debut); ninjas = false: no
## ninjas (before his); masters = false: no masters.
static func generate(level: int, rng: RandomNumberGenerator, knights := true, ninjas := true, masters := true, shadows := true) -> Dictionary:
	if shadows and (force_shadows or rng.randf() < shadow_chance(level)):
		return shadow_chain(level, rng)
	var lengths := chain_length_range(level)
	var chance := knight_chance(level) if knights else 0.0
	var share := ninja_share(level) if ninjas else 0.0
	var mshare := master_share(level) if masters else 0.0
	for _attempt in 40:
		var n := rng.randi_range(lengths.x, lengths.y)
		# Spend n spots: a plain enemy takes one, a knight her hits.
		var hits: Array[int] = []   # per enemy: 1, or a knight's hits (negative: a ninja's)
		var left := n
		while left > 0:
			if left >= Rules.KNIGHT_HITS_MIN and rng.randf() < chance:
				# A master (5-6 hits), a ninja (4-5) or a knight (3-4), each only
				# if there's room for it (else the next one down).
				if left >= Rules.MASTER_HITS_MIN and rng.randf() < mshare:
					var mh := mini(rng.randi_range(Rules.MASTER_HITS_MIN, Rules.MASTER_HITS_MAX), left)
					hits.append(-1000 - mh)
					left -= mh
				elif left >= Rules.NINJA_HITS_MIN and rng.randf() < share:
					var nh := mini(rng.randi_range(Rules.NINJA_HITS_MIN, Rules.NINJA_HITS_MAX), left)
					hits.append(-nh)
					left -= nh
				else:
					var h := mini(rng.randi_range(Rules.KNIGHT_HITS_MIN, Rules.KNIGHT_HITS_MAX), left)
					hits.append(h)
					left -= h
			else:
				hits.append(1)
				left -= 1
		var built := _build(hits, rng, PAIR_CHANCE)
		if not built.is_empty():
			built["name"] = "generated L%d: %s" % [level, built["steps"]]
			return built
	push_error("couldn't generate a chainable chain for level %d" % level)
	var fallback := parse("F")
	fallback["name"] = "fallback"
	fallback["steps"] = "F"
	fallback["knights"] = [-1, -1]
	return fallback


## A lone knight (the start of her debut level).
static func knight_alone(rng: RandomNumberGenerator) -> Dictionary:
	for _attempt in 40:
		var built := _build([rng.randi_range(Rules.KNIGHT_HITS_MIN, Rules.KNIGHT_HITS_MAX)], rng)
		if not built.is_empty():
			built["name"] = "knight alone: %s" % built["steps"]
			return built
	return {}


## A lone master (the start of his debut level).
static func master_alone(rng: RandomNumberGenerator) -> Dictionary:
	for _attempt in 40:
		var built := _build([-1000 - rng.randi_range(Rules.MASTER_HITS_MIN, Rules.MASTER_HITS_MAX)], rng)
		if not built.is_empty():
			built["name"] = "master alone: %s" % built["steps"]
			return built
	return {}


## A lone ninja (the start of his debut level).
static func ninja_alone(rng: RandomNumberGenerator) -> Dictionary:
	for _attempt in 40:
		var built := _build([-rng.randi_range(Rules.NINJA_HITS_MIN, Rules.NINJA_HITS_MAX)], rng)
		if not built.is_empty():
			built["name"] = "ninja alone: %s" % built["steps"]
			return built
	return {}


## Lays out one chain: `hits` has one entry per enemy, 1 for a plain enemy or
## a knight's number of hits (minus it: a ninja's). Returns {} if the random
## steps put two things in one spot.
static func _build(hits: Array[int], rng: RandomNumberGenerator, pair_chance := 0.0) -> Dictionary:
	var enemies: Array[Vector2] = []
	var knights: Array[int] = []
	var tokens: PackedStringArray = []
	var next_group := {"knight": 0, "ninja": NINJA_GROUP, "master": MASTER_GROUP}
	var i := 0
	while i < hits.size():
		if i > 0:
			var token := _free_step(GENERATED_STEPS, enemies, rng)
			enemies.append(_apply(enemies.back(), token))
			tokens.append(token)
		else:
			enemies.append(Vector2(0, 0))
		if absi(hits[i]) <= 1:
			knights.append(-1)
			i += 1
			continue
		var a := _teleporter(hits[i], next_group)
		knights.append(a["group"])
		# Two teleporters side by side: sometimes their duels interleave (her
		# spots and his alternate, each one step from the last), so while one
		# blinks away the other's standing there to hit.
		if i + 1 < hits.size() and absi(hits[i + 1]) > 1 and rng.randf() < pair_chance:
			var b := _teleporter(hits[i + 1], next_group)
			tokens.append("P(" + a["label"] + b["label"])
			var token := _free_step(GENERATED_STEPS, enemies, rng)
			enemies.append(_apply(enemies.back(), token))
			knights.append(b["group"])
			tokens.append(token.to_lower())
			var left := [int(a["count"]) - 1, int(b["count"]) - 1]
			var groups := [a["group"], b["group"]]
			# Where each was hit last: every blink is one move from her own last
			# spot (follow her straight from where you hit her) as well as from
			# the spot before it in the chain (so the chain still runs on).
			var last := [enemies[enemies.size() - 2], enemies.back()]
			var turn := 0
			while left[0] > 0 or left[1] > 0:
				if left[turn] == 0:
					turn = 1 - turn
				var blink := _shared_step(enemies, last[turn], rng)
				if blink == "":
					return {}   # no spot one move from both: try another layout
				var spot := _apply(enemies.back(), blink)
				enemies.append(spot)
				knights.append(groups[turn])
				tokens.append(blink.to_lower())
				last[turn] = spot
				left[turn] -= 1
				turn = 1 - turn
			tokens.append(")")
			i += 2
			continue
		tokens.append(a["label"] + "(")
		for h in int(a["count"]) - 1:
			var blink := _free_step(KNIGHT_STEPS, enemies, rng)
			enemies.append(_apply(enemies.back(), blink))
			knights.append(a["group"])
			tokens.append(blink.to_lower())
		tokens.append(")")
		i += 1
	if _overlaps(enemies, knights) or _strands_by_knight(enemies, knights):
		return {}
	return {"enemies": enemies, "knights": knights, "steps": " ".join(tokens)}


## A blink one move from the chain's last spot that's also one move from
## `own` (where that teleporter was last hit), on a spot not used yet; "" if
## there's none.
static func _shared_step(used: Array[Vector2], own: Vector2, rng: RandomNumberGenerator) -> String:
	var ok: Array = []
	for token in KNIGHT_STEPS:
		var spot := _apply(used.back(), token)
		if used.has(spot):
			continue
		for t in KNIGHT_STEPS:
			if _apply(own, t) == spot:
				ok.append(token)
				break
	if ok.is_empty():
		return ""
	return ok[rng.randi_range(0, ok.size() - 1)]


## A teleporter from its `hits` entry (a knight's hits, minus a ninja's,
## -1000 minus a master's): {group, count, label}, using up a group number.
static func _teleporter(entry: int, next_group: Dictionary) -> Dictionary:
	var kind := "master" if entry <= -1000 else ("ninja" if entry < 0 else "knight")
	var count := (-entry - 1000) if kind == "master" else absi(entry)
	var g: int = next_group[kind]
	next_group[kind] = g + 1
	return {"group": g, "count": count, "label": {"master": "M", "ninja": "N", "knight": "K"}[kind]}


## A random step from `steps` that lands on a spot not used yet in the chain
## (in practice: no across right after an across). F and D always move on,
## so there's always one.
static func _free_step(steps: Array, used: Array[Vector2], rng: RandomNumberGenerator) -> String:
	var free: Array = []
	for token in steps:
		if not used.has(_apply(used.back(), token)):
			free.append(token)
	if free.is_empty():
		return steps[rng.randi_range(0, steps.size() - 1)]
	return free[rng.randi_range(0, free.size() - 1)]


static func _apply(prev: Vector2, token: String) -> Vector2:
	var shape := step_shape(token)
	var row := (1 - int(prev.y)) if shape[1] else int(prev.y)
	return Vector2(prev.x + float(shape[0]), row)


## True if the chain could end within a knight's reach while she's still
## alive. You may leave a duel early (chain onto another enemy instead of
## her), so after every knight that isn't the chain's last enemy, the chain
## goes on until it's out of her reach: its last enemy is more than a forward
## teleport (plus the strike offset) past her furthest spot. Then finishing
## the chain always leaves you clear of her; she can only get you if the
## chain is dropped (TOO SLOW, MISSED) or you run into her.
static func _strands_by_knight(enemies: Array[Vector2], knights: Array[int]) -> bool:
	var last := enemies.size() - 1
	var furthest := {}
	for i in enemies.size():
		if knights[i] >= 0:
			furthest[knights[i]] = maxf(furthest.get(knights[i], -INF), enemies[i].x)
	for group in furthest:
		if knights[last] == group:
			continue   # she's the chain's last enemy: it ends on her
		if enemies[last].x - float(furthest[group]) <= Rules.FORWARD + Rules.STRIKE_OFFSET:
			return true
	return false


## True if any two spots in the chain are the same. Every spot is used once:
## a knight never blinks onto anyone else's spot (the player can skip the
## enemies before her, so they may still be there), nor back to one she's been on
## (so no across-and-back).
static func _overlaps(enemies: Array[Vector2], _knights: Array[int]) -> bool:
	for j in enemies.size():
		for i in j:
			if enemies[i] == enemies[j]:
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

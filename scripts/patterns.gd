class_name Patterns
extends RefCounted
## Enemy patterns in step notation, for two rows (floor and ceiling).
## The endless level is built by picking patterns at random (harder ones
## further in) and laying them end to end.
##
## A pattern is a run of enemies. The first enemy is the entry; each step
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
## Plain steps put the next enemy right under a marker, so the "your move"
## pause fires. Beats sit halfway between markers (WAIT = half a forward
## teleport), so it's never a near miss.
## A pattern's entry enemy is in the row the previous pattern ended in.
## Patterns are separated by a BREAK automatically.
##
## Run tools/validate_patterns.gd after editing: it checks the notation and
## proves every enemy in every pattern can be chained.

const WAIT := 3.0       # half a forward teleport
const BREAK := 14.0     # well past forward reach, so a break is unmistakable

const LIST := [
	# --- difficulty 1 -----------------------------------------------------
	{"name": "forward_pair", "difficulty": 1, "steps": "F"},
	{"name": "across_pair", "difficulty": 1, "steps": "V"},
	{"name": "diagonal_pair", "difficulty": 1, "steps": "D"},
	{"name": "forward_three", "difficulty": 1, "steps": "F F"},

	# --- difficulty 2 -----------------------------------------------------
	{"name": "forward_then_across", "difficulty": 2, "steps": "F V"},
	{"name": "across_then_forward", "difficulty": 2, "steps": "V F"},
	{"name": "zigzag", "difficulty": 2, "steps": "D D"},
	{"name": "forward_beat", "difficulty": 2, "steps": "F+"},
	{"name": "across_beat", "difficulty": 2, "steps": "V+"},

	# --- difficulty 3 -----------------------------------------------------
	{"name": "f_v_f", "difficulty": 3, "steps": "F V F"},
	{"name": "d_f_d", "difficulty": 3, "steps": "D F D"},
	{"name": "ladder", "difficulty": 3, "steps": "V D V"},
	{"name": "beat_then_across", "difficulty": 3, "steps": "F+ V"},
	{"name": "diagonal_beat_forward", "difficulty": 3, "steps": "D+ F"},

	# --- difficulty 4 -----------------------------------------------------
	{"name": "f_d_f_d", "difficulty": 4, "steps": "F D F D"},
	{"name": "v_f_v_f", "difficulty": 4, "steps": "V F V F"},
	{"name": "zigzag_long", "difficulty": 4, "steps": "D D D D"},
	{"name": "forward_across_beat", "difficulty": 4, "steps": "F V+ F"},
	{"name": "two_beats", "difficulty": 4, "steps": "V+ D+"},

	# --- difficulty 5 -----------------------------------------------------
	{"name": "mixed_a", "difficulty": 5, "steps": "F V D V F"},
	{"name": "mixed_b", "difficulty": 5, "steps": "D F+ V D"},
	{"name": "mixed_c", "difficulty": 5, "steps": "V F D V F D"},
	{"name": "broken_chains", "difficulty": 5, "steps": "F | D V | F"},
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

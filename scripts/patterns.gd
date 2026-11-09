class_name Patterns
extends RefCounted
## Enemy patterns in step notation. The endless level is built by picking
## patterns at random (harder ones further in) and laying them end to end.
##
## A pattern is a row of enemies. The first enemy is the entry; each step
## adds the next enemy, measured from the previous one (after a kill you're
## standing where it was):
##
##   S    short snap   next enemy exactly one short teleport ahead (4.5)
##   L    long snap    exactly one long teleport ahead (9)
##   s+   short beat   run a little, then short   (4.5 + WAIT)
##   l+   long beat    run a little, then long    (9 + WAIT)
##   |    break        next enemy is BREAK tiles ahead (chain ends on purpose)
##
## Snaps put the next enemy right under a marker, so the "your move" pause
## fires. Beats are clearly out of reach until you've run a bit: WAIT keeps
## them well away from both markers, so it's never a near miss.
## Patterns are separated by a BREAK automatically.
##
## New kinds of objects can be added later as new step tokens in parse().
##
## Run tools/validate_patterns.gd after editing: it checks the notation and
## proves every enemy in every pattern can be chained.

const WAIT := 2.25      # halfway between the short and long markers
const BREAK := 14.0     # well past long reach, so a break is unmistakable

const LIST := [
	# --- difficulty 1 -----------------------------------------------------
	{"name": "short_pair", "difficulty": 1, "steps": "S"},
	{"name": "long_pair", "difficulty": 1, "steps": "L"},
	{"name": "short_three", "difficulty": 1, "steps": "S S"},
	{"name": "long_three", "difficulty": 1, "steps": "L L"},

	# --- difficulty 2 -----------------------------------------------------
	{"name": "short_four", "difficulty": 2, "steps": "S S S"},
	{"name": "short_then_long", "difficulty": 2, "steps": "S L"},
	{"name": "long_then_short", "difficulty": 2, "steps": "L S"},
	{"name": "short_beat", "difficulty": 2, "steps": "s+"},
	{"name": "long_beat", "difficulty": 2, "steps": "l+"},

	# --- difficulty 3 -----------------------------------------------------
	{"name": "snap_beat_snap", "difficulty": 3, "steps": "S s+ S"},
	{"name": "long_snap_long_beat", "difficulty": 3, "steps": "L l+"},
	{"name": "short_short_long", "difficulty": 3, "steps": "S S L"},
	{"name": "two_beats", "difficulty": 3, "steps": "s+ s+"},
	{"name": "long_short_short", "difficulty": 3, "steps": "L S S"},

	# --- difficulty 4 -----------------------------------------------------
	{"name": "alternate", "difficulty": 4, "steps": "S L S L"},
	{"name": "beat_snap_x2", "difficulty": 4, "steps": "s+ S s+ S"},
	{"name": "long_beat_long", "difficulty": 4, "steps": "L s+ L"},
	{"name": "short_six", "difficulty": 4, "steps": "S S S S S"},
	{"name": "long_beat_shorts", "difficulty": 4, "steps": "l+ S S"},

	# --- difficulty 5 -----------------------------------------------------
	{"name": "mixed_a", "difficulty": 5, "steps": "S L s+ S L"},
	{"name": "mixed_b", "difficulty": 5, "steps": "l+ S s+ L S"},
	{"name": "shorts_longs_shorts", "difficulty": 5, "steps": "S S L L S S"},
	{"name": "broken_chains", "difficulty": 5, "steps": "S | S S | L"},
]


## Distance for one step token, or -1.0 if the token is unknown.
static func step_distance(token: String) -> float:
	match token:
		"S":
			return Rules.SHORT
		"L":
			return Rules.LONG
		"s+":
			return Rules.SHORT + WAIT
		"l+":
			return Rules.LONG + WAIT
		"|":
			return BREAK
	return -1.0


## Enemy positions relative to the entry enemy (the first is always 0),
## plus any notation errors.
static func parse(steps: String) -> Dictionary:
	var offsets: Array[float] = [0.0]
	var errors: Array[String] = []
	for token in steps.split(" ", false):
		var d := step_distance(token)
		if d < 0.0:
			errors.append("unknown step '%s'" % token)
			continue
		offsets.append(offsets.back() + d)
	return {"offsets": offsets, "errors": errors}

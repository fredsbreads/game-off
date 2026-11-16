extends SceneTree
## Checks the enemy chains:
##   - every hand-made pattern in scripts/patterns.gd parses and EVERY enemy
##     can be killed (the whole pattern chains), arriving from either row
##   - no two patterns share a layout (mirror images count as the same)
##   - generated chains for levels 4 and up are chainable (a sample per level)
##   - the bar size per level
##
## Run from the project folder:
##   godot --headless --path . -s tools/validate_patterns.gd

const GENERATED_LEVELS := 14
const SAMPLES_PER_LEVEL := 15

func _init() -> void:
	var failures := 0
	var seen := {}
	for p in Patterns.LIST:
		var name: String = p["name"]
		var parsed := Patterns.parse(p["steps"])
		var problems: Array[String] = parsed["errors"]
		if problems.is_empty() and not Patterns.is_chainable(parsed["enemies"]):
			problems.append("can't chain every enemy")
		if problems.is_empty():
			var key := _layout_key(parsed["enemies"])
			if seen.has(key):
				problems.append("same layout as %s (%s)" % [seen[key]["name"], seen[key]["steps"]])
			else:
				seen[key] = p
		if problems.is_empty():
			print("  ok    L%d  %-24s %s" % [p["level"], name, p["steps"]])
		else:
			failures += 1
			print("  FAIL  L%d  %-24s %s: %s" % [p["level"], name, p["steps"], ", ".join(problems)])

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for level in range(Patterns.FIRST_GENERATED_LEVEL, GENERATED_LEVELS + 1):
		var r := Patterns.chain_length_range(level)
		var bad := 0
		for i in SAMPLES_PER_LEVEL:
			var chain := Patterns.generate(level, rng)
			var n: int = chain["enemies"].size()   # spots: a knight's every hit counts
			if n < r.x or n > r.y or not Patterns.is_chainable(chain["enemies"], chain["knights"]):
				bad += 1
				print("  FAIL  L%d  generated %s" % [level, chain["steps"]])
		if bad > 0:
			failures += 1
		else:
			print("  ok    L%d  %d generated chains of %d-%d enemies (knight chance %d%%)" % [level, SAMPLES_PER_LEVEL, r.x, r.y, roundi(Patterns.knight_chance(level) * 100)])
	var lone_bad := 0
	for i in SAMPLES_PER_LEVEL:
		var lone := Patterns.knight_alone(rng)
		if lone.is_empty() or not Patterns.is_chainable(lone["enemies"], lone["knights"]):
			lone_bad += 1
			print("  FAIL  knight alone %s" % lone.get("steps", "?"))
	if lone_bad > 0:
		failures += 1
	else:
		print("  ok    L%d  %d lone knights" % [Patterns.KNIGHT_DEBUT_LEVEL, SAMPLES_PER_LEVEL])

	var sizes: PackedStringArray = []
	var prog := Progression.new()
	for level in range(1, 11):
		prog.level = level
		sizes.append("L%d %.1f" % [level, prog.bar_size()])
	print("  bar sizes: ", ", ".join(sizes))
	print("%d patterns, %d problems" % [Patterns.LIST.size(), failures])
	quit(1 if failures > 0 else 0)


## A layout as text, the same for a pattern and its top/bottom mirror image.
func _layout_key(enemies: Array) -> String:
	var a: Array[String] = []
	var b: Array[String] = []
	for e in enemies:
		var v: Vector2 = e
		a.append("%.2f/%d" % [v.x, int(v.y)])
		b.append("%.2f/%d" % [v.x, 1 - int(v.y)])
	a.sort()
	b.sort()
	var ka := ",".join(a)
	var kb := ",".join(b)
	return ka if ka < kb else kb

extends SceneTree
## Checks every pattern in scripts/patterns.gd:
##   - the step notation parses
##   - EVERY enemy can be killed (the whole pattern chains), arriving in
##     either row with BREAK tiles of run-up
##
## Run from the project folder:
##   godot --headless --path . -s tools/validate_patterns.gd

func _init() -> void:
	var failures := 0
	for p in Patterns.LIST:
		var name: String = p["name"]
		var parsed := Patterns.parse(p["steps"])
		var problems: Array[String] = parsed["errors"]
		if problems.is_empty():
			for entry_row in [Rules.Row.FLOOR, Rules.Row.CEILING]:
				var enemies: Array[Vector2] = []
				for e in parsed["enemies"]:
					var rel: Vector2 = e
					var row: int = entry_row if int(rel.y) == 0 else 1 - entry_row
					enemies.append(Vector2(Patterns.BREAK + rel.x, row))
				var length: float = enemies.back().x + Patterns.BREAK
				var all_killed := (1 << enemies.size()) - 1
				# Arrive in the worse case: the row the entry ISN'T in.
				var start := [0.0, 1 - entry_row, Rules.cooldown_frames()]
				var result := ChunkSolver.search(enemies, start, length, length, Rules.RUN_SPEED, 3000, all_killed)
				if not result["ok"]:
					problems.append("can't chain every enemy (entry on %s)" % ("floor" if entry_row == Rules.Row.FLOOR else "ceiling"))
		if problems.is_empty():
			print("  ok    d%d  %-24s %s" % [p["difficulty"], name, p["steps"]])
		else:
			failures += 1
			print("  FAIL  d%d  %-24s %s: %s" % [p["difficulty"], name, p["steps"], ", ".join(problems)])
	# Different step strings can produce the same layout (e.g. "D V F" and
	# "F V D"). Mirror images count as the same too: every pattern already
	# appears mirrored when entered from the other row.
	var seen := {}
	var dupes := 0
	for p in Patterns.LIST:
		var parsed := Patterns.parse(p["steps"])
		if not parsed["errors"].is_empty():
			continue
		var key := _layout_key(parsed["enemies"])
		if seen.has(key):
			dupes += 1
			print("  DUPE  %s (%s) has the same layout as %s (%s)" % [p["name"], p["steps"], seen[key]["name"], seen[key]["steps"]])
		else:
			seen[key] = p
	print("%d patterns, %d failed, %d duplicate layouts" % [Patterns.LIST.size(), failures, dupes])
	failures += dupes
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

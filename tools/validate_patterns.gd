extends SceneTree
## Checks every pattern in scripts/patterns.gd:
##   - the step notation parses
##   - EVERY enemy can be killed (the whole pattern chains), arriving with
##     the worst case (cooldown just started) and BREAK tiles of run-up
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
			var enemies: Array[float] = []
			for off in parsed["offsets"]:
				enemies.append(Patterns.BREAK + float(off))
			var length := int(ceil(enemies.back() + Patterns.BREAK))
			var tiles := PackedByteArray()
			tiles.resize(length)
			tiles.fill(Rules.Tile.GROUND)
			var all_killed := (1 << enemies.size()) - 1
			var result := ChunkSolver.search(tiles, enemies, 0.0, Rules.cooldown_frames(Rules.RUN_SPEED),
				float(length), func(_x: float) -> float: return Rules.RUN_SPEED, 3000, all_killed)
			if not result["ok"]:
				problems.append("can't chain every enemy")
		if problems.is_empty():
			print("  ok    d%d  %-22s %s" % [p["difficulty"], name, p["steps"]])
		else:
			failures += 1
			print("  FAIL  d%d  %-22s %s: %s" % [p["difficulty"], name, p["steps"], ", ".join(problems)])
	print("%d patterns, %d failed" % [Patterns.LIST.size(), failures])
	quit(1 if failures > 0 else 0)

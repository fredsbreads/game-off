extends SceneTree
## Checks every chunk in scripts/chunks.gd:
##   - format rules (hazard widths, spacing, padding)
##   - survivable at slow, medium and max run speed, entering with the
##     worst case (cooldown just started)
##
## Run from the project folder:
##   godot --headless --path . -s tools/validate_chunks.gd

func _init() -> void:
	var failures := 0
	var speeds := [Rules.SPEED_START, (Rules.SPEED_START + Rules.SPEED_MAX) / 2.0, Rules.SPEED_MAX]
	for c in Chunks.LIST:
		var name: String = c["name"]
		var map: String = c["map"]
		var problems: Array[String] = Chunks.validate(map)
		if problems.is_empty():
			var parsed := Chunks.parse(map)
			var tiles: PackedByteArray = parsed["tiles"]
			var enemies: Array[float] = parsed["enemies"]
			for speed in speeds:
				var result := ChunkSolver.search(tiles, enemies, 0.0, Rules.cooldown_frames(speed),
					float(tiles.size()), func(_x: float) -> float: return speed)
				if not result["ok"]:
					problems.append("not survivable at %.1f tiles/s" % speed)
		if problems.is_empty():
			print("  ok    d%d  %s" % [c["difficulty"], name])
		else:
			failures += 1
			print("  FAIL  d%d  %s: %s" % [c["difficulty"], name, ", ".join(problems)])
	print("%d chunks, %d failed" % [Chunks.LIST.size(), failures])
	quit(1 if failures > 0 else 0)

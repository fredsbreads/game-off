class_name Fx
extends Node2D
## Short-lived visual effects: teleport trails, landing rings, slashes,
## particles and floating text. Runs on real time; main.gd sets `frozen`
## to hold them mid-air during the kill pause.

const GRAVITY := 900.0
const KILL_COLORS := [Color(1, 1, 1), Color(1, 0.45, 0.4), Color(1, 0.85, 0.5)]

var _items: Array[Dictionary] = []
## While true, every effect holds still (used during the kill pause).
var frozen := false


## from / to are body centres in pixels.
func teleport_trail(from: Vector2, to: Vector2) -> void:
	_items.append({"kind": "trail", "t": 0.0, "life": 0.22, "a": from, "b": to})


func landing_ring(pos: Vector2) -> void:
	_ring(pos, 10.0, 46.0, 0.25, 3.0, Color(1, 1, 1, 0.8))


## Bigger and brighter the longer the chain.
func kill_burst(pos: Vector2, combo: int) -> void:
	var c := mini(combo, 8)
	_ring(pos, 12.0, 60.0 + 10.0 * c, 0.3, 4.0 + c * 0.5, Color(1, 0.9, 0.7, 0.9))
	_items.append({"kind": "slash", "t": 0.0, "life": 0.16, "pos": pos, "len": 80.0 + 10.0 * c})
	for i in 8 + c * 3:
		var dir := Vector2.from_angle(randf_range(-PI, 0.2))
		_items.append({"kind": "particle", "t": 0.0, "life": randf_range(0.35, 0.65),
			"pos": pos, "vel": dir * randf_range(150.0, 350.0 + 40.0 * c),
			"color": KILL_COLORS[i % KILL_COLORS.size()]})


func text(pos: Vector2, value: String, size: int, color: Color) -> void:
	_items.append({"kind": "text", "t": 0.0, "life": 0.7, "pos": pos, "text": value, "size": size, "color": color})


func _ring(pos: Vector2, r0: float, r1: float, life: float, width: float, color: Color) -> void:
	_items.append({"kind": "ring", "t": 0.0, "life": life, "pos": pos, "r0": r0, "r1": r1, "width": width, "color": color})


func _process(delta: float) -> void:
	if frozen:
		return
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		it["t"] += delta
		if it["kind"] == "particle":
			it["vel"].y += GRAVITY * delta
			it["pos"] += it["vel"] * delta
		if it["t"] >= it["life"]:
			_items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var t := Rules.TILE
	var gy := Rules.GROUND_Y
	var font := ThemeDB.fallback_font
	for it in _items:
		var k: float = it["t"] / it["life"]
		var fade := 1.0 - k
		match it["kind"]:
			"trail":
				var a: Vector2 = it["a"]
				var b: Vector2 = it["b"]
				for g in 4:
					var p := a.lerp(b, g / 4.0)
					draw_rect(Rect2(p.x - t * 0.25, p.y - t * 0.55, t * 0.5, t * 1.1), Color(0.85, 0.88, 1, 0.3 * fade * (g + 1) / 4.0))
				draw_line(a, b, Color(1, 1, 1, 0.9 * fade), 1.0 + 5.0 * fade)
			"ring":
				var r := lerpf(it["r0"], it["r1"], 1.0 - pow(1.0 - k, 3.0))
				var col: Color = it["color"]
				col.a *= fade
				draw_arc(it["pos"], r, 0.0, TAU, 40, col, it["width"])
			"slash":
				var dir := Vector2(1, -0.8).normalized()
				var half: float = it["len"] / 2.0
				var pos: Vector2 = it["pos"]
				var grow := minf(1.0, k * 4.0)
				draw_line(pos - dir * half, pos - dir * half + dir * half * 2.0 * grow, Color(1, 1, 1, fade), 2.0 + 6.0 * fade)
			"particle":
				var col: Color = it["color"]
				col.a = fade
				draw_rect(Rect2(it["pos"] - Vector2(3, 3), Vector2(6, 6)), col)
			"text":
				var size: int = it["size"]
				var value: String = it["text"]
				var col: Color = it["color"]
				col.a = 1.0 - k * k
				var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var pos: Vector2 = it["pos"] - Vector2(w / 2.0, k * 50.0)
				draw_string_outline(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, col.a))
				draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

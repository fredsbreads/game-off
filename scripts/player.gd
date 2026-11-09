class_name Player
extends Node2D
## The runner. Gameplay state is just `x` (in tiles) and `cooldown` (in
## frames). main.gd moves them; this script only draws, including the two
## landing markers.

const BODY_COLOR := Color(0.93, 0.93, 0.96)
const SCARF_COLOR := Color(0.9, 0.2, 0.22)
const SWORD_COLOR := Color(0.75, 0.78, 0.85)
const MARKER_READY := Color(1, 1, 1, 0.32)
const MARKER_COOLDOWN := Color(1, 1, 1, 0.1)
const MARKER_LIT := Color(1, 1, 1, 0.95)    # during the kill pause: "your move"
const MARKER_LIT_PULSE_SPEED := 18.0
const BOB_SPEED := 18.0
const BOB_HEIGHT := 3.0

var x := 0.0
var cooldown := 0
var running := false
var alive := true
var markers_lit := false

var _run_time := 0.0
var _lit_time := 0.0
var _death_offset := Vector2.ZERO
var _death_velocity := Vector2.ZERO


func die(_kind: String) -> void:
	alive = false
	_death_velocity = Vector2(-220, -420)


func animate_death(delta: float) -> void:
	_death_velocity.y += 1600.0 * delta
	_death_offset += _death_velocity * delta
	rotation -= 8.0 * delta


func _process(delta: float) -> void:
	if running and alive and not markers_lit:
		_run_time += delta
	_lit_time = _lit_time + delta if markers_lit else 0.0
	position = Vector2(x * Rules.TILE, Rules.GROUND_Y) + _death_offset
	queue_redraw()


func _draw() -> void:
	var t := Rules.TILE
	var w := t * 0.5
	var h := t * 1.1

	if alive:
		var marker_color := MARKER_READY if cooldown == 0 else MARKER_COOLDOWN
		var width := 2.0
		if markers_lit:
			marker_color = MARKER_LIT
			marker_color.a *= 0.75 + 0.25 * cos(_lit_time * MARKER_LIT_PULSE_SPEED)
			width = 3.0
		for d in [Rules.SHORT, Rules.LONG]:
			var mx: float = d * t
			draw_rect(Rect2(mx - w / 2, -h, w, h), marker_color, false, width)
			draw_line(Vector2(mx - w * 0.7, 3), Vector2(mx + w * 0.7, 3), marker_color, width + 1.0)

	var bob := -absf(sin(_run_time * BOB_SPEED)) * BOB_HEIGHT
	# Sword on the back, only while it's ready to throw.
	if cooldown == 0 or not alive:
		draw_line(Vector2(-w * 0.75, -h * 0.25 + bob), Vector2(w * 0.1, -h * 1.12 + bob), SWORD_COLOR, 4.0)
	draw_rect(Rect2(-w / 2, -h + bob, w, h), BODY_COLOR)
	draw_rect(Rect2(-w / 2, -h * 0.82 + bob, w, 7), SCARF_COLOR)
	draw_rect(Rect2(-w / 2 - 14, -h * 0.82 + bob + 2, 14, 4), SCARF_COLOR)

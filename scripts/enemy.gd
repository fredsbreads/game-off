class_name Enemy
extends Node2D
## A grey-box enemy on the floor, or hanging upside down from the ceiling.
## Kills you if you run into it in its row; dies if you teleport onto it.

const BODY_COLOR := Color(0.86, 0.27, 0.32)
const EYE_COLOR := Color(1, 1, 1)

var tile_x := 0.0
var row := Rules.Row.FLOOR
var alive := true


func _ready() -> void:
	position = Vector2(tile_x * Rules.TILE, Rules.surface_y(row))
	scale.y = -1.0 if row == Rules.Row.CEILING else 1.0


func die() -> void:
	alive = false
	visible = false


func _draw() -> void:
	var t := Rules.TILE
	var w := t * 0.6
	var h := t * 0.9
	draw_rect(Rect2(-w / 2, -h, w, h), BODY_COLOR)
	# Eye facing left, toward the player.
	draw_rect(Rect2(-w / 2 + 5, -h + 12, 9, 9), EYE_COLOR)

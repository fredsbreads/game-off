class_name Player
extends Node2D
## The runner. Gameplay state is `x` (in tiles), `row` (floor or ceiling)
## and `cooldown` (in frames). main.gd moves them; this script only draws:
## the kunoichi sprite, the three landing markers (forward, across,
## diagonal) and, while SHOW_HITBOX is on, her hitbox.

# Show the hitbox outline over the sprite (for tuning; turn off for release).
const SHOW_HITBOX := false

const SHEET := preload("res://assets/sprites/kunoichi.png")
# The run cycle is its own 6-frame strip (with the katana on her back).
const RUN_SHEET := preload("res://assets/sprites/kunoichi_run.png")
const FRAME := Vector2i(96, 96)
# Where her feet are inside a 96x96 frame: this point sits on the floor.
const FEET := Vector2(47, 88)
const RUN_FEET := Vector2(47, 86)   # the run strip's feet sit 2 px higher
# Drawn size: 1.5 = each art pixel is 1.5 game units (she's ~100 units tall).
# Purely visual; the hitbox below is set by the rules, not the art.
const SPRITE_SCALE := 1.5
# [sheet, row on the sheet, frame count, frames per second, loop, feet]
const ANIMS := {
	"idle": [SHEET, 0, 6, 8.0, true, FEET],
	"run": [RUN_SHEET, 0, 6, 12.0, true, RUN_FEET],
	"fall": [SHEET, 5, 3, 10.0, true, FEET],
}

const MARKER_READY := Color(1, 1, 1, 0.32)
const MARKER_COOLDOWN := Color(1, 1, 1, 0.1)
const MARKER_LIT := Color(1, 1, 1, 0.95)    # during the kill pause: "your move"
const MARKER_LIT_PULSE_SPEED := 18.0
const MARKER_SIZE := Vector2(0.5, 1.1)       # tiles
const HITBOX_COLOR := Color(0.2, 1.0, 0.4, 0.9)

var x := 0.0
var row := Rules.Row.FLOOR
var cooldown := 0
var running := false
var alive := true
var markers_lit := false
var frozen := false      # kill pause: hold the current animation frame

var _lit_time := 0.0
var _death_offset := Vector2.ZERO
var _death_velocity := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _hitbox: Node2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.centered = false
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_play("idle")
	add_child(_sprite)

	# Drawn after (on top of) the sprite.
	_hitbox = Node2D.new()
	_hitbox.draw.connect(_draw_hitbox)
	add_child(_hitbox)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ANIMS:
		var spec: Array = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[3])
		frames.set_animation_loop(anim, spec[4])
		for i in int(spec[2]):
			var tex := AtlasTexture.new()
			tex.atlas = spec[0]
			tex.region = Rect2(Vector2(i * FRAME.x, int(spec[1]) * FRAME.y), Vector2(FRAME))
			frames.add_frame(anim, tex)
	return frames


## Play an animation with its own foot anchor.
func _play(anim: String) -> void:
	var feet: Vector2 = ANIMS[anim][5]
	_sprite.offset = -feet
	_sprite.play(anim)


func die(_kind: String) -> void:
	alive = false
	_death_velocity = Vector2(-220, -420)
	_play("fall")


func animate_death(delta: float) -> void:
	_death_velocity.y += 1600.0 * delta
	_death_offset += _death_velocity * delta
	rotation -= 8.0 * delta


func _process(delta: float) -> void:
	_lit_time = _lit_time + delta if markers_lit else 0.0
	position = Vector2(x * Rules.TILE, Rules.surface_y(row)) + _death_offset
	# On the ceiling the whole player (sprite and markers) is upside down.
	scale.y = -1.0 if row == Rules.Row.CEILING else 1.0

	if alive:
		var want := "run" if running else "idle"
		if _sprite.animation != want:
			_play(want)
	_sprite.speed_scale = 0.0 if frozen else 1.0

	queue_redraw()
	_hitbox.queue_redraw()


func _draw() -> void:
	if not alive:
		return
	var t := Rules.TILE
	var h := MARKER_SIZE.y * t
	# In local coordinates the other row is always ROW_GAP "up" (-y): when
	# the player is flipped onto the ceiling, that maps down to the floor.
	var gap := Rules.ROW_GAP * t

	var marker_color := MARKER_READY if cooldown == 0 else MARKER_COOLDOWN
	var width := 2.0
	if markers_lit:
		marker_color = MARKER_LIT
		marker_color.a *= 0.75 + 0.25 * cos(_lit_time * MARKER_LIT_PULSE_SPEED)
		width = 3.0
	var fwd := Rules.FORWARD * t
	# Each marker covers that teleport's kill zone: an enemy whose centre is
	# inside it dies if you make that move now. The across marker (vertical)
	# reaches further ahead because that teleport is more forgiving forward.
	var zf := Rules.kill_zone(Rules.Move.FORWARD) * t
	var zv := Rules.kill_zone(Rules.Move.VERTICAL) * t
	var zd := Rules.kill_zone(Rules.Move.DIAGONAL) * t
	# Forward: same row.
	_draw_marker(Rect2(fwd - zf.x, -h, zf.x + zf.y, h), 3.0, marker_color, width)
	# Vertical and diagonal: the other row (hanging from its surface).
	_draw_marker(Rect2(-zv.x, -gap, zv.x + zv.y, h), -gap - 3.0, marker_color, width)
	_draw_marker(Rect2(fwd - zd.x, -gap, zd.x + zd.y, h), -gap - 3.0, marker_color, width)


func _draw_marker(body: Rect2, line_y: float, color: Color, width: float) -> void:
	draw_rect(body, color, false, width)
	var cx := body.get_center().x
	var half := body.size.x * 0.5 + 4.0
	draw_line(Vector2(cx - half, line_y), Vector2(cx + half, line_y), color, width + 1.0)


## The hitbox as the rules use it: you collide with an enemy in your row if
## its centre comes within HIT_RADIUS of your position (the dot at your
## feet). Drawn as a box that wide, as tall as the old placeholder body.
func _draw_hitbox() -> void:
	if not SHOW_HITBOX or not alive:
		return
	var t := Rules.TILE
	var half := Rules.HIT_RADIUS * t
	var h := MARKER_SIZE.y * t
	_hitbox.draw_rect(Rect2(-half, -h, half * 2.0, h), HITBOX_COLOR, false, 2.0)
	_hitbox.draw_circle(Vector2.ZERO, 3.0, HITBOX_COLOR)

class_name Player
extends Node2D
## The runner. Gameplay state is `x` (in tiles), `row` (floor or ceiling)
## and `cooldown` (in frames). main.gd moves them; this script only draws:
## the kunoichi sprite, the three landing markers (forward, across,
## diagonal) and, while SHOW_HITBOX is on, her hitbox.
##
## Each marker is a lightning bolt at that teleport's landing spot, with a
## line under it as wide as its kill zone. Hollow and dull by default; solid
## ("lit") when that teleport would slash an enemy right now. In the "your
## move" freeze the lit ones pulse.

# Show the hitbox outline over the sprite (for tuning; turn off for release).
const SHOW_HITBOX := false

const SHEET := preload("res://assets/sprites/kunoichi.png")
# The run cycle is its own 6-frame strip.
const RUN_SHEET := preload("res://assets/sprites/kunoichi_run.png")
const FRAME := Vector2i(96, 96)
# Where her feet are inside a 96x96 frame: this point sits on the floor.
const FEET := Vector2(47, 88)
const RUN_FEET := Vector2(47, 86)   # the run strip's feet sit 2 px higher
# Attacks: three separate strike poses (with their slash arcs) on a bigger
# 170x170 canvas, her body in the same place as the run frames + (37, 37).
const ATTACK_SHEET := preload("res://assets/sprites/kunoichi_attack.png")
const ATTACK_FRAME := Vector2i(170, 170)
const ATTACK_FEET := RUN_FEET + Vector2(37, 37)
const ATTACK_COUNT := 3
# How long a strike pose shows at least (real time, not counting freezes).
const ATTACK_HOLD := 0.2
# Drawn size: 1.5 = each art pixel is 1.5 game units (she's ~100 units tall).
# Purely visual; the hitbox below is set by the rules, not the art.
const SPRITE_SCALE := 1.5
# [sheet, row on the sheet, frame count, frames per second, loop, feet, frame size]
const ANIMS := {
	"idle": [SHEET, 0, 6, 8.0, true, FEET, FRAME],
	"run": [RUN_SHEET, 0, 6, 12.0, true, RUN_FEET, FRAME],
	"fall": [SHEET, 5, 3, 10.0, true, FEET, FRAME],
	"attack": [ATTACK_SHEET, 0, ATTACK_COUNT, 0.0, false, ATTACK_FEET, ATTACK_FRAME],
}

const MARKER_READY := Color(1, 1, 1, 0.32)      # dull, can teleport
const MARKER_COOLDOWN := Color(1, 1, 1, 0.12)   # dull, in the cooldown
const MARKER_LIT := Color(1, 1, 1, 0.95)        # an enemy is in this teleport's kill zone
const MARKER_LIT_PULSE_SPEED := 18.0            # lit markers pulse in the freeze
const MARKER_SIZE := Vector2(0.5, 1.1)          # tiles (also the hitbox drawing's height)
const BOLT_SIZE := Vector2(0.55, 0.95)          # tiles
# The bolt's outline, in a 1x1 box (x right, y down).
const BOLT := [Vector2(0.45, 0.0), Vector2(0.9, 0.0), Vector2(0.62, 0.4), Vector2(0.88, 0.4),
	Vector2(0.28, 1.0), Vector2(0.45, 0.56), Vector2(0.12, 0.56)]
const HITBOX_COLOR := Color(0.2, 1.0, 0.4, 0.9)

var x := 0.0
var row := Rules.Row.FLOOR
var cooldown := 0
var running := false
var alive := true
var markers_lit := false   # the "your move" freeze: lit markers pulse
# Which teleports would slash an enemy right now (main.gd sets these).
var target_forward := false
var target_vertical := false
var target_diagonal := false
var frozen := false      # kill pause: hold the current animation frame

var _lit_time := 0.0
var _attack_left := 0.0   # > 0 while a strike pose is showing
var _last_attack := -1
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
			var size: Vector2i = spec[6]
			tex.region = Rect2(Vector2(i * size.x, int(spec[1]) * size.y), Vector2(size))
			frames.add_frame(anim, tex)
	return frames


## Play an animation with its own foot anchor.
func _play(anim: String) -> void:
	var feet: Vector2 = ANIMS[anim][5]
	_sprite.offset = -feet
	_sprite.play(anim)


## A kill: show one of the strike poses (never the same one twice in a row).
## It stays through the kill freeze, then for ATTACK_HOLD of real play.
func strike() -> void:
	var pick := randi() % ATTACK_COUNT
	if pick == _last_attack:
		pick = (pick + 1 + randi() % (ATTACK_COUNT - 1)) % ATTACK_COUNT
	_last_attack = pick
	_attack_left = ATTACK_HOLD
	_play("attack")
	_sprite.frame = pick


func die(_kind: String) -> void:
	_attack_left = 0.0
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
		if _attack_left > 0.0:
			if not frozen:
				_attack_left -= delta
		else:
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

	var fwd := Rules.FORWARD * t
	# The line under each bolt spans that teleport's landing zone: an enemy
	# touching it dies if you make that move now.
	var zf := Rules.marker_zone(Rules.Move.FORWARD) * t
	var zv := Rules.marker_zone(Rules.Move.VERTICAL) * t
	var zd := Rules.marker_zone(Rules.Move.DIAGONAL) * t
	# Forward: same row.
	_draw_marker(fwd - zf.x, fwd + zf.y, -h, 3.0, target_forward)
	# Vertical and diagonal: the other row (hanging from its surface).
	_draw_marker(-zv.x, zv.y, -gap, -gap - 3.0, target_vertical)
	_draw_marker(fwd - zd.x, fwd + zd.y, -gap, -gap - 3.0, target_diagonal)


## A bolt over the kill zone [x0, x1]; body_top = the top of a body standing
## in that row (local y), line_y = where the zone line goes.
func _draw_marker(x0: float, x1: float, body_top: float, line_y: float, lit: bool) -> void:
	var t := Rules.TILE
	var color := MARKER_READY if cooldown == 0 else MARKER_COOLDOWN
	if lit:
		color = MARKER_LIT
		if markers_lit:
			color.a *= 0.75 + 0.25 * cos(_lit_time * MARKER_LIT_PULSE_SPEED)
	var size := BOLT_SIZE * t
	var cx := (x0 + x1) * 0.5
	# Centred in the body's height (MARKER_SIZE.y tall from body_top).
	var top := body_top + (MARKER_SIZE.y * t - size.y) * 0.5
	var points := PackedVector2Array()
	# On the ceiling the whole player node is flipped upside down; flip the
	# bolt back so it always reads upright on screen.
	var upright := row == Rules.Row.CEILING
	for p in BOLT:
		var v: Vector2 = p
		var vy := 1.0 - v.y if upright else v.y
		points.append(Vector2(cx - size.x * 0.5 + v.x * size.x, top + vy * size.y))
	if lit:
		draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, 3.0 if lit else 2.0)
	var half := (x1 - x0) * 0.5 + 4.0
	draw_line(Vector2(cx - half, line_y), Vector2(cx + half, line_y), color, 4.0 if lit else 3.0)


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

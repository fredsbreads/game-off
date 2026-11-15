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
# Attacks: three separate strike poses on a bigger 170x170 canvas, her body
# in the same place as the run frames + (37, 37). Each has its own slash arc,
# played separately: it sweeps along the swing, then fades, while the pose
# stays. Made from art/red_flash_attack_frames.piskel by
# tools/build_attack_arcs.py.
const ATTACK_SHEET := preload("res://assets/sprites/attack/poses.png")
const ARC_TEXTURES := [
	preload("res://assets/sprites/attack/arc0.png"),
	preload("res://assets/sprites/attack/arc1.png"),
	preload("res://assets/sprites/attack/arc2.png"),
]
const ARC_T_MAPS := [
	preload("res://assets/sprites/attack/arc0_t.png"),
	preload("res://assets/sprites/attack/arc1_t.png"),
	preload("res://assets/sprites/attack/arc2_t.png"),
]
const ARC_IN_FRONT := [false, false, true]   # as drawn: behind her, or in front
const ARC_SHADER := preload("res://shaders/swing_arc.gdshader")

# Throw poses for teleports: she throws the sword and flashes to it. The pose
# lingers where she left as a red outline, and red afterimages of it trail
# along the path. Forward and diagonal use the forward throw; across uses the
# vertical throw (sword pointing at the other row).
# Each pose is split into her body and the sword (same canvas, so they line
# up): the sword flies to where she lands, then she appears there.
const THROW := preload("res://assets/sprites/kunoichi_throw_body.png")              # 96x96
const THROW_SWORD := preload("res://assets/sprites/kunoichi_throw_sword.png")
const THROW_FEET := RUN_FEET                                                        # drawn over the run pose
const THROW_VERTICAL := preload("res://assets/sprites/kunoichi_throw_vertical_body.png")  # 120x120
const THROW_VERTICAL_SWORD := preload("res://assets/sprites/kunoichi_throw_vertical_sword.png")
const THROW_VERTICAL_FEET := Vector2(59, 102)
const SWORD_FLIGHT := 0.07   # seconds the thrown sword takes; she appears when it lands
# The middle of the sword in each throw image (art pixels): it flies, and the
# teleport line runs, between these points at the start and where she lands.
const THROW_SWORD_CENTRE := Vector2(75.5, 41.5)
const THROW_VERTICAL_SWORD_CENTRE := Vector2(54.5, 16.5)
# Diagonal teleports throw the sword at an angle: the one from the second
# attack (hilt top-left, blade down and forward), mirrored to point up when
# she goes floor -> ceiling.
const DIAGONAL_SWORD := preload("res://assets/sprites/kunoichi_sword_diagonal.png")
const DIAGONAL_SWORD_CENTRE := Vector2(12, 11)
# Kills: she flashes red when she appears in her strike pose, and red copies
# of that pose linger just behind her (toward where she came from).
const STRIKE_FLASH := Color(1.0, 0.3, 0.3)
const STRIKE_FLASH_TIME := 0.15
const STRIKE_GHOSTS := 2
const STRIKE_GHOST_STEP := 0.35   # tiles between copies
const STRIKE_GHOST_FILL := Color(1.0, 0.25, 0.3, 0.5)
const STRIKE_GHOST_LIFE := 0.25
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const GHOST_OUTLINE := Color(1.0, 0.25, 0.3, 0.9)     # the lingering pose where she left
const GHOST_OUTLINE_FILL := Color(1.0, 0.2, 0.25, 0.2)
const GHOST_OUTLINE_LIFE := 0.35
const GHOST_TRAIL_FILL := Color(1.0, 0.3, 0.3, 0.55)  # afterimages along the path
const GHOST_TRAIL_COUNT := 3
const GHOST_TRAIL_LIFE := 0.2
const ARC_SWEEP := 0.08   # seconds to sweep along the swing
const ARC_HOLD := 0.12    # seconds the full slash stays before fading
const ARC_FADE := 0.12    # seconds to fade out after that
const ATTACK_FRAME := Vector2i(170, 170)
const ATTACK_FEET := RUN_FEET + Vector2(37, 37)
const ATTACK_COUNT := 3
# The strike pose shows until she moves again (the end of the kill freeze);
# then she's straight back to running.
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
var _striking := false    # showing a strike pose
var _strike_time := 0.0
const STRIKE_MIN := 0.035  # the pose shows at least this long (~2 frames)
var _last_attack := -1
var _hidden_left := 0.0   # > 0: not shown yet (the thrown sword is still flying)
var _last_from_feet := Vector2.ZERO   # where the last teleport started
var _arc: Sprite2D
var _arc_material: ShaderMaterial
const ARC_NONE := -100.0
var _arc_time := ARC_NONE  # seconds since the arc started (negative: waiting for her to land)
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

	_arc_material = ShaderMaterial.new()
	_arc_material.shader = ARC_SHADER
	_arc = Sprite2D.new()
	_arc.material = _arc_material
	_arc.centered = false
	_arc.offset = -ATTACK_FEET
	_arc.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arc.visible = false
	# Not moved by her: the slash stays where it happened and she runs out of it.
	_arc.top_level = true
	add_child(_arc)

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
	_striking = true
	_strike_time = 0.0
	_play("attack")
	_sprite.frame = pick
	_strike_flair(pick)
	_arc.texture = ARC_TEXTURES[pick]
	_arc_material.set_shader_parameter("t_map", ARC_T_MAPS[pick])
	_arc.z_index = 1 if ARC_IN_FRONT[pick] else -1
	# Placed where she is now (and flipped like her on the ceiling).
	_arc.global_position = Vector2(x * Rules.TILE, Rules.surface_y(row))
	_arc.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * (-1.0 if row == Rules.Row.CEILING else 1.0))
	_arc_time = -_hidden_left   # starts when she appears (after the thrown sword lands)
	_update_arc()


## A teleport just happened from from_feet (world, at her feet) in from_row
## to where she is now: leave the throw pose behind as a fading red outline,
## and red afterimages of it along the way.
func teleport_afterimages(move: int, from_feet: Vector2, from_row: int) -> void:
	var vertical := move == Rules.Move.VERTICAL
	var tex: Texture2D = THROW_VERTICAL if vertical else THROW
	var sword: Texture2D = THROW_VERTICAL_SWORD if vertical else THROW_SWORD
	var feet: Vector2 = THROW_VERTICAL_FEET if vertical else THROW_FEET
	var to_feet := Vector2(x * Rules.TILE, Rules.surface_y(row))
	# 1. She stands in the throw stance where she was (sword gone from her hand)...
	var stance := _sprite_at(tex, feet, from_feet, from_row)
	stance.z_index = 1
	var st := stance.create_tween()
	st.tween_interval(SWORD_FLIGHT)
	st.tween_callback(stance.queue_free)
	# 2. ...the sword flies to where she lands (flipping halfway if she
	# changes rows)...
	var centre: Vector2 = THROW_VERTICAL_SWORD_CENTRE if vertical else THROW_SWORD_CENTRE
	var diagonal := move == Rules.Move.DIAGONAL
	if diagonal:
		sword = DIAGONAL_SWORD
		centre = DIAGONAL_SWORD_CENTRE
	# (The diagonal sword points down and forward as drawn: flip it when
	# going up from the floor.)
	var sword_row := (Rules.Row.CEILING if from_row == Rules.Row.FLOOR else Rules.Row.FLOOR) if diagonal else from_row
	var flying := _sprite_at(sword, centre, sword_point(move, from_feet, from_row), sword_row)
	flying.z_index = 2
	var ft := flying.create_tween()
	ft.tween_property(flying, "global_position", sword_point(move, to_feet, row), SWORD_FLIGHT)
	ft.tween_callback(flying.queue_free)
	if row != from_row and not diagonal:
		var flip := flying.create_tween()
		flip.tween_interval(SWORD_FLIGHT * 0.5)
		flip.tween_callback(func() -> void: flying.scale.y = -flying.scale.y)
	# 3. ...and she appears there when it lands. The stance stays behind as a
	# fading red outline.
	_hidden_left = SWORD_FLIGHT
	_sprite.visible = false
	_last_from_feet = from_feet
	_ghost(tex, feet, from_feet, from_row, GHOST_OUTLINE_FILL, GHOST_OUTLINE, GHOST_OUTLINE_LIFE, 1.0, SWORD_FLIGHT)
	for i in range(1, GHOST_TRAIL_COUNT + 1):
		var k := float(i) / (GHOST_TRAIL_COUNT + 1)
		# Across: flips halfway. Diagonal: all keep the way she left.
		var on_row := from_row if (k < 0.5 or diagonal) else row
		# Nearer her = a bit stronger.
		_ghost(tex, feet, from_feet.lerp(to_feet, k), on_row, GHOST_TRAIL_FILL, Color(0, 0, 0, 0),
			GHOST_TRAIL_LIFE, 0.4 + 0.6 * k)


## When she appears in a strike pose: a quick red flash on her, and red copies
## of the pose just behind her (toward where she came from).
func _strike_flair(pick: int) -> void:
	var delay := _hidden_left
	var flash := _sprite.create_tween()
	if delay > 0.0:
		flash.tween_interval(delay)
	flash.tween_callback(func() -> void: _sprite.modulate = STRIKE_FLASH)
	flash.tween_property(_sprite, "modulate", Color.WHITE, STRIKE_FLASH_TIME)
	var here := Vector2(x * Rules.TILE, Rules.surface_y(row))
	var back := (_last_from_feet - here)
	if back.length() < 1.0:
		return
	back = back.normalized() * STRIKE_GHOST_STEP * Rules.TILE
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture("attack", pick)
	for i in range(1, STRIKE_GHOSTS + 1):
		_ghost(tex, ATTACK_FEET, here + back * i, row, STRIKE_GHOST_FILL, Color(0, 0, 0, 0),
			STRIKE_GHOST_LIFE, 1.0 - 0.35 * (i - 1), delay)


## Where the sword is in her throw pose for `move`, standing at feet_pos in
## on_row (world pixels). Flipped like her on the ceiling.
func sword_point(move: int, feet_pos: Vector2, on_row: int) -> Vector2:
	var vertical := move == Rules.Move.VERTICAL
	var centre: Vector2 = THROW_VERTICAL_SWORD_CENTRE if vertical else THROW_SWORD_CENTRE
	var feet: Vector2 = THROW_VERTICAL_FEET if vertical else THROW_FEET
	var d := (centre - feet) * SPRITE_SCALE
	if on_row == Rules.Row.CEILING:
		d.y = -d.y
	return feet_pos + d


## A plain sprite of one of her poses, left in the world at pos (her feet).
func _sprite_at(tex: Texture2D, feet: Vector2, pos: Vector2, on_row: int) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = false
	g.offset = -feet
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.top_level = true   # stays where it was left
	g.global_position = pos
	g.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * (-1.0 if on_row == Rules.Row.CEILING else 1.0))
	add_child(g)
	return g


## delay: seconds before it shows (then it fades over `life`).
func _ghost(tex: Texture2D, feet: Vector2, pos: Vector2, on_row: int, fill: Color, outline: Color, life: float, alpha: float, delay: float = 0.0) -> void:
	var g := _sprite_at(tex, feet, pos, on_row)
	g.z_index = -2       # behind her and her slash
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("outline", outline)
	g.material = m
	g.modulate.a = alpha
	var tween := g.create_tween()
	if delay > 0.0:
		g.visible = false
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: g.visible = true)
	tween.tween_property(g, "modulate:a", 0.0, life)
	tween.tween_callback(g.queue_free)


## The arc runs on real time (even during the kill freeze): sweep, then fade.
func _update_arc() -> void:
	if _arc_time < 0.0 or not alive:   # none, or not started yet
		_arc.visible = false
		return
	_arc.visible = true
	_arc_material.set_shader_parameter("progress", clampf(_arc_time / ARC_SWEEP, 0.0, 1.0))
	_arc_material.set_shader_parameter("fade", 1.0 - clampf((_arc_time - ARC_SWEEP - ARC_HOLD) / ARC_FADE, 0.0, 1.0))
	if _arc_time >= ARC_SWEEP + ARC_HOLD + ARC_FADE:
		_arc_time = ARC_NONE
		_arc.visible = false


func die(_kind: String) -> void:
	_striking = false
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

	if _arc_time > ARC_NONE:
		_arc_time += delta
		_update_arc()
	if _hidden_left > 0.0:
		_hidden_left -= delta
		_sprite.visible = _hidden_left <= 0.0
	if alive:
		_strike_time += delta
		if _striking and not frozen and _strike_time >= STRIKE_MIN:
			_striking = false   # moving again: back to running
		if not _striking:
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

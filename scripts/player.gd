class_name Player
extends Node2D
## The runner. Gameplay state is `x` (in tiles), `row` (floor or ceiling)
## and `cooldown` (in frames). main.gd moves them; this script only draws:
## the kunoichi sprite, the three landing markers (forward, across,
## diagonal) and, while SHOW_HITBOX is on, her hitbox.
##
## Each marker is a small katana over that teleport's landing spot, with a
## line under it as wide as its kill zone. When an enemy is in range it turns
## red ("lit") and hovers over his head. In the "your move" freeze the red
## drains as the time to act runs out.

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
# The angle the diagonal sword is drawn at (hilt to tip, radians: ~42 degrees
# down-right). In flight it's turned to lie along the teleport line, with its
# cutting edge facing back toward where she came from.
const DIAGONAL_SWORD_ANGLE := 0.75
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

# Teleport markers: a small katana (the diagonal sword) floating at head
# height over each landing spot. When an enemy is in that teleport's range,
# the katana hovers over his head instead and follows him; when he leaves
# the range it snaps back. Plain by default, red when it would slash. In the
# "your move" freeze the red drains toward the tip as the time to act runs out.
const MARKER_READY := Color(1, 1, 1, 0.32)      # plain, can teleport
const MARKER_COOLDOWN := Color(1, 1, 1, 0.12)   # plain, in the cooldown
const MARKER_LIT := Color(0.95, 0.15, 0.2, 1.0) # an enemy is in this teleport's kill zone
const MARKER_KATANA := preload("res://assets/sprites/kunoichi_sword_diagonal.png")  # hilt top-left, tip bottom-right
const MARKER_KATANA_SCALE := 1.25
const MARKER_HEIGHT := 1.65      # tiles above the row's surface (just over an enemy's head)
const MARKER_FOLLOW_RATE := 16.0 # how fast it glides onto an enemy and back (higher = snappier)
const MARKER_COLOUR_RATE := 14.0 # how fast it fades between plain and red
const MARKER_SHADER := preload("res://shaders/marker.gdshader")
const MARKER_SIZE := Vector2(0.5, 1.1)          # tiles (the hitbox drawing's height)
const HITBOX_COLOR := Color(0.2, 1.0, 0.4, 0.9)

var x := 0.0
var row := Rules.Row.FLOOR
var cooldown := 0
var running := false
var alive := true
# How much of a lit marker is red (1 = all). main.gd drains it during the
# "your move" freeze.
var marker_fill := 1.0
var _markers: Array[Sprite2D] = []   # forward, vertical, diagonal
# For each teleport (forward, vertical, diagonal): the x (tiles) of the enemy
# it would slash right now, or NAN. main.gd sets these.
var target_x: Array = [NAN, NAN, NAN]
var _marker_lit_mix: Array = [0.0, 0.0, 0.0]
var frozen := false      # kill pause: hold the current animation frame

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

	zap_fx = Fx.new()
	zap_fx.top_level = true   # world coordinates, drawn over her
	add_child(zap_fx)

	for i in 3:
		var m := Sprite2D.new()
		m.texture = MARKER_KATANA
		m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = MARKER_SHADER
		m.material = mat
		add_child(m)
		_markers.append(m)

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
	var start := sword_point(move, from_feet, from_row)
	var end := sword_point(move, to_feet, row)
	# Diagonal: turned to lie along the line. From the floor it's rotated
	# (edge ends up facing down, back toward the floor); from the ceiling it's
	# mirrored first (edge facing up, back toward the ceiling).
	var sword_row := Rules.Row.FLOOR if diagonal else from_row
	if diagonal and from_row == Rules.Row.CEILING:
		sword_row = Rules.Row.CEILING   # _sprite_at mirrors it top-to-bottom
	var flying := _sprite_at(sword, centre, start, sword_row)
	if diagonal:
		var drawn := DIAGONAL_SWORD_ANGLE if sword_row == Rules.Row.FLOOR else -DIAGONAL_SWORD_ANGLE
		flying.rotation = (end - start).angle() - drawn
	flying.z_index = 2
	var ft := flying.create_tween()
	ft.tween_property(flying, "global_position", end, SWORD_FLIGHT)
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
		# Forward and diagonal: each copy's sword sits on the teleport line
		# (the line runs between the sword positions, not her feet).
		var at := from_feet.lerp(to_feet, k)
		if not vertical:
			at = start.lerp(end, k) - sword_point(move, Vector2.ZERO, on_row)
		# Nearer her = a bit stronger.
		_ghost(tex, feet, at, on_row, GHOST_TRAIL_FILL, Color(0, 0, 0, 0),
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


# Her death: she's knocked back a little and fizzles out, as if zapped.
const DISSOLVE_SHADER := preload("res://shaders/dissolve.gdshader")
const DEATH_PUSH := Vector2(-170, -60)   # pixels/s, slowing down
const DEATH_TILT := -0.5                 # radians she tips back by
const DISSOLVE_TIME := 0.55              # seconds (game time, so the slow motion stretches it)
const FLICKER_EVERY := 0.06              # seconds (real time): the frozen lightning redraws this often
const FREEZE_SPARKLE := 0.14             # share of her pixels glowing in the death freeze
var _flicker_timer := 0.0
# A ring of her own lightning looping around her while she dies, then a last
# burst as she finishes dissolving.
const DEATH_RING_FPS := 14.0
const DEATH_RING_SCALE := 1.15
const FINAL_BURST_AT := 0.85             # dissolve amount when she bursts
var _death_ring: Sprite2D
var _ring_time := 0.0
var _burst_done := false
const BODY_CENTRE := Vector2(0, -54)     # her body's middle, from her feet (local, before tilt)
# Her own effects layer, drawn over her, for the lightning. main.gd slows and
# freezes it with the death moment like the other effects.
var zap_fx: Fx
# Her katana stays in her right hand as she dies (the far arm, so it's drawn
# behind her; blade angled down and back) and fizzles out with her.
const KATANA := preload("res://assets/sprites/katana.png")   # tip up, hilt at the bottom
const FALL_HAND := Vector2(35, 56)        # her right hand in the fall frames (art pixels)
const KATANA_HELD_ANGLE := 3.7            # radians: tip down and back
const KATANA_GRIP := 5.0                  # art pixels of hilt inside her hand
var _katana: Sprite2D
var _dissolve := 0.0
var _dissolve_material: ShaderMaterial


func die(_kind: String) -> void:
	_striking = false
	alive = false
	_hidden_left = 0.0
	_sprite.visible = true
	_play("fall")   # held during the freeze, then plays as she dissolves
	_death_velocity = DEATH_PUSH if row == Rules.Row.FLOOR else Vector2(DEATH_PUSH.x, -DEATH_PUSH.y)
	# The katana in her hand: a child of her, so it tilts, drifts and flips
	# with her, and shares her dissolve.
	_katana = Sprite2D.new()
	_katana.texture = KATANA
	_katana.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_katana.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_katana.rotation = KATANA_HELD_ANGLE
	var hand := (FALL_HAND - FEET) * SPRITE_SCALE
	var blade_dir := Vector2(sin(KATANA_HELD_ANGLE), -cos(KATANA_HELD_ANGLE))   # from hilt to tip
	var half := KATANA.get_height() * 0.5
	_katana.position = hand + blade_dir * (half - KATANA_GRIP) * SPRITE_SCALE
	_katana.z_index = -1   # her right arm is the far one: behind her body
	add_child(_katana)
	_dissolve_material = ShaderMaterial.new()
	_dissolve_material.shader = DISSOLVE_SHADER
	_sprite.material = _dissolve_material
	_katana.material = _dissolve_material
	# Already crackling in the death freeze (and flickering: see _process).
	_crackle(Vector2.ZERO, 4, 3)
	_death_ring = Sprite2D.new()
	_death_ring.texture = Fx.BOLT_SHEETS[Fx.Bolt.RING]
	_death_ring.hframes = Fx.BOLT_FRAMES[Fx.Bolt.RING]
	_death_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_death_ring.position = BODY_CENTRE
	_death_ring.scale = Vector2.ONE * DEATH_RING_SCALE
	_death_ring.z_index = 1
	add_child(_death_ring)


## Called with game time (0 during the death freeze, slowed in the slow
## motion): she drifts back, tips, and fizzles out with crackles of lightning.
func animate_death(delta: float) -> void:
	if delta <= 0.0:
		return
	_death_velocity *= exp(-3.0 * delta)
	_death_offset += _death_velocity * delta
	rotation = lerpf(rotation, DEATH_TILT, 1.0 - exp(-4.0 * delta))
	_dissolve = minf(_dissolve + delta / DISSOLVE_TIME, 1.0)
	_dissolve_material.set_shader_parameter("amount", _dissolve)
	if zap_fx:
		zap_fx.bolt_alpha = 1.0 - _dissolve


## Lightning over her body and along her sword, moving with `vel`.
func _crackle(vel: Vector2, arcs: int, sparks: int) -> void:
	if zap_fx == null:
		return
	zap_fx.zap(to_global(BODY_CENTRE), arcs, vel, Vector2(16, 30), sparks)
	if _katana:
		var half := KATANA.get_height() * 0.5
		zap_fx.zap_line(_katana.to_global(Vector2(0, half)), _katana.to_global(Vector2(0, -half)), vel)


func _process(delta: float) -> void:
	position = Vector2(x * Rules.TILE, Rules.surface_y(row)) + _death_offset
	# On the ceiling the whole player (sprite and markers) is upside down.
	scale.y = -1.0 if row == Rules.Row.CEILING else 1.0

	if _arc_time > ARC_NONE:
		_arc_time += delta
		_update_arc()
	# Death: the lightning flickers on real time (freeze, slow motion and
	# all) as long as there's some of her left, moving with her body.
	if _death_ring:
		# Loops on real time, a new turn each time round, fading as she goes.
		_ring_time += delta
		var n: int = Fx.BOLT_FRAMES[Fx.Bolt.RING]
		var step := int(_ring_time * DEATH_RING_FPS)
		if step % n == 0 and _death_ring.frame != 0:
			_death_ring.rotation = randf() * TAU
		_death_ring.frame = step % n
		_death_ring.modulate.a = 0.8 * clampf(1.0 - _dissolve / FINAL_BURST_AT, 0.0, 1.0)
	if not alive and zap_fx and not _burst_done and _dissolve >= FINAL_BURST_AT:
		# What's left of her pops: the shards at the end of the strike animation.
		_burst_done = true
		var burst_y := 215.0 - 128.0   # the burst sits this far below the frame's centre
		zap_fx.bolt(Fx.Bolt.STRIKE, to_global(BODY_CENTRE) - Vector2(0, burst_y * 1.3), 0.0, Vector2.ONE * 1.3, 16.0, 3)
		if _death_ring:
			_death_ring.queue_free()
			_death_ring = null
	if not alive and zap_fx and _dissolve < 0.95:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = FLICKER_EVERY
			zap_fx.clear_bolts()
			if frozen:
				_crackle(Vector2.ZERO, 4, 0)
				# Her pixels already flash (re-scattered each flicker); she
				# only starts disappearing when time moves again.
				_dissolve_material.set_shader_parameter("sparkle", FREEZE_SPARKLE)
				_dissolve_material.set_shader_parameter("seed", randf() * 100.0)
			else:
				_crackle(_death_velocity, 3, 1)
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

	_update_markers(delta)
	queue_redraw()
	_hitbox.queue_redraw()


func _draw() -> void:
	for m in _markers:
		m.visible = alive
	if not alive:
		return
	var t := Rules.TILE
	# In local coordinates the other row is always ROW_GAP "up" (-y): when
	# the player is flipped onto the ceiling, that maps down to the floor.
	var gap := Rules.ROW_GAP * t

	var fwd := Rules.FORWARD * t
	# The line under each katana spans that teleport's landing zone: an enemy
	# touching it dies if you make that move now.
	var zf := Rules.marker_zone(Rules.Move.FORWARD) * t
	var zv := Rules.marker_zone(Rules.Move.VERTICAL) * t
	var zd := Rules.marker_zone(Rules.Move.DIAGONAL) * t
	# Forward: same row. Vertical and diagonal: the other row.
	_draw_zone_line(fwd - zf.x, fwd + zf.y, 3.0, target_x[0])
	_draw_zone_line(-zv.x, zv.y, -gap - 3.0, target_x[1])
	_draw_zone_line(fwd - zd.x, fwd + zd.y, -gap - 3.0, target_x[2])


## The line on the floor/ceiling spanning a landing zone [x0, x1] (local
## pixels). Plain, except the part the targeted enemy (at enemy_x tiles, or
## NAN) is standing on, which is red.
func _draw_zone_line(x0: float, x1: float, line_y: float, enemy_x: float) -> void:
	var plain := MARKER_READY if cooldown == 0 else MARKER_COOLDOWN
	draw_line(Vector2(x0, line_y), Vector2(x1, line_y), plain, 3.0)
	if is_nan(enemy_x):
		return
	var t := Rules.TILE
	var feet := (enemy_x - x) * t
	var a := maxf(x0, feet - Rules.ENEMY_HALF_WIDTH * t)
	var b := minf(x1, feet + Rules.ENEMY_HALF_WIDTH * t)
	if b > a:
		draw_line(Vector2(a, line_y), Vector2(b, line_y), MARKER_LIT, 4.0)


## Places the three katana markers: over the landing spot, or over the head
## of the enemy that teleport would slash (sliding there, snapping back).
func _update_markers(delta: float) -> void:
	var t := Rules.TILE
	var gap := Rules.ROW_GAP * t
	var plain := MARKER_READY if cooldown == 0 else MARKER_COOLDOWN
	var s := MARKER_KATANA_SCALE
	for i in 3:
		var m := _markers[i]
		var move: int = [Rules.Move.FORWARD, Rules.Move.VERTICAL, Rules.Move.DIAGONAL][i]
		var zone := Rules.marker_zone(move) * t
		var home_x := Rules.move_dx(move) * t + (zone.y - zone.x) * 0.5
		var own_row := i == 0
		# Local y: her row's surface is 0 and "up" is -y; the other row's
		# surface is -gap and its "up" (into the corridor) is +y.
		var y := -MARKER_HEIGHT * t if own_row else -gap + MARKER_HEIGHT * t
		# Pointing toward the row it marks (the tip toward the enemy's head).
		m.scale = Vector2(s, s if own_row else -s)
		var lit := not is_nan(target_x[i])
		var want := Vector2((float(target_x[i]) - x) * t, y) if lit else Vector2(home_x, y)
		# Glide there (onto the enemy, or back home), easing out.
		var k := 1.0 - exp(-MARKER_FOLLOW_RATE * delta)
		m.position = m.position.lerp(want, k)
		m.position.y = y   # only x glides; the height is fixed per row
		_marker_lit_mix[i] = lerpf(float(_marker_lit_mix[i]), 1.0 if lit else 0.0, 1.0 - exp(-MARKER_COLOUR_RATE * delta))
		var mat := m.material as ShaderMaterial
		mat.set_shader_parameter("plain", plain)
		mat.set_shader_parameter("lit", MARKER_LIT)
		mat.set_shader_parameter("lit_mix", _marker_lit_mix[i])
		mat.set_shader_parameter("fill", marker_fill if lit else 1.0)


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

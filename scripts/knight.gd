class_name Knight
extends Enemy
## The chase enemy (debuts in level 9): a knight who takes several hits. Each
## hit he blinks to one of her three landing spots, chosen when his chain was
## generated (so the chain is provably catchable), and you chase him down.
##
## You can teleport past him, but not run past him across the rows: while
## she's straight across from him (he's under her across marker) he winds up
## (sound, sword raised), and if she runs on out of reach, or a freeze ends
## (dropped) with her there, he teleports to her and cuts her down. Same if a
## freeze ends with him hit but not finished and within a teleport of her.
## main.gd checks this every frame; ChunkSolver mirrors the running part.
## Art: "Hero Knight" (CC0), assets/sprites/hero_knight.

const K_IDLE := preload("res://assets/sprites/hero_knight/idle.png")
const K_DEATH := preload("res://assets/sprites/hero_knight/death.png")
const K_ATTACK := preload("res://assets/sprites/hero_knight/attack.png")   # "Attack1": his clash swings
const K_ATTACK2 := preload("res://assets/sprites/hero_knight/attack2.png") # "Attack2": the killing blow
const K_FRAME := Vector2i(180, 180)
const K_FEET := Vector2(94, 114)
const K_SCALE := 1.9
const K_IDLE_FPS := 10.0
const K_DEATH_FPS := 14.0
const K_ATTACK_FPS := 16.0
const K_ATTACK_START := 2
const KILL_SLASH_FRAME := 3         # "Attack2"'s big arc: held in the death freeze
const KILL_DISTANCE := 2.6          # tiles ahead of her he swings his killing blow from
const CLASH_FRAMES := [2, 3, 4, 5, 6]   # "Attack1" from the swing on
const CLASH_HOLD_FRAME := 3        # his arc at its biggest: held through the clash beat
const CLASH_TIME := 0.32            # seconds his clash swing (left where he was) plays
const SLASH_OUTLINE := Color(0.35, 1.0, 0.45, 1.0)   # green outline while he swings

## Every spot he'll be in, in order: Vector2(tile x, row). path[0] is where
## he starts; each hit moves him to the next one.
var path: Array[Vector2] = []
var step_index := 0
## True once he's been hit (and not yet killed): he's in a duel with her.
var engaged := false
## True while she's straight across from him: he's winding up to strike.
var threat := false
var _slashing := false   # the killing blow: green outline held
var _arc: AnimatedSprite2D
## Where his body goes in a clash swing: a layer above her (set by main.gd).
static var front_parent: Node = null


func _part_material(part: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("white_part", part)
	return m
const WINDUP_FRAME := 1             # sword raised, from his attack animation


func hits_left() -> int:
	return path.size() - step_index


func _ready() -> void:
	if not path.is_empty():
		tile_x = path[0].x
		row = int(path[0].y)
	_place()
	# His slash arcs (the white in his attack frames) go behind him: a copy
	# of him drawing only them, underneath.
	_arc = AnimatedSprite2D.new()
	_arc.sprite_frames = _build_knight_frames()
	_arc.centered = false
	_arc.offset = Vector2(-(K_FRAME.x - K_FEET.x), -K_FEET.y)
	_arc.scale = Vector2(K_SCALE, K_SCALE)
	_arc.flip_h = true
	_arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arc.material = _part_material(2)
	add_child(_arc)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _arc.sprite_frames
	_sprite.centered = false
	_sprite.offset = Vector2(-(K_FRAME.x - K_FEET.x), -K_FEET.y)
	_sprite.scale = Vector2(K_SCALE, K_SCALE)
	_sprite.flip_h = true   # the art faces right; he faces her (left)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = _part_material(1)
	_sprite.material = _material
	add_child(_sprite)
	_sprite.play("idle")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("idle")
	_sprite.animation_finished.connect(_on_animation_finished)


func _place() -> void:
	position = Vector2(tile_x * Rules.TILE, Rules.surface_y(row))
	scale.y = -1.0 if row == Rules.Row.CEILING else 1.0


func _build_knight_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for spec in [["idle", K_IDLE, K_IDLE_FPS, true], ["death", K_DEATH, K_DEATH_FPS, false],
			["attack", K_ATTACK, K_ATTACK_FPS, false], ["kill", K_ATTACK2, K_ATTACK_FPS, false]]:
		var sheet: Texture2D = spec[1]
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		frames.set_animation_loop(spec[0], spec[3])
		for i in sheet.get_width() / K_FRAME.x:
			var tex := AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(Vector2(i * K_FRAME.x, 0), Vector2(K_FRAME))
			frames.add_frame(spec[0], tex)
	return frames


## Hit but not finished: leaves a white flash where he was and blinks to his
## next spot. Returns the spot he left (pixels, body centre).
## `beat`: seconds his swing holds where he was before he reappears.
func blink(beat := 0.0) -> Vector2:
	var from := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	_leave_ghost(beat)
	if beat > 0.0:
		visible = false
		get_tree().create_timer(beat).timeout.connect(func() -> void:
			if is_instance_valid(self):
				visible = true)
	engaged = true
	step_index += 1
	tile_x = path[step_index].x
	row = int(path[step_index].y)
	_place()
	threat = false
	if _sprite:
		_sprite.play("idle")
	return from


## His clash swing, left where he was as he blinks away: "Attack1" from the
## swing on, with a green outline, then fading.
func _leave_ghost(beat := 0.0) -> void:
	if get_parent() == null or _sprite == null:
		return
	var tex := AtlasTexture.new()
	tex.atlas = K_ATTACK
	tex.region = Rect2(Vector2(CLASH_FRAMES[0] * K_FRAME.x, 0), Vector2(K_FRAME))
	# His arc goes behind everything; his body in front of her and her slash
	# (front_parent), so the clash reads.
	var parts: Array[Node2D] = []
	for part in [2, 1]:
		var holder := Node2D.new()
		holder.position = position
		holder.scale = Vector2(K_SCALE, K_SCALE * scale.y)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = _sprite.offset
		s.flip_h = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := _part_material(part)
		if part == 1:
			mat.set_shader_parameter("outline_color", SLASH_OUTLINE)
			mat.set_shader_parameter("glint", 1.0)
		s.material = mat
		holder.add_child(s)
		var parent: Node = front_parent if part == 1 and front_parent else get_parent()
		parent.add_child(holder)
		parts.append(holder)
	var tween := parts[0].create_tween()
	# The swing up to its biggest arc, held through the beat, then the rest.
	var held := CLASH_FRAMES.find(CLASH_HOLD_FRAME)
	var show := func(f: float) -> void:
		var i := clampi(int(f), 0, CLASH_FRAMES.size() - 1)
		tex.region = Rect2(Vector2(CLASH_FRAMES[i] * K_FRAME.x, 0), Vector2(K_FRAME))
	tween.tween_method(show, 0.0, float(held), CLASH_TIME * 0.4)
	tween.tween_interval(maxf(beat - CLASH_TIME * 0.4, 0.0))
	tween.tween_method(show, float(held), float(CLASH_FRAMES.size()), CLASH_TIME * 0.6)
	tween.tween_method(func(a: float) -> void:
		for p in parts:
			if is_instance_valid(p):
				p.modulate.a = a, 1.0, 0.0, 0.15)
	tween.tween_callback(func() -> void:
		for p in parts:
			if is_instance_valid(p):
				p.queue_free())


## She's straight across from him: he raises his sword and holds it.
func warn() -> void:
	threat = true
	if alive and _sprite:
		_sprite.play("attack")
		_sprite.frame = WINDUP_FRAME
		_sprite.pause()


## She's no longer across from him.
func calm() -> void:
	threat = false
	if alive and _sprite and _sprite.animation == "attack":
		_sprite.play("idle")


## He teleports to her (just ahead of her, in her row) and cuts her down.
## Returns the spot he left (pixels, body centre).
func pounce(her_x: float, her_row: int) -> Vector2:
	var from := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	row = her_row
	slash(her_x)
	return from


## The killing blow (she ran into him, or he teleported to her): "Attack2" on
## its big arc (that's what the death freeze holds), outlined green.
func slash(her_x: float) -> void:
	threat = false
	# Far enough off that his arc lands on her rather than him standing in her.
	tile_x = her_x + KILL_DISTANCE
	_place()
	if _sprite:
		_sprite.play("kill")
		_sprite.frame = KILL_SLASH_FRAME
		_material.set_shader_parameter("outline_color", SLASH_OUTLINE)
		_material.set_shader_parameter("glint", 1.0)
		# His body over her (and her effects) for the killing blow; the arc
		# stays behind.
		if front_parent and _sprite.get_parent() == self:
			var holder := Node2D.new()
			front_parent.add_child(holder)
			holder.global_position = global_position
			holder.scale = scale
			_sprite.reparent(holder, false)
			tree_exiting.connect(holder.queue_free)
	_slashing = true


func _process(delta: float) -> void:
	if _arc and _sprite:
		if _arc.animation != _sprite.animation:
			_arc.play(_sprite.animation)
		_arc.frame = _sprite.frame
		_arc.pause()
	if _slashing:
		return   # keep the green outline (Enemy would fade it to the target glint)
	super(delta)


func clear_glint() -> void:
	if not _slashing:
		super()


func attack() -> void:
	if alive and _sprite:
		_sprite.play("attack")
		_sprite.frame = K_ATTACK_START

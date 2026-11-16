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
const K_TAKE_HIT := preload("res://assets/sprites/hero_knight/take_hit.png") # struck in the level-10 finisher
const K_HIT_FRAMES := 3   # recoil, white flash, recoil (not the recovery after)
const K_HIT_FPS := 12.0
const K_FRAME := Vector2i(180, 180)
const K_FEET := Vector2(94, 114)
const K_SCALE := 1.9
const K_IDLE_FPS := 10.0
const K_DEATH_FPS := 14.0
const K_ATTACK_FPS := 16.0
const K_ATTACK_START := 2
const KILL_SLASH_FRAME := 3         # "Attack2"'s big arc: held in the death freeze
# On the frames with the biggest arcs the art paints the arc over his head
# and body, so with the arc moved behind him his body is taken from the next
# frame, where it's whole: frame -> frame to draw his body from.
const KILL_BODY_FROM := {3: 4}
# His clash swing: either attack, at random. Per attack: the sheet, the
# frames from the swing on, the frame held through the clash beat, and
# frame -> frame his body is drawn from (see KILL_BODY_FROM).
const CLASH_SWINGS := [
	{"sheet": K_ATTACK, "frames": [2, 3, 4, 5, 6], "hold": 3, "body_from": {3: 5, 4: 5}},
	{"sheet": K_ATTACK2, "frames": [2, 3, 4, 5, 6], "hold": 3, "body_from": {3: 4}},
]
# Which of his swings answers each of her three strike poses, and how far
# (tiles) past his real spot it's drawn so the two read as a clash: her 1 vs
# his 1, her 2 vs his 2 (his lunge, so further back), her 3 vs his 1.
const CLASH_BY_POSE := [
	{"swing": 0, "gap": 1.3 + 1.0 / 3.0},
	{"swing": 1, "gap": 2.6 + 0.75},
	{"swing": 0, "gap": 1.3 + 1.0 / 3.0},
]
const KILL_DISTANCE := 2.6          # tiles ahead of her he swings his killing blow from
const AFTERIMAGE_FADE := 0.35       # seconds his clash swing lingers after he blinks away
const CLASH_TIME := 0.25           # seconds his clash swing (left where he was) plays
const SLASH_OUTLINE := Color(0.35, 1.0, 0.45, 1.0)   # green outline while he swings

## Every spot he'll be in, in order: Vector2(tile x, row). path[0] is where
## he starts; each hit moves him to the next one.
var path: Array[Vector2] = []
var step_index := 0
## True once he's been hit (and not yet killed): he's in a duel with her.
var engaged := false
## True while she's straight across from him: he's winding up to strike.
var threat := false
var warned := false   # he's already given his wind-up swish once
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
			["attack", K_ATTACK, K_ATTACK_FPS, false], ["kill", K_ATTACK2, K_ATTACK_FPS, false],
			["hit", K_TAKE_HIT, K_HIT_FPS, false, K_HIT_FRAMES]]:
		var sheet: Texture2D = spec[1]
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		frames.set_animation_loop(spec[0], spec[3])
		var count: int = spec[4] if spec.size() > 4 else sheet.get_width() / K_FRAME.x
		for i in count:
			var tex := AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(Vector2(i * K_FRAME.x, 0), Vector2(K_FRAME))
			frames.add_frame(spec[0], tex)
	return frames


## Struck (the level-10 finisher): his take-hit, ending on the recoil, held
## until the next strike.
func take_hit() -> void:
	if _sprite:
		_sprite.speed_scale = 1.0
		_sprite.play("hit")
		_sprite.frame = 0


## The finisher's over: now he falls.
func fall() -> void:
	if _sprite:
		_sprite.speed_scale = 1.0
		_sprite.play("death")


## Hit but not finished: leaves a white flash where he was and blinks to his
## next spot. Returns the spot he left (pixels, body centre).
## `beat`: seconds his swing holds where he was before he reappears.
## `her_pose`: the strike pose she hit him with (picks his swing).
## `reappear`: seconds until he shows at his new spot (< beat, so she can
## see where he went while the clash still plays out where he was).
func blink(beat := 0.0, her_pose := 0, reappear := -1.0) -> Vector2:
	var from := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	_leave_ghost(beat, her_pose)
	if reappear < 0.0:
		reappear = beat
	if reappear > 0.0:
		visible = false
		get_tree().create_timer(reappear).timeout.connect(func() -> void:
			if is_instance_valid(self):
				visible = true)
	engaged = true
	step_index += 1
	tile_x = path[step_index].x
	row = int(path[step_index].y)
	_place()
	threat = false
	if _sprite:
		# Engaged now: he waits at his new spot with his sword raised (the
		# wind-up pose), not idle.
		_sprite.play("attack")
		_sprite.frame = WINDUP_FRAME
		_sprite.pause()
	return from


## His clash swing, left where he was as he blinks away: "Attack1" from the
## swing on, with a green outline, then fading.
func _leave_ghost(beat := 0.0, her_pose := 0) -> void:
	if get_parent() == null or _sprite == null:
		return
	var answer: Dictionary = CLASH_BY_POSE[clampi(her_pose, 0, CLASH_BY_POSE.size() - 1)]
	var swing: Dictionary = CLASH_SWINGS[answer["swing"]]
	var frames: Array = swing["frames"]
	var body_from: Dictionary = swing["body_from"]
	var arc_tex := AtlasTexture.new()
	arc_tex.atlas = swing["sheet"]
	var body_tex := AtlasTexture.new()
	body_tex.atlas = swing["sheet"]
	# His arc goes behind everything; his body in front of her and her slash
	# (front_parent), so the clash reads.
	var parts: Array[Node2D] = []
	for part in [2, 1]:
		var holder := Node2D.new()
		# Further from her than his real spot (by the swing's "gap", tiles),
		# so the clash reads as two swords meeting rather than one figure.
		holder.position = position + Vector2(float(answer["gap"]) * Rules.TILE, 0)
		holder.scale = Vector2(K_SCALE, K_SCALE * scale.y)
		var s := Sprite2D.new()
		s.texture = arc_tex if part == 2 else body_tex
		s.centered = false
		s.offset = _sprite.offset
		s.flip_h = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := _part_material(part)
		mat.set_shader_parameter("outline_color", SLASH_OUTLINE)
		mat.set_shader_parameter("glint", 1.0)
		s.material = mat
		holder.add_child(s)
		var parent: Node = front_parent if part == 1 and front_parent else get_parent()
		parent.add_child(holder)
		parts.append(holder)
	var tween := parts[0].create_tween()
	# The swing up to its biggest arc, held through the beat, then the rest.
	var held := frames.find(swing["hold"])
	var show := func(f: float) -> void:
		var frame: int = frames[clampi(int(f), 0, frames.size() - 1)]
		arc_tex.region = Rect2(Vector2(frame * K_FRAME.x, 0), Vector2(K_FRAME))
		var body: int = body_from.get(frame, frame)
		body_tex.region = Rect2(Vector2(body * K_FRAME.x, 0), Vector2(K_FRAME))
	show.call(0.0)
	tween.tween_method(show, 0.0, float(held), CLASH_TIME * 0.4)
	tween.tween_interval(maxf(beat - CLASH_TIME * 0.4, 0.0))
	# He's gone: what's left is an afterimage of the clash, fading.
	tween.tween_method(func(a: float) -> void:
		for p in parts:
			if is_instance_valid(p):
				p.modulate.a = a, 0.8, 0.0, AFTERIMAGE_FADE)
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
## `side`: 1 = he lands in front of her (facing back at her), -1 = behind
## her (facing forward), when two strike at once.
func pounce(her_x: float, her_row: int, side := 1.0) -> Vector2:
	var from := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	row = her_row
	slash(her_x, side)
	return from


## The killing blow (she ran into him, or he teleported to her): "Attack2" on
## its big arc (that's what the death freeze holds), outlined green.
func slash(her_x: float, side := 1.0) -> void:
	threat = false
	# Far enough off that his arc lands on her rather than him standing in her.
	tile_x = her_x + KILL_DISTANCE * side
	scale.x = side   # behind her: turned round to face her
	_place()
	if _sprite:
		_sprite.play("kill")
		_sprite.frame = KILL_BODY_FROM.get(KILL_SLASH_FRAME, KILL_SLASH_FRAME)
		_sprite.pause()
		for m in [_material, _arc.material]:
			m.set_shader_parameter("outline_color", SLASH_OUTLINE)
			m.set_shader_parameter("glint", 1.0)
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
		_arc.frame = KILL_SLASH_FRAME if _slashing else _sprite.frame
		_arc.pause()
	if _slashing:
		return   # keep the green outline (Enemy would fade it to the target glint)
	super(delta)
	if _arc:
		# Only the killing blow's follow-through outlines the arc (fading).
		_arc.material.set_shader_parameter("glint", _glint if _sprite.animation == "kill" else 0.0)


func clear_glint() -> void:
	if not _slashing:
		super()


## After the killing blow's freeze (the world starts moving again): he
## follows through with the rest of the swing, then goes back to idle.
func set_anim_speed(value: float) -> void:
	super(value)
	if _slashing and value > 0.0 and _sprite:
		_slashing = false   # the green outline fades (Enemy._process)
		targeted = false
		_glint = 1.0
		_sprite.play("kill")


func _on_animation_finished() -> void:
	if _sprite.animation == "kill" or _sprite.animation == "attack":
		_sprite.play("idle")
	else:
		super()


func attack() -> void:
	if alive and _sprite:
		_sprite.play("attack")
		_sprite.frame = K_ATTACK_START

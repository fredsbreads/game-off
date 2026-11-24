class_name Enemy
extends Node2D
## The default enemy: a sword fighter on the floor, or hanging upside down
## from the ceiling. Kills you if you run into it in its row; dies if you
## teleport onto it. Art: "Martial Hero 3" (CC0), assets/sprites/martial_hero.
##
## Only the look lives here. Hits and kills use the rules' numbers (an enemy
## counts as Rules.ENEMY_HALF_WIDTH * 2 tiles wide), not the art.

const IDLE := preload("res://assets/sprites/martial_hero/idle.png")
const DEATH := preload("res://assets/sprites/martial_hero/death.png")
const ATTACK := preload("res://assets/sprites/martial_hero/attack.png")   # "Attack2" in the pack
const TAKE_HIT := preload("res://assets/sprites/martial_hero/take_hit.png")   # "Take Hit": struck in the streak finisher
const FRAME := Vector2i(126, 126)
# The point between his feet inside a frame: this sits on the floor.
const FEET := Vector2(66, 82)
# Drawn size: each art pixel is this many game units (he's ~82 units tall,
# a little shorter than her).
const SPRITE_SCALE := 2.0
const IDLE_FPS := 10.0
const DEATH_FPS := 16.0
const ATTACK_FPS := 14.0
const HIT_FPS := 12.0
const REEL_FRAME := 2   # his death's stumble (sword dropping): held between finisher strikes
const HIT_FIT := 0.8   # a take-hit squeezed between quick strikes takes this much of the gap
# Start the attack on the slash frame, so it lands right as she touches him (the first
# frames are a wind-up).
const ATTACK_START_FRAME := 3
# Where he stands when he cuts her down: this far ahead of her (tiles), so she's
# at the edge of his slash (its arc reaches ~1.85 tiles).
const GRUNT_KILL_DISTANCE := 1.9
const OUTLINE_SHADER := preload("res://shaders/enemy_outline.gdshader")
const GLINT_RATE := 12.0    # how fast the red outline fades in/out

var tile_x := 0.0
var row := Rules.Row.FLOOR
var alive := true
## Set once he's behind her and out of reach while alive: he got away
## (that ends her sweep, see main.gd).
var escaped := false
## True while a teleport would slash him (main.gd sets it every frame): he
## gets a thin red outline.
var targeted := false
var _glint := 0.0
var _material: ShaderMaterial
var _flash_tween: Tween

var _sprite: AnimatedSprite2D


func _ready() -> void:
	position = Vector2(tile_x * Rules.TILE, Rules.surface_y(row))
	scale.y = -1.0 if row == Rules.Row.CEILING else 1.0
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.centered = false
	# Flipped, so his feet are FEET mirrored inside the frame.
	_sprite.offset = Vector2(-(FRAME.x - FEET.x), -FEET.y)
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.flip_h = true   # the art faces right; he faces her (left)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_sprite.material = _material
	add_child(_sprite)
	_sprite.play("idle")
	# Don't have every enemy breathe in sync.
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("idle")
	_sprite.animation_finished.connect(_on_animation_finished)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for spec in [["idle", IDLE, IDLE_FPS, true], ["death", DEATH, DEATH_FPS, false], ["attack", ATTACK, ATTACK_FPS, false], ["hit", TAKE_HIT, HIT_FPS, false]]:
		var sheet: Texture2D = spec[1]
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		frames.set_animation_loop(spec[0], spec[3])
		for i in sheet.get_width() / FRAME.x:
			var tex := AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(Vector2(i * FRAME.x, 0), Vector2(FRAME))
			frames.add_frame(spec[0], tex)
	return frames


func _process(delta: float) -> void:
	var want := 1.0 if targeted and alive else 0.0
	_glint = lerpf(_glint, want, 1.0 - exp(-GLINT_RATE * delta))
	if _material:
		_material.set_shader_parameter("glint", _glint)


## Drop the red glint at once (no fade), e.g. when she dies.
func clear_glint() -> void:
	targeted = false
	_glint = 0.0
	if _material:
		_material.set_shader_parameter("glint", 0.0)


## Killed: he's out of the game at once (alive = false); the body plays the
## death animation and stays where he fell.
func die() -> void:
	alive = false
	if _idle_held:
		hold_idle(false)   # (his death plays at its own speed)
	if _sprite:
		_sprite.play("death")
	else:
		queue_free()


## Struck in the streak finisher: his take-hit (recoil, a white flash,
## recoil), held on its last frame until the next strike. `span`: seconds
## until the next strike (0: none): a quick finisher's strikes come faster
## than the take-hit, so it plays faster, to show whole on every one...
func take_hit(span := 0.0) -> void:
	var speed := hit_speed(span)
	if _sprite:
		_sprite.speed_scale = speed
		_sprite.play("hit")
		_sprite.frame = 0
	hit_flash(speed)


## How much faster the take-hit plays to fit in `span` seconds (with a little
## of its last frame left to see).
func hit_speed(span: float) -> float:
	if span <= 0.0 or _sprite == null or not _sprite.sprite_frames.has_animation("hit"):
		return 1.0
	var frames := _sprite.sprite_frames
	var length := float(frames.get_frame_count("hit")) / frames.get_animation_speed("hit")
	return maxf(1.0, length / (span * HIT_FIT))


## The white flash on a strike's second beat (the art has none of its own).
func hit_flash(speed := 1.0) -> void:
	if _material == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	var beat := 1.0 / HIT_FPS / speed
	_material.set_shader_parameter("flash", 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(beat)
	_flash_tween.tween_callback(_material.set_shader_parameter.bind("flash", 1.0))
	_flash_tween.tween_interval(beat)
	_flash_tween.tween_callback(_material.set_shader_parameter.bind("flash", 0.0))


## ...then, when it's over, he falls.
func fall() -> void:
	if _sprite:
		_sprite.speed_scale = 1.0
		if _sprite.animation != "death":
			_sprite.play("death")


## Held still in his idle pose while she's in a chain's freeze (the grey),
## and picks up again where he left off when it's over. Only his idle: a
## death or an attack plays on at its own speed.
var _idle_held := false

func hold_idle(on: bool) -> void:
	if not _sprite or on == _idle_held:
		return
	if on and not (alive and _sprite.animation == "idle"):
		return
	_idle_held = on
	_sprite.speed_scale = 0.0 if on else 1.0


## Slow down or stop his animation (1 = normal, 0 = frozen).
func set_anim_speed(value: float) -> void:
	if _sprite:
		_sprite.speed_scale = value


## She ran into him: he cuts her down. `her_x` (tiles): he's shown standing
## GRUNT_KILL_DISTANCE ahead of her, so she's at the edge of his swing (not inside it).
func attack(her_x := NAN) -> void:
	if alive and _sprite:
		if _idle_held:
			hold_idle(false)
		home_x = tile_x
		if not is_nan(her_x):
			tile_x = her_x + GRUNT_KILL_DISTANCE
			position.x = tile_x * Rules.TILE
		_sprite.play("attack")
		_sprite.frame = ATTACK_START_FRAME


## Where he stood before he stepped in to cut her down (see attack()).
var home_x := 0.0
var _unattack_from := 0.0


## The tutorial's rewind: his slash, backwards, as he slides back to where he
## stood (k: 0 to 1 over it). Then he's idle.
func unattack(k: float) -> void:
	if not _sprite:
		return
	if k <= 0.0:
		_unattack_from = tile_x
		_sprite.speed_scale = 1.0
		_sprite.play_backwards("attack")
	tile_x = lerpf(_unattack_from, home_x, clampf(k, 0.0, 1.0))
	position.x = tile_x * Rules.TILE
	if k >= 1.0:
		tile_x = home_x
		position.x = tile_x * Rules.TILE
		_sprite.play("idle")


func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		_sprite.play("idle")
	elif _sprite.animation == "hit" and not self is Knight:
		# (the grunt) his take-hit ends standing up straight: instead he's held
		# reeling (his death's stumble: its first frames are still upright) until
		# the next strike or his fall.
		_sprite.play("death")
		_sprite.frame = REEL_FRAME
		_sprite.speed_scale = 0.0
	# After "death" the body just stays (level.gd removes it once it's well
	# behind the camera).

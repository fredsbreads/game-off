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
const FRAME := Vector2i(126, 126)
# The point between his feet inside a frame: this sits on the floor.
const FEET := Vector2(66, 82)
# Drawn size: each art pixel is this many game units (he's ~82 units tall,
# a little shorter than her).
const SPRITE_SCALE := 2.0
const IDLE_FPS := 10.0
const DEATH_FPS := 16.0
const ATTACK_FPS := 14.0
# Start the attack on the slash frame, so it lands right as she touches him (the first
# frames are a wind-up).
const ATTACK_START_FRAME := 3
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
	for spec in [["idle", IDLE, IDLE_FPS, true], ["death", DEATH, DEATH_FPS, false], ["attack", ATTACK, ATTACK_FPS, false]]:
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
	if _sprite:
		_sprite.play("death")
	else:
		queue_free()


## Slow down or stop his animation (1 = normal, 0 = frozen).
func set_anim_speed(value: float) -> void:
	if _sprite:
		_sprite.speed_scale = value


## She ran into him: he cuts her down.
func attack() -> void:
	if alive and _sprite:
		_sprite.play("attack")
		_sprite.frame = ATTACK_START_FRAME


func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		_sprite.play("idle")
	# After "death" the body just stays (level.gd removes it once it's well
	# behind the camera).

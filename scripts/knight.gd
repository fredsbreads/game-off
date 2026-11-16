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
const K_ATTACK := preload("res://assets/sprites/hero_knight/attack.png")   # "Attack1" in the pack
const K_TAKE_HIT := preload("res://assets/sprites/hero_knight/take_hit.png")
const K_FRAME := Vector2i(180, 180)
const K_FEET := Vector2(94, 114)
const K_SCALE := 1.6
const K_IDLE_FPS := 10.0
const K_DEATH_FPS := 14.0
const K_ATTACK_FPS := 16.0
const K_ATTACK_START := 2
const HIT_FLASH_FRAME := 1          # the white silhouette in "Take Hit"
const GHOST_FADE := 0.3             # seconds the flash he leaves behind lasts

## Every spot he'll be in, in order: Vector2(tile x, row). path[0] is where
## he starts; each hit moves him to the next one.
var path: Array[Vector2] = []
var step_index := 0
## True once he's been hit (and not yet killed): he's in a duel with her.
var engaged := false
## True while she's straight across from him: he's winding up to strike.
var threat := false
const WINDUP_FRAME := 1             # sword raised, from his attack animation


func hits_left() -> int:
	return path.size() - step_index


func _ready() -> void:
	if not path.is_empty():
		tile_x = path[0].x
		row = int(path[0].y)
	_place()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_knight_frames()
	_sprite.centered = false
	_sprite.offset = Vector2(-(K_FRAME.x - K_FEET.x), -K_FEET.y)
	_sprite.scale = Vector2(K_SCALE, K_SCALE)
	_sprite.flip_h = true   # the art faces right; he faces her (left)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
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
			["attack", K_ATTACK, K_ATTACK_FPS, false]]:
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
func blink() -> Vector2:
	var from := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	_leave_ghost()
	engaged = true
	step_index += 1
	tile_x = path[step_index].x
	row = int(path[step_index].y)
	_place()
	threat = false
	if _sprite:
		_sprite.play("idle")
	return from


func _leave_ghost() -> void:
	if get_parent() == null or _sprite == null:
		return
	var ghost := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = K_TAKE_HIT
	tex.region = Rect2(Vector2(HIT_FLASH_FRAME * K_FRAME.x, 0), Vector2(K_FRAME))
	ghost.texture = tex
	ghost.centered = false
	ghost.offset = _sprite.offset
	ghost.flip_h = true
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.position = position
	ghost.scale = Vector2(K_SCALE, K_SCALE * scale.y)
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE)
	tween.tween_callback(ghost.queue_free)


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
	threat = false
	tile_x = her_x + Rules.HIT_RADIUS * 0.9
	row = her_row
	_place()
	attack()
	return from


func attack() -> void:
	if alive and _sprite:
		_sprite.play("attack")
		_sprite.frame = K_ATTACK_START

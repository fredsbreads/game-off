class_name Shadow
extends Master
## The fourth teleporter (debuts in level 20, Patterns.SHADOW_DEBUT_LEVEL):
## the Shadow, a dark copy of her (she). Everything the master does, she does
## too (and the ninja's and the knight's rules), and she takes the most hits
## (Rules.SHADOW_HITS_MIN-MAX). And she also watches behind (back_aggro): the
## instant the player is past her, to her right, within a teleport's reach in
## either row (Rules.shadow_behind), she teleports to her and cuts her down.
## Close to her, the player is never safe.
## Art: the player's own sprites, darkened, with a red eye
## (tools/build_shadow_sprites.py); black lightning with a red glow; a dark
## smoke flickering round her; dark afterimages where she blinks from.

const S_IDLE := preload("res://assets/sprites/shadow/idle.png")
const S_FALL := preload("res://assets/sprites/shadow/fall.png")
const S_SWINGS := preload("res://assets/sprites/shadow/swings.png")   # per strike pose: bare, with its arc, the arc fading

const SHADOW_ART := {
	"frame": Vector2i(170, 170), "feet": Vector2(84, 123), "scale": Player.SPRITE_SCALE,
	"anims": [["idle", S_IDLE, 8.0, true], ["death", S_FALL, 10.0, false],
		["attack", S_SWINGS, 14.0, false, 3, 3], ["kill", S_SWINGS, 14.0, false, 3, 0],
		["hit", S_FALL, 12.0, false, 1],
		["stance", S_SWINGS, 1.0, false, 1, 6]],
	"kill_frame": 1, "kill_body_from": {},
	"swings": [
		{"sheet": S_SWINGS, "frames": [0, 1, 2], "hold": 1, "body_from": {}},
		{"sheet": S_SWINGS, "frames": [3, 4, 5], "hold": 4, "body_from": {}},
		{"sheet": S_SWINGS, "frames": [6, 7, 8], "hold": 7, "body_from": {}},
	],
	"by_pose": [
		{"swing": 0, "gap": 1.9},
		{"swing": 1, "gap": 2.9},
		{"swing": 2, "gap": 1.9},
	],
	# Each clash, by her strike pose: the Shadow answers with the same pose
	# (a mirror of her), drawn this far (tiles) past its spot.
	"pose_swings": [
		[{"swing": 0, "gap": 3.4}],
		[{"swing": 1, "gap": 3.4}],
		[{"swing": 2, "gap": 3.4}],
	],
	"kill_distance": 3.1,
	"windup_anim": "stance", "windup_frame": 0,
	"engaged_anim": "stance", "engaged_frame": 0,
	"attack_start": 0,
	"lightning": "shadow", "outline": Color(0.62, 0.05, 0.12, 1.0),
	"alert_pitch": 0.8,
}

const SMOKE := Color(0.22, 0.04, 0.26, 0.55)   # her dark aura
const SMOKE_GROW := 1.12                         # (drawn this much bigger than her, behind)
const AFTERIMAGES := 3                           # dark copies where she blinks from
const AFTERIMAGE_TIME := 0.35

var _smoke: AnimatedSprite2D
var _smoke_t := 0.0
var _last_spot := Vector2.INF


func _init() -> void:
	art = SHADOW_ART
	forward_aggro = true
	diag_aggro = true
	back_aggro = true


func _ready() -> void:
	super._ready()
	# A dark copy of her, a little bigger, behind her: her smoke.
	_smoke = AnimatedSprite2D.new()
	_smoke.sprite_frames = _sprite.sprite_frames
	_smoke.centered = false
	_smoke.offset = _sprite.offset
	_smoke.scale = _sprite.scale * SMOKE_GROW
	_smoke.flip_h = true
	_smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_smoke.material = m
	_smoke.modulate = SMOKE
	_smoke.show_behind_parent = true
	add_child(_smoke)
	move_child(_smoke, 0)
	_last_spot = position


func _process(delta: float) -> void:
	super._process(delta)
	if _smoke == null or not is_instance_valid(_sprite):
		return
	# The smoke follows her pose and flickers.
	_smoke.visible = _sprite.visible and alive
	_smoke.animation = _sprite.animation
	_smoke.frame = _sprite.frame
	_smoke_t += delta
	var flick := 0.75 + 0.25 * sin(_smoke_t * 7.0) * sin(_smoke_t * 2.3 + 1.0)
	_smoke.modulate = Color(SMOKE, SMOKE.a * flick)
	_smoke.scale = _sprite.scale * (SMOKE_GROW + 0.03 * sin(_smoke_t * 3.1))
	# She blinked: dark afterimages trail from where she was.
	if _last_spot != Vector2.INF and position.distance_to(_last_spot) > Rules.TILE * 0.9 and alive:
		_afterimages(_last_spot, position)
	_last_spot = position


func _afterimages(from: Vector2, to: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	for i in AFTERIMAGES:
		var k := float(i + 1) / float(AFTERIMAGES + 1)
		var ghost := Sprite2D.new()
		ghost.texture = tex
		ghost.centered = false
		ghost.offset = _sprite.offset
		ghost.flip_h = true
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.position = from.lerp(to, k * 0.6)
		ghost.scale = Vector2(_sprite.scale.x, _sprite.scale.y * scale.y)
		ghost.modulate = Color(0.12, 0.02, 0.16, 0.55 * (1.0 - k * 0.5))
		parent.add_child(ghost)
		var t := ghost.create_tween()
		t.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_TIME)
		t.tween_callback(ghost.queue_free)

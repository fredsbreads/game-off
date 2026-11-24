class_name Shadow
extends Knight
## The Shadow (debuts in level 20, Patterns.SHADOW_DEBUT_LEVEL): a dark copy
## of her, and the last thing the run adds. Always alone in her chain.
##
## She fights in rounds (three at her debut, then two or three). Clash with
## her and time stops while she blinks through
## the three columns on screen, 4-5 times, each blink a move the player could
## make, never back; on every spot but the last she leaves a remnant
## (remnant.gd), and on the last she waits. Then nothing shows how she went:
## the player cuts the remnants in the order she made them (main.gd: any
## other is "Fooled", and the remnants have her), then clashes with her
## again. Her last round's last clash kills her.
## Art: the player's own sprites in dark plum, two red eyes
## (tools/build_shadow_sprites.py), a soft pale glow; black lightning with a
## pale lavender glow.

const S_IDLE := preload("res://assets/sprites/shadow/idle.png")
const S_FALL := preload("res://assets/sprites/shadow/fall.png")
const S_SWINGS := preload("res://assets/sprites/shadow/swings.png")   # per strike pose: bare, with its arc, the arc fading

const SHADOW_ART := {
	"frame": Vector2i(170, 170), "feet": Vector2(84, 123), "scale": Player.SPRITE_SCALE,
	"anims": [["idle", S_IDLE, 8.0, true], ["death", S_FALL, 10.0, true],   # (her death: the player's fall, looping, katana in hand)
		["attack", S_SWINGS, 14.0, false, 3, 3], ["kill", S_SWINGS, 14.0, false, 3, 0],
		["hit", S_FALL, 12.0, false, 1],
		["stance", S_SWINGS, 1.0, false, 1, 3]],   # where she waits: her second strike pose's end (both feet down, sword low)
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
		[{"swing": 0, "gap": 1.9}],
		[{"swing": 1, "gap": 2.9}],
		[{"swing": 2, "gap": 1.9}],
	],
	"kill_distance": 1.6,
	"windup_anim": "stance", "windup_frame": 0,
	"engaged_anim": "stance", "engaged_frame": 0,
	"attack_start": 0,
	"lightning": "shadow", "outline": Color(0.62, 0.05, 0.12, 1.0),
	"alert_pitch": 0.8,
	"hit_flash": true,
}

# Her death's explosion: her colours.
const SHARD_COLOURS := [Color(0.77, 0.7, 0.91), Color(0.44, 0.17, 0.36), Color(0.95, 0.92, 1.0), Color(0.12, 0.07, 0.16)]
const GLOW := Color(0.66, 0.62, 0.84, 0.55)   # her soft pale glow (she reads against the dark)
const GLOW_PX := 2.6                           # its reach past her outline (pixels of the art)

## Every round's spots, in order (Vector2(tile x, row)): the last is where
## that round ends (path[round + 1]); the others get her remnants.
var rounds: Array = []
## This round's remnants, in the order she made them.
var remnants: Array = []
var _glow_t := 0.0


func _init() -> void:
	art = SHADOW_ART
	hides_path = true
	# Before the fight (until the first clash): never safe near her. The
	# master's watch ahead and diagonally, and behind her too
	# (Rules.shadow_behind).
	forward_aggro = true
	diag_aggro = true
	back_aggro = true


## Where she's drawn (pixels, her body's middle).
static func drawn_at(x: float, r: int) -> Vector2:
	return Vector2(x * Rules.TILE, Rules.body_center_y(r))


## Her killing blow (hers and her remnants'): one of the player's two big
## sweeping strikes, at random (swing 0, or swing 1, the one whose end is her
## stance); never the flat one (swing 2).
const KILL_SWINGS := [0, 1]
func _pick_kill() -> void:
	set_kill_swing(self, KILL_SWINGS.pick_random())


static func set_kill_swing(k: Knight, swing: int) -> void:
	var size: Vector2i = SHADOW_ART["frame"]
	for spr in [k._sprite, k._arc]:
		if spr == null:
			continue
		var frames: SpriteFrames = spr.sprite_frames
		frames.clear("kill")
		for i in range(swing * 3, swing * 3 + 3):
			var tex := AtlasTexture.new()
			tex.atlas = S_SWINGS
			tex.region = Rect2(Vector2(i * size.x, 0), Vector2(size))
			frames.add_frame("kill", tex)


## The one to cut next: this round's first remnant still standing, else her.
func next_target() -> Enemy:
	for r in remnants:
		if is_instance_valid(r) and r.alive:
			return r
	return self


func remnants_left() -> int:
	var n := 0
	for r in remnants:
		if is_instance_valid(r) and r.alive:
			n += 1
	return n


func _process(delta: float) -> void:
	super._process(delta)
	_glow_t += delta
	glow(_material, _glow_t, 1.0 if alive else 0.0)
	_update_dissolve(delta)


## Her glow on a sprite's material (hers, a remnant's): pale, flickering.
static func glow(mat: ShaderMaterial, t: float, strength: float) -> void:
	if mat == null:
		return
	var flick := 0.75 + 0.25 * sin(t * 7.0) * sin(t * 2.3 + 1.0)
	mat.set_shader_parameter("aura_color", Color(GLOW, GLOW.a * flick * strength))
	mat.set_shader_parameter("aura_px", GLOW_PX + 0.8 * sin(t * 3.1))


# Her death (Shadow.fall, at the end of main.gd's finish on her): she's pushed
# back, tips, and fizzles out in lavender blocks (the player's own dissolve).
const DISSOLVE_SHADER := preload("res://shaders/dissolve.gdshader")
const DEATH_PUSH := Vector2(150, -50)   # pixels/s (away from the player), slowing down
const DEATH_TILT := 0.35
var _dissolve_delay := -1.0   # < 0: not dissolving
var _dissolve_time := 1.0
var _dissolve_t := 0.0
var _push := Vector2.ZERO
var _fx: Fx


## Fizzle out: after `delay` seconds, over `time`.
func dissolve_out(delay: float, time: float, fx: Fx) -> void:
	if _dissolve_delay >= 0.0 or not visible:
		return   # (already going)
	_dissolve_delay = delay
	_dissolve_time = time
	_dissolve_t = 0.0
	_fx = fx
	_push = Vector2(DEATH_PUSH.x, DEATH_PUSH.y * (-1.0 if row == Rules.Row.CEILING else 1.0))
	var m := ShaderMaterial.new()
	m.shader = DISSOLVE_SHADER
	m.set_shader_parameter("edge_hot", Color(0.95, 0.92, 1.0))
	m.set_shader_parameter("edge_red", Color(0.77, 0.7, 0.91))   # (her lightning's lavender)
	if _sprite:
		_sprite.material = m
	_material = null   # (no glow on her now)


func _update_dissolve(delta: float) -> void:
	if _dissolve_delay < 0.0 or _sprite == null:
		return
	_dissolve_t += delta
	var m := _sprite.material as ShaderMaterial
	if _dissolve_t < _dissolve_delay:
		return   # (her body, clear, until she fizzles)
	var t := _dissolve_t - _dissolve_delay
	_push *= exp(-3.0 * delta)
	position += _push * delta
	rotation = lerpf(rotation, DEATH_TILT * scale.y, 1.0 - exp(-4.0 * delta))
	var amount := clampf(t / _dissolve_time, 0.0, 1.0)
	m.set_shader_parameter("amount", amount)
	if amount >= 1.0:
		visible = false
		_dissolve_delay = -1.0


## (A finisher's last strike) she falls: and fizzles out.
func fall() -> void:
	super.fall()
	var main := get_tree().current_scene
	dissolve_out(0.2, 0.6, main.get("fx") if main else null)


## A remnant bursts: shards of her colours every way.
static func explode(fx: Fx, at: Vector2, size: float) -> void:
	if fx == null:
		return
	fx.shards(at, SHARD_COLOURS, int(70 * size), 180.0 * size, 650.0 * size)

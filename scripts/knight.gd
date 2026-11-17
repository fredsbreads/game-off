class_name Knight
extends Enemy
## The chase enemy (debuts in level 5, Patterns.KNIGHT_DEBUT_LEVEL): a knight, a woman, who takes several
## hits. Each hit she blinks to one of the player's three landing spots,
## chosen when her chain was generated (so the chain is provably catchable),
## and you chase her down.
##
## You can teleport past her, but not run past her across the rows: while
## the player is straight across from her (under the player's across marker)
## she winds up (sound, sword raised), and if the player runs on out of
## reach, or a freeze ends (dropped) there, she teleports to the player and
## cuts the player down. Same if a freeze ends with her hit but not finished and
## within a teleport of the player.
## main.gd checks this every frame; ChunkSolver mirrors the running part.
## Art: "Hero Knight" (CC0), assets/sprites/hero_knight.

const K_IDLE := preload("res://assets/sprites/hero_knight/idle.png")
const K_DEATH := preload("res://assets/sprites/hero_knight/death.png")
const K_ATTACK := preload("res://assets/sprites/hero_knight/attack.png")   # "Attack1": her clash swings
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
# On the frames with the biggest arcs the art paints the arc over her head
# and body, so with the arc moved behind her, her body is taken from the next
# frame, where it's whole: frame -> frame to draw her body from.
const KILL_BODY_FROM := {3: 4}
# Her clash swing: either attack, at random. Per attack: the sheet, the
# frames from the swing on, the frame held through the clash beat, and
# frame -> frame her body is drawn from (see KILL_BODY_FROM).
const CLASH_SWINGS := [
	{"sheet": K_ATTACK, "frames": [2, 3, 4, 5, 6], "hold": 3, "body_from": {3: 5, 4: 5}},
	{"sheet": K_ATTACK2, "frames": [2, 3, 4, 5, 6], "hold": 3, "body_from": {3: 4}},
]
# Which of the knight's swings answers each of the player's three strike
# poses, and how far (tiles) past the knight's real spot it's drawn so the two
# read as a clash: player 1 vs knight 1, player 2 vs knight 2 (the knight's
# lunge, so further back), player 3 vs knight 1.
const CLASH_BY_POSE := [
	{"swing": 0, "gap": 1.3 + 1.0 / 3.0},
	{"swing": 1, "gap": 2.6 + 0.75},
	{"swing": 0, "gap": 1.3 + 1.0 / 3.0},
]
const KILL_DISTANCE := 2.6          # tiles ahead of the player the knight swings her killing blow from
const AFTERIMAGE_FADE := 0.35       # seconds her clash swing lingers after she blinks away
const CLASH_TIME := 0.25           # seconds her clash swing (left where she was) plays
const SLASH_OUTLINE := Color(0.35, 1.0, 0.45, 1.0)   # green outline while she swings
# Her swings' arcs (the clash and the killing blow): outlined this thick in her
# colour (art pixels, up to 3; her body keeps 1) and the white tinted toward
# it just a little (SLASH_ARC_TINT).
const SLASH_OUTLINE_PX := 2
# Where she'll blink to next: a faint silhouette in her colour at that spot.
const NEXT_SHADER := preload("res://shaders/silhouette.gdshader")
const NEXT_ALPHA := 0.28
const SHOW_NEXT := false   # off for now: it read as a target in the heat of a chain
# Instead, in the freeze after a clash: a thin flickering thread of lightning
# in her colour from her to her next spot (main.gd sets `thread`).
const THREAD_WIDTH := 3.0
const THREAD_JAG := 9.0           # pixels it wavers from the straight line (most in the middle)
const THREAD_POINTS := 28
const THREAD_FADE_IN := 0.12      # seconds
const THREAD_PULSE_SPEED := 1.8   # pulses along it per second
const THREAD_TRAIL_ALPHA := 0.5   # the line of the jump she just made: this much dimmer
const SLASH_ARC_TINT := 0.12

## Her look, as data, so another teleporter (the ninja) can use all of her
## behaviour with his own art: the sheets, frame size, where the feet are, the
## drawn scale, and which frames do what.
const KNIGHT_ART := {
	"frame": K_FRAME, "feet": K_FEET, "scale": K_SCALE,
	"anims": [["idle", K_IDLE, K_IDLE_FPS, true], ["death", K_DEATH, K_DEATH_FPS, false],
		["attack", K_ATTACK, K_ATTACK_FPS, false], ["kill", K_ATTACK2, K_ATTACK_FPS, false],
		["hit", K_TAKE_HIT, K_HIT_FPS, false, K_HIT_FRAMES]],
	"kill_frame": KILL_SLASH_FRAME, "kill_body_from": KILL_BODY_FROM,
	"swings": CLASH_SWINGS, "by_pose": CLASH_BY_POSE,
	"windup_anim": "attack", "windup_frame": WINDUP_FRAME,
	"engaged_anim": "attack", "engaged_frame": WINDUP_FRAME,   # her pose waiting at her next spot after a clash
	"attack_start": K_ATTACK_START,
	"lightning": "green", "outline": SLASH_OUTLINE,
}
## The art in use (see KNIGHT_ART; the ninja sets his own before _ready).
var art: Dictionary = KNIGHT_ART

## Every spot she'll be in, in order: Vector2(tile x, row). path[0] is where
## she starts; each hit moves her to the next one.
var path: Array[Vector2] = []
var step_index := 0
## True once she's been hit (and not yet killed): she's in a duel with the player.
var engaged := false
## Her debut (the lone knight that opens level 5): the power-up never plays
## through her, the player always meets her by hand.
var debut := false
## True while the player is straight across from her: she's winding up to strike.
var threat := false
var warned := false   # she's already given her wind-up swish once
## The ninja's extra: he also watches straight ahead (see ninja.gd). main.gd
## keeps the rest: `ahead` while she could teleport to him (under her forward
## marker), and `alerted` once he's given his alert (coming back under it
## after that brings him at once).
var forward_aggro := false
var diag_aggro := false   # the master: diagonally too (see master.gd)
var ahead := false
var alerted := false
var _slashing := false   # the killing blow: green outline held
var _next: Sprite2D = null   # her next spot's silhouette (see _update_next)
## True while the thread to her next spot shows (main.gd: the freeze after a clash).
var thread := false
var _thread: Node2D = null
var _thread_points := PackedVector2Array()
var _trail_points := PackedVector2Array()   # the jump she just made (from her last spot)
## The trail of her last jump shows only until the player teleports elsewhere
## (set by blink(); main.gd clears it on any other teleport).
var show_trail := false
## (Testing) which clash swing to use; -1 = the usual choice.
var force_swing := -1
var _thread_time := 0.0
var _thread_fade := 0.0
var _thread_seed := randf() * TAU
var _arc: AnimatedSprite2D
## Where her body goes in a clash swing: a layer above the player (set by main.gd).
static var front_parent: Node = null


func _part_material(part: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("white_part", part)
	return m
const WINDUP_FRAME := 1             # sword raised, from her attack animation


## (The ninja, the master) she could teleport to him by a move he watches:
## forward, and the master's diagonal too.
func watching(her_x: float, her_row: int) -> bool:
	return (forward_aggro and Rules.ninja_ahead(tile_x, row, her_x, her_row)) \
			or (diag_aggro and Rules.master_diag_ahead(tile_x, row, her_x, her_row))


## (The ninja, the master) she's in front of him but too close to reach him by
## a move he watches: he strikes.
func too_close(her_x: float, her_row: int) -> bool:
	return (forward_aggro and Rules.ninja_too_close(tile_x, row, her_x, her_row)) \
			or (diag_aggro and Rules.master_diag_too_close(tile_x, row, her_x, her_row))


## Her lightning's colour (Fx: "green"; the ninja's "cyan").
func lightning() -> String:
	return art["lightning"]


func hits_left() -> int:
	return path.size() - step_index


func _ready() -> void:
	if not path.is_empty():
		tile_x = path[0].x
		row = int(path[0].y)
	_place()
	# Her slash arcs (the white in her attack frames) go behind her: a copy
	# of her drawing only them, underneath.
	_arc = AnimatedSprite2D.new()
	var frame: Vector2i = art["frame"]
	var feet: Vector2 = art["feet"]
	var sc: float = art["scale"]
	_arc.sprite_frames = _build_knight_frames()
	_arc.centered = false
	_arc.offset = Vector2(-(frame.x - feet.x), -feet.y)
	_arc.scale = Vector2(sc, sc)
	_arc.flip_h = true
	_arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arc.material = _part_material(2)
	add_child(_arc)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _arc.sprite_frames
	_sprite.centered = false
	_sprite.offset = Vector2(-(frame.x - feet.x), -feet.y)
	_sprite.scale = Vector2(sc, sc)
	_sprite.flip_h = true   # the art faces right; she faces the player (left)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = _part_material(1)
	_sprite.material = _material
	add_child(_sprite)
	_sprite.play("idle")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("idle")
	_sprite.animation_finished.connect(_on_animation_finished)
	_thread = Node2D.new()
	_thread.top_level = true
	_thread.z_index = 1
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_thread.material = glow
	_thread.draw.connect(_draw_thread)
	add_child(_thread)
	# Her next spot: a flat silhouette (her stance), drawn where she'll blink to.
	if not SHOW_NEXT:
		return
	_next = Sprite2D.new()
	_next.texture = _sprite.sprite_frames.get_frame_texture(art["windup_anim"], art["windup_frame"])
	_next.centered = false
	_next.offset = _sprite.offset
	_next.flip_h = true
	_next.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = NEXT_SHADER
	_next.material = m
	_next.top_level = true
	var c: Color = art["outline"]
	_next.modulate = Color(c.r, c.g, c.b, NEXT_ALPHA)
	add_child(_next)
	_update_next()


func _place() -> void:
	position = Vector2(tile_x * Rules.TILE, Rules.surface_y(row))
	scale.y = -1.0 if row == Rules.Row.CEILING else 1.0


func _build_knight_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var size: Vector2i = art["frame"]
	for spec in art["anims"]:
		var sheet: Texture2D = spec[1]
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		frames.set_animation_loop(spec[0], spec[3])
		var count: int = spec[4] if spec.size() > 4 else sheet.get_width() / size.x
		var first: int = spec[5] if spec.size() > 5 else 0
		for i in range(first, first + count):
			var tex := AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(Vector2(i * size.x, 0), Vector2(size))
			frames.add_frame(spec[0], tex)
	return frames


## Struck (the streak finisher): her take-hit, ending on the recoil, held
## until the next strike.
func take_hit() -> void:
	if _sprite:
		_sprite.speed_scale = 1.0
		_sprite.play("hit")
		_sprite.frame = 0


## The finisher's over: now she falls.
func fall() -> void:
	if _sprite:
		_sprite.speed_scale = 1.0
		_sprite.play("death")


## Hit but not finished: leaves a white flash where she was and blinks to her
## next spot. Returns the spot she left (pixels, body centre).
## `beat`: seconds her swing holds where she was before she reappears.
## `her_pose`: the strike pose the player hit her with (picks her swing).
## `reappear`: seconds until she shows at her new spot (< beat, so the player
## can see where she went while the clash still plays out where she was).
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
	show_trail = true
	step_index += 1
	tile_x = path[step_index].x
	row = int(path[step_index].y)
	_place()
	threat = false
	if _sprite:
		# Engaged now: she waits at her new spot in her duel pose, not idle.
		_sprite.play(art["engaged_anim"])
		_sprite.frame = art["engaged_frame"]
		_sprite.pause()
	return from


## Her clash swing, left where she was as she blinks away: "Attack1" from the
## swing on, with a green outline, then fading.
func _leave_ghost(beat := 0.0, her_pose := 0) -> void:
	if get_parent() == null or _sprite == null:
		return
	var by_pose: Array = art["by_pose"]
	var answer: Dictionary = by_pose[clampi(her_pose, 0, by_pose.size() - 1)]
	if art.has("pose_swings"):
		# (The master) her pose decides which swings can answer, each with its own gap.
		var options: Array = art["pose_swings"][clampi(her_pose, 0, art["pose_swings"].size() - 1)]
		answer = options[randi() % options.size()]
		if force_swing >= 0:
			for entry in options:
				if int(entry["swing"]) == force_swing:
					answer = entry
	elif force_swing >= 0:
		for entry in by_pose:
			if int(entry["swing"]) == force_swing:
				answer = entry
				break
	elif art.get("swing_mix", false):
		# Either swing, half and half: the first pose that answers with it.
		var want: int = randi() % (art["swings"] as Array).size()
		for entry in by_pose:
			if int(entry["swing"]) == want:
				answer = entry
				break
	var swing: Dictionary = art["swings"][answer["swing"]]
	var size: Vector2i = art["frame"]
	var sc: float = art["scale"]
	var frames: Array = swing["frames"]
	var body_from: Dictionary = swing["body_from"]
	var arc_tex := AtlasTexture.new()
	arc_tex.atlas = swing["sheet"]
	var body_tex := AtlasTexture.new()
	body_tex.atlas = swing["sheet"]
	# Her arc goes behind everything; her body in front of the player and the player's slash
	# (front_parent), so the clash reads.
	var parts: Array[Node2D] = []
	for part in [2, 1]:
		var holder := Node2D.new()
		# Further from the player than her real spot (by the swing's "gap", tiles),
		# so the clash reads as two swords meeting rather than one figure.
		holder.position = position + Vector2(float(answer["gap"]) * Rules.TILE, 0)
		holder.scale = Vector2(sc, sc * scale.y)
		var s := Sprite2D.new()
		s.texture = arc_tex if part == 2 else body_tex
		s.centered = false
		s.offset = _sprite.offset
		s.flip_h = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := _part_material(part)
		mat.set_shader_parameter("outline_color", art["outline"])
		mat.set_shader_parameter("glint", 1.0)
		if part == 2:   # (her body keeps the thin outline)
			mat.set_shader_parameter("outline_px", SLASH_OUTLINE_PX)
			mat.set_shader_parameter("arc_tint", SLASH_ARC_TINT)
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
		arc_tex.region = Rect2(Vector2(frame * size.x, 0), Vector2(size))
		var body: int = body_from.get(frame, frame)
		body_tex.region = Rect2(Vector2(body * size.x, 0), Vector2(size))
	show.call(0.0)
	tween.tween_method(show, 0.0, float(held), CLASH_TIME * 0.4)
	tween.tween_interval(maxf(beat - CLASH_TIME * 0.4, 0.0))
	# She's gone: what's left is an afterimage of the clash, fading.
	tween.tween_method(func(a: float) -> void:
		for p in parts:
			if is_instance_valid(p):
				p.modulate.a = a, 0.8, 0.0, AFTERIMAGE_FADE)
	tween.tween_callback(func() -> void:
		for p in parts:
			if is_instance_valid(p):
				p.queue_free())


## The player is straight across from her: she raises her sword and holds it.
func warn() -> void:
	threat = true
	if alive:
		_hold_windup()


## Her wind-up pose, held (the art's: the knight's sword raised).
func _hold_windup() -> void:
	if _sprite:
		_sprite.play(art["windup_anim"])
		_sprite.frame = art["windup_frame"]
		_sprite.pause()


## The player's dead: out of her stance, back to idle (not mid-blow).
func relax() -> void:
	if alive and not _slashing and _sprite:
		threat = false
		_sprite.play("idle")


## The player is no longer across from her.
func calm() -> void:
	threat = false
	if alive and _sprite and _sprite.animation == art["windup_anim"]:
		_sprite.play("idle")


## She teleports to the player (just ahead, in the player's row) and cuts
## the player down. Returns the spot she left (pixels, body centre).
## `side`: 1 = she lands in front of the player (facing back), -1 = behind
## her (facing forward), when two strike at once.
func pounce(her_x: float, her_row: int, side := 1.0) -> Vector2:
	var from := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	row = her_row
	slash(her_x, side)
	return from


## The killing blow (the player ran into her, or she teleported to the player): "Attack2" on
## its big arc (that's what the death freeze holds), outlined green.
func slash(her_x: float, side := 1.0) -> void:
	threat = false
	# Far enough off that her arc lands on the player rather than her standing inside the player.
	tile_x = her_x + float(art.get("kill_distance", KILL_DISTANCE)) * side
	scale.x = side   # behind her: turned round to face her
	_place()
	if _sprite:
		_sprite.play("kill")
		var kill_frame: int = art["kill_frame"]
		_sprite.frame = art["kill_body_from"].get(kill_frame, kill_frame)
		_sprite.pause()
		for m in [_material, _arc.material]:
			m.set_shader_parameter("outline_color", art["outline"])
			m.set_shader_parameter("glint", 1.0)
		# Only the arc gets the thicker outline and the tint (her body keeps the thin one).
		_arc.material.set_shader_parameter("outline_px", SLASH_OUTLINE_PX)
		_arc.material.set_shader_parameter("arc_tint", SLASH_ARC_TINT)
		# Her body over the player (and the player's effects) for the killing blow; the arc
		# stays behind.
		if front_parent and _sprite.get_parent() == self:
			var holder := Node2D.new()
			front_parent.add_child(holder)
			holder.global_position = global_position
			holder.scale = scale
			_sprite.reparent(holder, false)
			tree_exiting.connect(holder.queue_free)
	_slashing = true


## Puts her next spot's silhouette where she'll blink to next (hidden when
## there's none, or she's dead or striking).
func _update_next() -> void:
	if _next == null:
		return
	var has_next := alive and not _slashing and step_index + 1 < path.size()
	_next.visible = has_next
	if not has_next:
		return
	var spot: Vector2 = path[step_index + 1]
	var sc: float = art["scale"]
	_next.global_position = Vector2(spot.x * Rules.TILE, Rules.surface_y(int(spot.y)))
	_next.global_scale = Vector2(sc, sc * (-1.0 if int(spot.y) == Rules.Row.CEILING else 1.0))


## The thread to her next spot: a wavering line of energy in her colour,
## fading in, with a pulse running along it toward where she'll blink.
func _update_thread(delta: float) -> void:
	if _thread == null:
		return
	var has_next := step_index + 1 < path.size()
	var has_prev := step_index > 0 and show_trail
	var show := thread and alive and not _slashing and (has_next or has_prev)
	if not show:
		_thread.visible = false
		_thread_fade = 0.0
		return
	_thread.visible = true
	_thread_fade = minf(_thread_fade + delta / THREAD_FADE_IN, 1.0)
	_thread_time += delta
	var here := Vector2(tile_x * Rules.TILE, Rules.body_center_y(row))
	_thread_points = PackedVector2Array()
	if has_next:
		var spot: Vector2 = path[step_index + 1]
		_thread_points = _waver(here, Vector2(spot.x * Rules.TILE, Rules.body_center_y(int(spot.y))), _thread_seed)
	# The jump she just made, lingering (dimmer, no pulse).
	_trail_points = PackedVector2Array()
	if has_prev:
		var was: Vector2 = path[step_index - 1]
		_trail_points = _waver(Vector2(was.x * Rules.TILE, Rules.body_center_y(int(was.y))), here, _thread_seed + 2.0)
	_thread.queue_redraw()


## A wavering line from a to b (two slow waves, pinned at both ends).
func _waver(a: Vector2, b: Vector2, seed: float) -> PackedVector2Array:
	var normal := (b - a).orthogonal().normalized()
	var n := THREAD_POINTS
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var w := sin(t * 17.0 + _thread_time * 11.0 + seed) * 0.6 + sin(t * 41.0 - _thread_time * 19.0) * 0.4
		pts.append(a.lerp(b, t) + normal * w * THREAD_JAG * sin(t * PI))
	return pts


func _draw_thread() -> void:
	var c: Color = art["outline"]
	var f := _thread_fade
	if _trail_points.size() >= 2:
		var tf := f * THREAD_TRAIL_ALPHA
		_thread.draw_polyline(_trail_points, Color(c.r, c.g, c.b, 0.10 * tf), THREAD_WIDTH * 3.0, true)
		_thread.draw_polyline(_trail_points, Color(c.r, c.g, c.b, 0.8 * tf), THREAD_WIDTH * 0.8, true)
		_thread.draw_polyline(_trail_points, Color(1, 1, 1, 0.5 * tf), 1.0, true)
	if _thread_points.size() < 2:
		return
	# Glow, then the colour, then a white-hot core.
	_thread.draw_polyline(_thread_points, Color(c.r, c.g, c.b, 0.10 * f), THREAD_WIDTH * 4.0, true)
	_thread.draw_polyline(_thread_points, Color(c.r, c.g, c.b, 0.22 * f), THREAD_WIDTH * 2.2, true)
	_thread.draw_polyline(_thread_points, Color(c.r, c.g, c.b, 0.85 * f), THREAD_WIDTH, true)
	_thread.draw_polyline(_thread_points, Color(1, 1, 1, 0.75 * f), maxf(THREAD_WIDTH * 0.35, 1.0), true)
	# A pulse running toward her next spot (shows which way she'll go).
	var u := fmod(_thread_time * THREAD_PULSE_SPEED, 1.0)
	var k := u * float(_thread_points.size() - 1)
	var i := mini(int(k), _thread_points.size() - 2)
	var p := _thread_points[i].lerp(_thread_points[i + 1], k - float(i))
	var pa := sin(u * PI) * f
	_thread.draw_circle(p, THREAD_WIDTH * 3.0, Color(c.r, c.g, c.b, 0.25 * pa))
	_thread.draw_circle(p, THREAD_WIDTH * 1.1, Color(1, 1, 1, 0.9 * pa))
	# A soft glow where it lands.
	var end := _thread_points[_thread_points.size() - 1]
	var beat := 0.75 + 0.25 * sin(_thread_time * 9.0)
	_thread.draw_circle(end, THREAD_WIDTH * 3.5, Color(c.r, c.g, c.b, 0.18 * f * beat))
	_thread.draw_circle(end, THREAD_WIDTH * 1.4, Color(c.r, c.g, c.b, 0.6 * f * beat))


func _process(delta: float) -> void:
	_update_next()
	_update_thread(delta)
	if _arc and _sprite:
		if _arc.animation != _sprite.animation:
			_arc.play(_sprite.animation)
		_arc.frame = art["kill_frame"] if _slashing else _sprite.frame
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


## After the killing blow's freeze (the world starts moving again): she
## follows through with the rest of the swing, then goes back to idle.
func set_anim_speed(value: float) -> void:
	super(value)
	if _slashing and value > 0.0 and _sprite:
		_slashing = false   # the green outline fades (Enemy._process)
		targeted = false
		_glint = 1.0
		_sprite.play("kill")


func _on_animation_finished() -> void:
	if _sprite.animation == "kill" or _sprite.animation == "attack" or _sprite.animation == art["windup_anim"]:
		_sprite.play("idle")
	else:
		super()


func attack(_her_x := NAN) -> void:
	if alive and _sprite:
		_sprite.play("attack")
		_sprite.frame = art["attack_start"]

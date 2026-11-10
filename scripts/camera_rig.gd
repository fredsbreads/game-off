class_name CameraRig
extends Camera2D
## Keeps the player at a home spot near the left of the screen. After a
## teleport the player visibly jumps right, then the camera catches up
## quickly so long jumps don't leave you with less view ahead.
##
## Fairness: every screen sees exactly VIEW_TILES tiles across. The camera
## zooms to fit that width, so wider phones crop a little sky instead of
## seeing further ahead. The two rows always sit centred on screen.

const HOME_TILES := 2.0         # player's home spot, in tiles from the left edge
const CATCH_UP_RATE := 14.0     # higher = faster catch-up (14 ~= 0.2 s)
const VIEW_TILES := 16.0        # tiles visible across, on every device
# Kill zoom punch: in quickly, then back out well before the pause ends,
# so the full view is back while you decide.
const PUNCH_ZOOM := 0.06        # 6 % closer at the peak
const PUNCH_IN := 0.05
const PUNCH_OUT := 0.13

var _left := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _punch_time := -1.0         # < 0 = no punch running
var _punch_focus := Vector2.ZERO


func left() -> float:
	return _left


## Size of the visible area in world pixels (always VIEW_TILES wide).
func visible_world_size() -> Vector2:
	var screen := get_viewport_rect().size
	var world_w := VIEW_TILES * Rules.TILE
	return Vector2(world_w, world_w * screen.y / screen.x)


## Both rows are centred vertically, so every screen shows them the same.
func top() -> float:
	var middle := (Rules.GROUND_Y + Rules.CEILING_Y) / 2.0
	return middle - visible_world_size().y / 2.0


func snap(player_x: float) -> void:
	_left = _target(player_x)
	_apply()


## run_px_per_s moves the camera with the run, so steady running has no lag;
## the exponential catch-up only handles teleports.
func follow(player_x: float, run_px_per_s: float, delta: float) -> void:
	_left += run_px_per_s * delta
	_left += (_target(player_x) - _left) * (1.0 - exp(-CATCH_UP_RATE * delta))
	if _shake_time > 0.0:
		_shake_time -= delta
	if _punch_time >= 0.0:
		_punch_time += delta
		if _punch_time > PUNCH_IN + PUNCH_OUT:
			_punch_time = -1.0
	_apply()


func punch(focus_world: Vector2) -> void:
	_punch_focus = focus_world
	_punch_time = 0.0


func shake(duration: float, strength: float) -> void:
	_shake_time = maxf(_shake_time, duration)
	_shake_strength = maxf(_shake_strength, strength)


func _punch_amount() -> float:
	if _punch_time < 0.0:
		return 0.0
	if _punch_time < PUNCH_IN:
		return PUNCH_ZOOM * ease(_punch_time / PUNCH_IN, 0.5)
	return PUNCH_ZOOM * (1.0 - ease((_punch_time - PUNCH_IN) / PUNCH_OUT, 2.0))


func _target(player_x: float) -> float:
	return (player_x - HOME_TILES) * Rules.TILE


func _apply() -> void:
	var z := get_viewport_rect().size.x / (VIEW_TILES * Rules.TILE)
	var top_left := Vector2(_left, top())
	var p := _punch_amount()
	if p > 0.0:
		# Zoom in around the kill point: it stays put on screen.
		top_left = _punch_focus - (_punch_focus - top_left) / (1.0 + p)
		z *= 1.0 + p
	zoom = Vector2(z, z)
	position = top_left
	if _shake_time > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		offset = Vector2.ZERO
		_shake_strength = 0.0

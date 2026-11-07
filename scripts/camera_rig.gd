class_name CameraRig
extends Camera2D
## Keeps the player at a home spot near the left of the screen. After a
## teleport the player visibly jumps right, then the camera catches up
## quickly so long jumps don't leave you with less view ahead.
##
## Fairness: every screen sees exactly VIEW_TILES tiles across. The camera
## zooms to fit that width, so wider phones crop a little sky instead of
## seeing further ahead. The ground always sits at the same height on screen.

const HOME_TILES := 2.0         # player's home spot, in tiles from the left edge
const CATCH_UP_RATE := 14.0     # higher = faster catch-up (14 ~= 0.2 s)
const VIEW_TILES := 16.0        # tiles visible across, on every device
const GROUND_SCREEN_FRACTION := 448.0 / 576.0   # ground line, from the top of the screen

var _left := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0


func left() -> float:
	return _left


## Size of the visible area in world pixels (always VIEW_TILES wide).
func visible_world_size() -> Vector2:
	var screen := get_viewport_rect().size
	var world_w := VIEW_TILES * Rules.TILE
	return Vector2(world_w, world_w * screen.y / screen.x)


func top() -> float:
	return Rules.GROUND_Y - visible_world_size().y * GROUND_SCREEN_FRACTION


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
	_apply()


func shake(duration: float, strength: float) -> void:
	_shake_time = maxf(_shake_time, duration)
	_shake_strength = maxf(_shake_strength, strength)


func _target(player_x: float) -> float:
	return (player_x - HOME_TILES) * Rules.TILE


func _apply() -> void:
	var z := get_viewport_rect().size.x / (VIEW_TILES * Rules.TILE)
	zoom = Vector2(z, z)
	position = Vector2(_left, top())
	if _shake_time > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		offset = Vector2.ZERO
		_shake_strength = 0.0

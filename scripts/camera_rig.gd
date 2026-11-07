class_name CameraRig
extends Camera2D
## Keeps the player at a home spot near the left of the screen. After a
## teleport the player visibly jumps right, then the camera catches up
## quickly so long jumps don't leave you with less view ahead.

const HOME_TILES := 2.0         # player's home spot, in tiles from the left edge
const CATCH_UP_RATE := 14.0     # higher = faster catch-up (14 ~= 0.2 s)

var _left := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0


func left() -> float:
	return _left


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
	position = Vector2(_left, 0)
	if _shake_time > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		offset = Vector2.ZERO
		_shake_strength = 0.0

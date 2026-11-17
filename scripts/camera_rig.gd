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
var _punch_zoom := PUNCH_ZOOM
var _punch_out := PUNCH_OUT
var _punch_focus := Vector2.ZERO
# A held zoom (the death moment): eases toward _hold_target around _hold_focus.
var _hold := 0.0
var _hold_target := 0.0
var _hold_focus := Vector2.ZERO
var _hold_rate := 12.0
var _hold_frac := 0.5       # screen x (0-1) to pan the focus to
var _pan := 0.0             # 0 = no pan, 1 = focus at _hold_frac (eased)
var _pan_target := 0.0


func left() -> float:
	return _left


## What's on screen right now, in world pixels: wider than
## visible_world_size() while zoomed out (the death camera).
func shown_world_size() -> Vector2:
	return visible_world_size() / (1.0 + minf(_hold, 0.0))


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
	_hold += (_hold_target - _hold) * (1.0 - exp(-_hold_rate * delta))
	_pan += (_pan_target - _pan) * (1.0 - exp(-_hold_rate * delta))
	if _punch_time >= 0.0:
		_punch_time += delta
		if _punch_time > PUNCH_IN + _punch_out:
			_punch_time = -1.0
	_apply()


## `amount`: how much closer at the peak; `out`: seconds to ease back out.
func punch(focus_world: Vector2, amount := PUNCH_ZOOM, out := PUNCH_OUT) -> void:
	_punch_focus = focus_world
	_punch_time = 0.0
	_punch_zoom = amount * Settings.shake   # (the Camera Shake & Zoom option)
	_punch_out = out


## Zoom by `amount` around a world point and hold it (0.45 = 45 % closer,
## -0.15 = 15 % further out, 0 = normal). `rate`: how fast it eases there.
## `screen_frac`: also pan so the focus sits this far across the screen
## (0.5 = middle); < 0 = no pan.
func hold_zoom(focus_world: Vector2, amount: float, rate: float = 12.0, screen_frac: float = -1.0) -> void:
	_hold_focus = focus_world
	# The Camera Shake & Zoom option scales zooming in; zooming out (the death camera
	# pulling back to show what happened) is kept as it is.
	_hold_target = amount * Settings.shake if amount > 0.0 else amount
	_hold_rate = rate
	_pan_target = 1.0 if screen_frac >= 0.0 else 0.0
	if screen_frac >= 0.0:
		_hold_frac = screen_frac


## Every screen shake in the game is scaled by this (1 = as tuned; lower is
## gentler on the eyes over a long run).
const SHAKE_SCALE := 0.5


func shake(duration: float, strength: float) -> void:
	_shake_time = maxf(_shake_time, duration)
	_shake_strength = maxf(_shake_strength, strength * SHAKE_SCALE * Settings.shake)   # (the Camera Shake & Zoom option)


func _punch_amount() -> float:
	if _punch_time < 0.0:
		return 0.0
	if _punch_time < PUNCH_IN:
		return _punch_zoom * ease(_punch_time / PUNCH_IN, 0.5)
	return _punch_zoom * (1.0 - ease(minf((_punch_time - PUNCH_IN) / _punch_out, 1.0), 2.0))


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
	if absf(_hold) > 0.001 or _pan > 0.001:
		var zoomed := _hold_focus - (_hold_focus - top_left) / (1.0 + _hold)
		var view_w := VIEW_TILES * Rules.TILE / (1.0 + _hold)
		var panned_x := _hold_focus.x - _hold_frac * view_w
		zoomed.x = lerpf(zoomed.x, panned_x, clampf(_pan, 0.0, 1.0))
		top_left = zoomed
		z *= 1.0 + _hold
	zoom = Vector2(z, z)
	position = top_left
	if _shake_time > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		offset = Vector2.ZERO
		_shake_strength = 0.0

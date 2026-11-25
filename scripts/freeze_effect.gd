class_name FreezeEffect
extends CanvasLayer
## Full-screen invert / grey effect used during the kill pause.
## Sits above the world but below the enemy and player layers, so enemies,
## the player and the lit landing markers stay in full colour.

const SHADER := preload("res://shaders/freeze.gdshader")
## How dark the grey goes: the forest background's sepia needs it darker to
## read as stopped time.
const SIMPLE_DARKEN := 0.75
const FOREST_DARKEN := 0.62

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


## Shown at a strength nobody can see for a moment (see main.gd _prewarm),
## so the browser compiles it before the first kill pause needs it.
var _warm_until := 0


func prewarm(seconds: float) -> void:
	_warm_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func set_state(invert: float, grey: float) -> void:
	if Time.get_ticks_msec() < _warm_until and invert <= 0.0 and grey <= 0.0:
		grey = 0.002
	_rect.visible = invert > 0.0 or grey > 0.0
	_material.set_shader_parameter("grey_darken", FOREST_DARKEN if Settings.forest() else SIMPLE_DARKEN)
	_material.set_shader_parameter("invert", invert)
	_material.set_shader_parameter("grey", grey)

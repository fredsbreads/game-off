class_name FreezeEffect
extends CanvasLayer
## Full-screen invert / grey effect used during the kill pause.
## Sits above the world but below the enemy and player layers, so enemies,
## the player and the lit landing markers stay in full colour.

const SHADER := preload("res://shaders/freeze.gdshader")

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


func set_state(invert: float, grey: float) -> void:
	_rect.visible = invert > 0.0 or grey > 0.0
	_material.set_shader_parameter("invert", invert)
	_material.set_shader_parameter("grey", grey)

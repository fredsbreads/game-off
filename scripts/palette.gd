class_name Palette
extends RefCounted
## Her colour: red until level 10, then pink. Shaders read it through the
## `accent_pink` global (shaders/accent.gdshaderinc); colours set in code go
## through tint(). Only reds move (whites, greys, the knight's green don't),
## and blood is drawn without it, so it stays red.

const PINK_FROM_LEVEL := 10
const PINK_HUE := 0.925
const PINK_SAT := 0.7
const SHADER := preload("res://shaders/accent_sprite.gdshader")

## 0 = red, 1 = pink (in between while it changes over).
static var pink := 0.0
## One material for every plain sprite in her colour.
static var material: ShaderMaterial = null


static func sprite_material() -> ShaderMaterial:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SHADER
	return material


static func set_pink(value: float) -> void:
	pink = clampf(value, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("accent_pink", pink)


static func for_level(level: int) -> float:
	return 1.0 if level >= PINK_FROM_LEVEL else 0.0


## The same as accent() in the shader, for colours set in code.
static func tint(c: Color) -> Color:
	if pink <= 0.0:
		return c
	var from_red := minf(c.h, 1.0 - c.h)
	var w := (1.0 - smoothstep(0.05, 0.11, from_red)) * smoothstep(0.12, 0.3, c.s)
	var p := Color.from_hsv(PINK_HUE, c.s * PINK_SAT, minf(1.0, c.v * 1.05 + 0.04), c.a)
	return c.lerp(p, w * pink)

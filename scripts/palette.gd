class_name Palette
extends RefCounted
## Her colour: red until level 10, then COLOUR (below). Shaders read it
## through globals (shaders/accent.gdshaderinc); colours set in code go
## through tint(). Only reds move (whites, greys, the knight's green don't),
## and blood is drawn without it, so it stays red.

## >>> Her colour from level 10. Change this to any name in COLOURS. <<<
const COLOUR := "ember"

## While playing, the C key cycles through every colour here (and shows its
## name), so they can be compared in the game. Off = false.
const CYCLE_KEY := true

## [hue 0..1, saturation x, brightness x] (the last two multiply her red's).
## The names match the mock-up sheets.
const COLOURS := {
	"ember": [0.045, 1.0, 1.0],          # red-orange (red sheet D)
	"crimson": [0.965, 1.0, 0.85],       # red sheet A
	"blood": [0.995, 1.0, 0.62],         # red sheet B
	"scarlet": [0.015, 1.0, 1.0],        # red sheet C
	"burgundy": [0.95, 0.85, 0.55],      # red sheet E
	"white_hot": [0.0, 0.55, 1.15],      # red sheet F
	"black_red": [0.99, 1.0, 0.38],      # red sheet G
	"pink": [0.925, 0.7, 1.09],          # pink sheet A (the first pink)
	"hot_pink": [0.917, 0.9, 1.0],       # pink sheet B
	"rose": [0.944, 0.85, 0.85],         # pink sheet C
	"magenta": [0.883, 0.9, 0.95],       # pink sheet D
	"raspberry": [0.93, 1.0, 0.8],       # pink sheet E
	"gold": [0.11, 1.0, 1.0],            # colour sheet 1
	"yellow": [0.15, 0.9, 1.1],          # colour sheet 2
	"silver": [0.0, 0.08, 1.15],         # colour sheet 3
	"ice": [0.52, 0.85, 1.05],           # colour sheet 4
	"electric_blue": [0.6, 0.95, 1.05],  # colour sheet 5
	"deep_blue": [0.64, 1.0, 0.8],       # colour sheet 6
	"violet": [0.75, 0.85, 1.0],         # colour sheet 7
	"royal_purple": [0.79, 1.0, 0.75],   # colour sheet 8
	"teal": [0.48, 1.0, 0.75],           # colour sheet 9
	"void": [0.0, 0.0, 0.45],            # colour sheet 10
}

const PINK_FROM_LEVEL := 10
const SHADER := preload("res://shaders/accent_sprite.gdshader")

## 0 = red, 1 = her level-10 colour (in between while it changes over).
static var pink := 0.0
## The colour in use (COLOUR, or another one picked with the C key).
static var colour_name := COLOUR
static var _hsv: Array = COLOURS[COLOUR]
## One material for every plain sprite in her colour.
static var material: ShaderMaterial = null


static func sprite_material() -> ShaderMaterial:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SHADER
	return material


## Picks her level-10 colour by name (see COLOURS).
static func use_colour(name: String) -> void:
	if not COLOURS.has(name):
		push_warning("Palette: no colour called '%s', using ember" % name)
		name = "ember"
	colour_name = name
	_hsv = COLOURS[name]
	RenderingServer.global_shader_parameter_set("accent_hue", float(_hsv[0]))
	RenderingServer.global_shader_parameter_set("accent_sat", float(_hsv[1]))
	RenderingServer.global_shader_parameter_set("accent_val", float(_hsv[2]))


## The next colour in COLOURS (the C key). Returns its name.
static func next_colour() -> String:
	var names := COLOURS.keys()
	use_colour(names[(names.find(colour_name) + 1) % names.size()])
	return colour_name


## The screen flash when she changes over, in her new colour.
static func flash_colour() -> Color:
	return Color.from_hsv(float(_hsv[0]), minf(1.0, 0.8 * float(_hsv[1])), minf(1.0, 0.95 * float(_hsv[2])), 0.55)


static func set_pink(value: float) -> void:
	pink = clampf(value, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("accent_pink", pink)
	RenderingServer.global_shader_parameter_set("accent_wipe", -1.0)


## The change-over as a sweep: everything right of screen x `at` (0..1) is
## the new colour, left of it still red (shaders only; tint() stays red
## until it's done). Ends with set_pink(1.0).
static func sweep_to(at: float) -> void:
	RenderingServer.global_shader_parameter_set("accent_pink", 1.0)
	RenderingServer.global_shader_parameter_set("accent_wipe", at)


static func for_level(level: int) -> float:
	return 1.0 if level >= PINK_FROM_LEVEL else 0.0


## The same as accent() in the shader, for colours set in code.
static func tint(c: Color) -> Color:
	if pink <= 0.0:
		return c
	var from_red := minf(c.h, 1.0 - c.h)
	var w := (1.0 - smoothstep(0.05, 0.11, from_red)) * smoothstep(0.12, 0.3, c.s)
	var p := Color.from_hsv(float(_hsv[0]), minf(1.0, c.s * float(_hsv[1])), minf(1.0, c.v * float(_hsv[2])), c.a)
	return c.lerp(p, w * pink)

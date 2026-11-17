class_name Palette
extends RefCounted
## Her colour: red until level 10, then COLOUR (below). Shaders read it
## through globals (shaders/accent.gdshaderinc); colours set in code go
## through tint(). Only reds move (whites, greys, the knight's green don't),
## and blood follows it too (BLOOD_FOLLOWS_COLOUR).

## >>> Her reward colour (a flawless streak, see main.gd STREAK_REWARD).
## Change this to any name in COLOURS (the pause screen's Colour button
## picks one too). <<<
const COLOUR := "yellow"

## Blood takes her colour too (from level 10, like her effects). Off = it
## always stays red.
const BLOOD_FOLLOWS_COLOUR := true

## While playing, the C key cycles through every colour here (and shows its
## name), so they can be compared in the game. Off = false.
const CYCLE_KEY := true

## [hue 0..1, saturation x, brightness x] (the last two multiply her red's).
## Ember plus the ten from the colour-wheel sheet, in that order (the pause
## screen's Colour button and the C key step through them).
const COLOURS := {
	"ember": [0.045, 1.0, 1.0],
	"orange": [0.07, 1.0, 1.0],
	"yellow": [0.14, 0.95, 1.05],
	"lime": [0.22, 0.95, 0.95],
	"green": [0.33, 0.95, 0.85],
	"teal": [0.47, 1.0, 0.8],
	"cyan": [0.53, 0.9, 1.0],
	"blue": [0.61, 0.95, 1.0],
	"violet": [0.74, 0.85, 1.0],
	"magenta": [0.85, 0.9, 0.95],
	"pink": [0.93, 0.7, 1.09],
	# Her own red, unchanged (a hue below 0 means "keep it": see accent.gdshaderinc).
	"red": [-1.0, 1.0, 1.0],
}

## How a colour's name is shown (the Options screen, the C key).
static func display_name(name: String) -> String:
	return "Red (Original)" if name == "red" else name.capitalize()

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


## Her lit-marker red in the colour in use (for the pause screen's swatch).
static func swatch() -> Color:
	var red := Color(0.95, 0.15, 0.2)
	if float(_hsv[0]) < 0.0:
		return red
	return Color.from_hsv(float(_hsv[0]), minf(1.0, red.s * float(_hsv[1])), minf(1.0, red.v * float(_hsv[2])))


## The screen flash when she changes over, in her new colour.
static func flash_colour() -> Color:
	if float(_hsv[0]) < 0.0:
		return Color(0.95, 0.19, 0.24, 0.55)   # her red
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



## The same as accent() in the shader, for colours set in code.
static func tint(c: Color) -> Color:
	if pink <= 0.0 or float(_hsv[0]) < 0.0:
		return c
	var from_red := minf(c.h, 1.0 - c.h)
	var w := (1.0 - smoothstep(0.05, 0.11, from_red)) * smoothstep(0.12, 0.3, c.s)
	var p := Color.from_hsv(float(_hsv[0]), minf(1.0, c.s * float(_hsv[1])), minf(1.0, c.v * float(_hsv[2])), c.a)
	return c.lerp(p, w * pink)

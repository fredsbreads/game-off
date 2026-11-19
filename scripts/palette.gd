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

## The game's second colour (the first is her red): the colour picked in
## Options, at full strength whatever the level (the HUD, the PERFECT text,
## the katana's grip...). Red (Hair): her red.
static func secondary() -> Color:
	if float(_hsv[0]) < 0.0:
		return Color(0.95, 0.15, 0.2)
	return Color.from_hsv(float(_hsv[0]), minf(1.0, 0.82 * float(_hsv[1])), minf(1.0, 1.0 * float(_hsv[2])))


## True with Red (Hair) picked: her colour never changes.
static func keeps_red() -> bool:
	return float(_hsv[0]) < 0.0


## How a colour's name is shown (the Options screen, the C key).
static func display_name(name: String) -> String:
	return "Red (Hair)" if name == "red" else name.capitalize()

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
	_hsv = COLOURS[name].duplicate()
	RenderingServer.global_shader_parameter_set("accent_hue", float(_hsv[0]))
	RenderingServer.global_shader_parameter_set("accent_sat", float(_hsv[1]))
	RenderingServer.global_shader_parameter_set("accent_val", float(_hsv[2]))
	RenderingServer.global_shader_parameter_set("accent2", secondary())   # (her katana's hilt)


# --- The rainbow (a flawless streak of 100) ----------------------------------
# Her colour fades from one of these to the next, RAINBOW_STEP seconds each,
# whatever colour is picked in Options; in an auto-chain it steps on every hit.

## Its own list (not the Options colours): twelve hues round the wheel, her
## red first, and an indigo between blue and violet. [name, hue, sat x, val x]
## as in COLOURS ("red" here is her red as a hue: 0.99).
const RAINBOW_ORDER := [
	["red", 0.99, 1.0, 1.0], ["ember", 0.045, 1.0, 1.0], ["orange", 0.07, 1.0, 1.0],
	["yellow", 0.14, 0.95, 1.05], ["lime", 0.22, 0.95, 0.95], ["green", 0.33, 0.95, 0.85],
	["teal", 0.47, 1.0, 0.8], ["cyan", 0.53, 0.9, 1.0], ["blue", 0.61, 0.95, 1.0],
	["indigo", 0.68, 0.95, 1.0], ["violet", 0.74, 0.85, 1.0], ["magenta", 0.85, 0.9, 0.95],
]
const RAINBOW_STEP := 1.0
static var rainbow := false
## While true (an auto-chain, a finisher), the rainbow doesn't fade on its own.
static var rainbow_hold := false
static var _rainbow_t := 0.0


## On: the rainbow takes over her colour. Off: back to the colour picked.
static func set_rainbow(on: bool) -> void:
	if on == rainbow:
		return
	rainbow = on
	if on:
		# From the colour she has (one not in it, e.g. Pink: from her red).
		_rainbow_t = 0.0
		for i in RAINBOW_ORDER.size():
			if RAINBOW_ORDER[i][0] == colour_name:
				_rainbow_t = float(i)
		tick(0.0)
	else:
		use_colour(colour_name)


## The next colour at once (a hit in an auto-chain, a finisher's slash).
static func rainbow_next() -> void:
	rainbow_at(floorf(_rainbow_t) + 1.0)


## Jump to a point in the rainbow (0 = its first colour, 1 = the next...).
static func rainbow_at(t: float) -> void:
	if not rainbow:
		return
	_rainbow_t = fposmod(t, float(RAINBOW_ORDER.size()))
	tick(0.0)


static func rainbow_pos() -> float:
	return _rainbow_t


## Called every frame (main.gd): fades the rainbow on.
static func tick(delta: float) -> void:
	if not rainbow:
		return
	var n := RAINBOW_ORDER.size()
	if not rainbow_hold:
		_rainbow_t = fposmod(_rainbow_t + delta / RAINBOW_STEP, float(n))
	var i := int(_rainbow_t)
	var f := _rainbow_t - float(i)
	var a: Array = RAINBOW_ORDER[i].slice(1)
	var b: Array = RAINBOW_ORDER[(i + 1) % n].slice(1)
	var dh := fposmod(float(b[0]) - float(a[0]) + 0.5, 1.0) - 0.5   # (the short way round)
	_hsv[0] = fposmod(float(a[0]) + dh * f, 1.0)
	_hsv[1] = lerpf(float(a[1]), float(b[1]), f)
	_hsv[2] = lerpf(float(a[2]), float(b[2]), f)
	RenderingServer.global_shader_parameter_set("accent_hue", float(_hsv[0]))
	RenderingServer.global_shader_parameter_set("accent_sat", float(_hsv[1]))
	RenderingServer.global_shader_parameter_set("accent_val", float(_hsv[2]))
	RenderingServer.global_shader_parameter_set("accent2", secondary())


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

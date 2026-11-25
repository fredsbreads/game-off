class_name CreditsScreen
extends Control
## The Credits screen (from the title screen). Drawn in code like the Options
## screen; main.gd passes it every press while it's open. Any key, click or
## tap closes it.

signal closed

const TITLE_SIZE := 44
const BYLINE_SIZE := 26
const ROLE_SIZE := 20
const CREDIT_SIZE := 20
const LINE := 34.0
const HINT_SIZE := 18

const BYLINE := "A game by FredTheBread"
## [what it is, the work and who made it]
const CREDITS := [
	["Kunoichi", "Inspired by Ninja 2D Pixel Character, by mirokaz"],
	["Enemies", "Martial Hero, Martial Hero 2, Martial Hero 3 and Hero Knight, by LuizMelo"],
	["Frog", "Frogs Pixel Asset Pack, by Pop Shop Packs"],
	["Forest", "Free Pixel Night Forest, by thqian"],
	["Lightning", "Pixel Art Skill Animations: Lightning (effects and sounds), by Frostwindz"],
	["Music", "Suspense Tension Building, from Pixabay"],
	["Sound Effects", "Mixkit"],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


## A fresh press while it's open: any key, click or tap goes back.
func handle(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton:
		close()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()   # (the view can change size: phones turning)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.03))
	# Everything shrinks together if the screen's too small for it.
	var role_w := 0.0
	var credit_w := 0.0
	for c in CREDITS:
		role_w = maxf(role_w, font.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ROLE_SIZE).x)
		credit_w = maxf(credit_w, font.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CREDIT_SIZE).x)
	var gap := 22.0
	var block_w := role_w + gap + credit_w
	var block_h := TITLE_SIZE + 18.0 + BYLINE_SIZE + 36.0 + LINE * CREDITS.size() + 30.0 + HINT_SIZE
	var k := minf(1.0, minf((size.x - 40.0) / block_w, (size.y - 24.0) / block_h))
	var y := (size.y - block_h * k) / 2.0
	y = _centred("CREDITS", TITLE_SIZE, MainMenu.TITLE_TEXT_RED, y, k)
	y += 18.0 * k
	y = _centred(BYLINE, BYLINE_SIZE, Color.WHITE, y, k)
	y += 36.0 * k
	var left := (size.x - block_w * k) / 2.0
	for c in CREDITS:
		var rs := int(ROLE_SIZE * k)
		var cs := int(CREDIT_SIZE * k)
		var rw := font.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x
		# What it is, right-aligned in its column; the credit after it.
		draw_string(font, Vector2(left + role_w * k - rw, y + rs * 0.8), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, rs, Color(1, 1, 1, 0.55))
		draw_string(font, Vector2(left + (role_w + gap) * k, y + cs * 0.8), c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color(1, 1, 1, 0.92))
		y += LINE * k
	y += 30.0 * k - LINE * k + CREDIT_SIZE * k
	_centred("Tap To Go Back" if Hud.is_touch() else "Press Any Key To Go Back", HINT_SIZE, Color(1, 1, 1, 0.45), y, k)


## A line of text centred across the screen at y (its top), scaled by k.
## Returns the y under it.
func _centred(text: String, fsize: int, col: Color, y: float, k: float) -> float:
	var font := ThemeDB.fallback_font
	var s := int(fsize * k)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(font, Vector2((size.x - w) / 2.0, y + s * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
	return y + s

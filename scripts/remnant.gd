class_name Remnant
extends Knight
## One of the Shadow's remnants (shadow.gd): what she leaves on each spot she
## blinks through, in her idle. Cut down in one hit, but only in the order she made them
## (main.gd); stood across from or run into, they cut her down like a knight.

var shadow: Shadow
var order := 0   # 0: the first she made this round
var fx: Fx       # (main.gd) for its burst when cut
## (An auto-chain) it stands in for her: as she looks, and cut it's a clash
## with her, not a remnant bursting (main.gd _shadow_auto_cut).
var as_her := false:
	set(v):
		as_her = v
		modulate.a = 1.0 if v else 0.72
		if v and _sprite:
			_sprite.play(art["engaged_anim"])   # (her waiting pose, as she is)
			_sprite.frame = art["engaged_frame"]
			_sprite.pause()
var _t := 0.0


func _init() -> void:
	art = Shadow.SHADOW_ART
	hides_path = true


func _ready() -> void:
	super._ready()
	modulate = Color(1, 1, 1, 0.72)   # fainter than her
	_t = randf() * 10.0


## Cut: it bursts and is gone (no body left behind); standing in for her, it
## just goes (she's blinked on).
func die() -> void:
	super.die()
	if not as_her:
		Shadow.explode(fx, _sprite.global_position + Vector2(0, -Rules.TILE * 0.6 * scale.y), 0.45)
	visible = false


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	Shadow.glow(_material, _t, (1.0 if as_her else 0.7) if alive else 0.0)


## Her killing blow: one of her two big strikes (Shadow._pick_kill).
func _pick_kill() -> void:
	Shadow.set_kill_swing(self, Shadow.KILL_SWINGS.pick_random())


## (Across from the player) a remnant doesn't wind up: it stays in her idle.
func _hold_windup() -> void:
	pass

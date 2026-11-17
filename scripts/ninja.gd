class_name Ninja
extends Knight
## The second teleporter (debuts in level 10, Patterns.NINJA_DEBUT_LEVEL): a
## ninja, a man. Everything the knight does, he does too: several hits, a blink
## to one of the player's landing spots after each, and he strikes if the
## player runs on past him across the rows or lets a freeze run out there.
##
## And he also watches straight ahead: while the player is in his row with him
## inside the forward teleport's reach (forward_aggro), he drops into his
## stance (hand on his sword) with an alert. If she's still there after
## Rules.NINJA_AGGRO_DELAY seconds of running, or a freeze runs out with him
## there, he teleports to her and cuts her down; once he's been alerted, coming
## back into his reach brings him at once. main.gd runs it; ChunkSolver
## mirrors the running part.
## Art: "Martial Hero 2" (CC0), assets/sprites/ninja.

const N_IDLE := preload("res://assets/sprites/ninja/idle.png")
const N_RUN := preload("res://assets/sprites/ninja/run.png")           # frame 6 (both feet down, hand on his sword): his stance
const N_ATTACK := preload("res://assets/sprites/ninja/attack.png")     # "Attack1": his clash swings
const N_ATTACK2 := preload("res://assets/sprites/ninja/attack2.png")   # "Attack2": the killing blow
const N_TAKE_HIT := preload("res://assets/sprites/ninja/take_hit.png")
const N_DEATH := preload("res://assets/sprites/ninja/death.png")
const N_STANCE_FRAME := 6

const NINJA_ART := {
	"frame": Vector2i(200, 200), "feet": Vector2(100, 128), "scale": 1.75,
	"anims": [["idle", N_IDLE, 10.0, true], ["death", N_DEATH, 12.0, false],
		["attack", N_ATTACK, 14.0, false], ["kill", N_ATTACK2, 14.0, false],
		["hit", N_TAKE_HIT, 12.0, false, 3],
		["stance", N_RUN, 1.0, false, 1, N_STANCE_FRAME]],
	"kill_frame": 2, "kill_body_from": {},
	"swings": [
		{"sheet": N_ATTACK, "frames": [1, 2, 3], "hold": 2, "body_from": {}},
		{"sheet": N_ATTACK2, "frames": [1, 2, 3], "hold": 2, "body_from": {}},
	],
	"by_pose": [
		{"swing": 0, "gap": 1.6},
		{"swing": 1, "gap": 2.4},
		{"swing": 0, "gap": 1.6},
	],
	"windup_anim": "stance", "windup_frame": 0,
	"attack_start": 1,
}


func _init() -> void:
	art = NINJA_ART
	forward_aggro = true

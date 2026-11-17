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
const N_STANCE := preload("res://assets/sprites/ninja/stance.png")     # his stance: the last frame of "Run" (both feet down, hand on his sword), lowered onto the ground
const N_ATTACK := preload("res://assets/sprites/ninja/attack.png")     # "Attack1": his clash swings
const N_ATTACK2 := preload("res://assets/sprites/ninja/attack2.png")   # "Attack2": the killing blow
const N_TAKE_HIT := preload("res://assets/sprites/ninja/take_hit.png")
const N_DEATH := preload("res://assets/sprites/ninja/death.png")

const NINJA_ART := {
	"frame": Vector2i(200, 200), "feet": Vector2(100, 128), "scale": 2.1,
	"anims": [["idle", N_IDLE, 5.0, true], ["death", N_DEATH, 12.0, false],
		["attack", N_ATTACK, 14.0, false], ["kill", N_ATTACK2, 14.0, false],
		["hit", N_TAKE_HIT, 12.0, false, 3],
		["stance", N_STANCE, 1.0, false, 1]],
	"kill_frame": 2, "kill_body_from": {},
	"swings": [
		{"sheet": N_ATTACK, "frames": [1, 2, 3], "hold": 2, "body_from": {}},
		{"sheet": N_ATTACK2, "frames": [1, 2, 3], "hold": 2, "body_from": {}},
	],
	"by_pose": [
		{"swing": 0, "gap": 1.9},
		{"swing": 1, "gap": 2.9},
		{"swing": 0, "gap": 1.9},
	],
	"windup_anim": "stance", "windup_frame": 0,
	"attack_start": 1,
	"lightning": "cyan", "outline": Color(0.35, 0.9, 1.0, 1.0),
}


func _init() -> void:
	art = NINJA_ART
	forward_aggro = true

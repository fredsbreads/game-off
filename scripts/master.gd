class_name Master
extends Ninja
## The third teleporter (debuts in level 15, Patterns.MASTER_DEBUT_LEVEL): the
## master, a man. Everything the ninja does, he does too (and the knight's
## rules), and he takes the most hits (Rules.MASTER_HITS_MIN-MAX). And he also
## watches diagonally (diag_aggro): the instant she could teleport to him
## diagonally (in the other row, under her diagonal marker) he drops into his
## stance with an alert, and holds it; the instant he's in the other row in
## front of her but nearer than that and not yet straight across (she ran on
## past her chance, or a teleport landed her there), he teleports to her and
## cuts her down. So in either row: take your chance at him as it comes.
## Art: "Martial Hero" (CC0), assets/sprites/master, his red scarf purple.

const M_IDLE := preload("res://assets/sprites/master/idle.png")
const M_RUN := preload("res://assets/sprites/master/run.png")           # frame 5: his stance when he alerts
const M_ATTACK := preload("res://assets/sprites/master/attack.png")     # "Attack1": clash swings, and the killing blow (frame 4)
const M_ATTACK2 := preload("res://assets/sprites/master/attack2.png")   # "Attack2": clash swings
const M_TAKE_HIT := preload("res://assets/sprites/master/take_hit.png")
const M_DEATH := preload("res://assets/sprites/master/death.png")

const MASTER_ART := {
	"frame": Vector2i(200, 200), "feet": Vector2(94, 122), "scale": 2.2,
	"anims": [["idle", M_IDLE, 6.0, true], ["death", M_DEATH, 12.0, false],
		["attack", M_ATTACK, 14.0, false], ["kill", M_ATTACK, 14.0, false],
		["hit", M_TAKE_HIT, 12.0, false, 3],
		["stance", M_RUN, 1.0, false, 1, 5]],
	"kill_frame": 4, "kill_body_from": {},
	"swings": [
		{"sheet": M_ATTACK, "frames": [3, 4, 5], "hold": 4, "body_from": {}},
		{"sheet": M_ATTACK2, "frames": [3, 4, 5], "hold": 4, "body_from": {}},
	],
	"by_pose": [
		{"swing": 0, "gap": 1.9},
		{"swing": 1, "gap": 2.9},
		{"swing": 0, "gap": 1.9},
	],
	# Each clash, by her strike pose: which of his swings can answer it (one
	# picked at random) and how far (tiles) past his spot it's drawn.
	# Pose 3 is only ever answered by Attack2.
	"pose_swings": [
		[{"swing": 0, "gap": 3.4}, {"swing": 1, "gap": 3.4}],
		[{"swing": 0, "gap": 3.9}, {"swing": 1, "gap": 3.4}],
		[{"swing": 1, "gap": 3.4}],
	],
	"kill_distance": 3.1,   # tiles ahead of her he strikes from (the knight's 2.6, half a tile further)
	"windup_anim": "stance", "windup_frame": 0,
	"engaged_anim": "stance", "engaged_frame": 0,   # after a clash: his stance too
	"attack_start": 3,
	"lightning": "purple", "outline": Color(0.75, 0.45, 1.0, 1.0),
	"alert_pitch": 0.9,
}


func _init() -> void:
	art = MASTER_ART
	forward_aggro = true
	diag_aggro = true

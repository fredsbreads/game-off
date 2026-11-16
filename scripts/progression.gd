class_name Progression
extends RefCounted
## The progression bar and level.
##
## Each kill in a chain adds 1 to a temporary portion. When the chain ends,
## that portion is added to the bar, multiplied by how the chain ended:
##   PERFECT  ended on a kill, nothing more to chain, and this chain
##            killed the whole spawned chain, first enemy to last       x1.5
##   CLEAN    ended on a kill, nothing more to chain, but some of the
##            spawned chain wasn't part of it (skipped or joined late)  x1
##   DROPPED  the "your move" freeze ran out, or you teleported into empty
##            space while an enemy was under a marker                   x0.5
##   SINGLE   a one-kill chain                                           x1
## "Skipped" = an enemy that was under one of your markers during the chain
## and is still alive when it ends.
##
## The bar can't go past full (no overflow). Levelling up only happens when a
## PERFECT or CLEAN chain ends with the bar full; a DROPPED or SINGLE chain
## can fill it, but the level-up then waits for the next good ending.
##
## Bar size at level x = CHAINS_PER_LEVEL x the average chain length at that
## level, so two clean chains fill it, or a perfect plus a bit more (one
## perfect is three quarters of it; two overfill it).

const CHAINS_PER_LEVEL := 2.0
const MULTIPLIER := {"PERFECT": 1.5, "CLEAN": 1.0, "DROPPED": 0.5, "SINGLE": 1.0}

var level := 1
var bar := 0.0


func bar_size() -> float:
	return CHAINS_PER_LEVEL * Patterns.average_chain_length(level)


## Adds a finished chain to the bar. Returns true if it levelled up.
func add_chain(kills: int, grade: String) -> bool:
	bar = minf(bar + kills * float(MULTIPLIER[grade]), bar_size())
	var can_level := grade == "PERFECT" or grade == "CLEAN"
	if can_level and bar >= bar_size() - 0.001:
		level += 1
		bar = 0.0
		return true
	return false

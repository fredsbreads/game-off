# Red Flash (working title)

An entry for [GitHub Game Off 2026](https://itch.io/jam/game-off-2026), theme **SHIFT**.

You're always running right. Throw your sword ahead and instantly teleport to it,
**shifting** between a short and a long distance. Land on enemies to slash them and
chain kills; long-jump over spikes.

> Status: grey-box prototype. Everything is drawn with placeholder shapes.

## Controls

You run along a floor and an upside-down ceiling, teleporting between them.
The original single-row short/long version is kept on the `short-long-version` branch.


| Action | Keyboard | Touch |
| --- | --- | --- |
| Forward teleport (6 tiles, same row) | `→` / `K` / `D` / `Right Shift` | tap the right half |
| Vertical teleport (straight across to the other row) | `←` / `↑` / `J` / `A` / `W` / `Left Shift` | tap the left half |
| Diagonal teleport (forward 6 + other row) | both at once | tap both halves at once |

Pause with `P` / `Esc` or the button in the top-right corner; any key or tap resumes.
The game also pauses itself when the window or app loses focus.

Practice mode: `N` (or the "Enemies" button on the pause screen) removes
every enemy so you can play around with the teleports. Press again and they
spawn again just off screen. It stays on across retries.

The three bolts show exactly where each teleport lands. On the ceiling you
run upside down.

## Rules

- Running into an enemy in your row kills you.
- Teleporting passes through everything; only the landing spot matters.
- Landing on an enemy kills it and snaps you exactly onto it (so chains line
  up). Exception: an across teleport onto an enemy behind you only pulls you
  back onto it if you can chain on from there; otherwise you stay put. It counts if
  any part of the enemy touches the landing zone (the line under the marker).
- Every landing zone reaches 0.8 tiles behind the landing spot and 1.25
  ahead (`KILL_BEHIND` / `KILL_AHEAD` in `scripts/rules.gd`), so pressing a
  little early still hits.
- You die when your body touches an enemy (`HIT_RADIUS`, 0.95 tiles between
  centres).
- A single press waits up to 4 frames in case the other button follows (a
  diagonal). While it waits you're committed: running into an enemy doesn't
  count. It hits if it would have hit from anywhere between where you pressed
  and where you are when it fires.
- A short cooldown of 0.2 s (12 frames) between teleports, shared by all of them; a kill resets it. A press of the other button during the cooldown fires as soon as it ends; pressing the same button again is ignored (`COOLDOWN_SECONDS` in `scripts/rules.gd`).
- Every kill gets a short hit freeze. If another enemy is under one of your
  markers, it becomes a 0.7 s "your move" pause (tap to skip).
- Each teleport has a marker at its landing spot: a lightning bolt, hollow
  and dull by default, solid when that teleport would slash an enemy right
  now (an enemy touching the line under it counts). In the "your move" pause the
  solid ones pulse.
- Run speed is a constant 6 tiles/s.
- Score, distance and the kill counter are tracked but **not shown** for now
  (kills, level reached and longest combo are on the game-over screen).
  Toggle with `SHOW_KILLS_UI` / `SHOW_SCORE_UI` / `SHOW_DISTANCE_UI` at the top of `scripts/hud.gd`.

## Progression

A bar above the ceiling row fills as you chain kills; filling it levels you up.

- Each kill in a chain adds 1 to a grey, temporary part of the bar. When the
  chain ends it's added for real, multiplied by how the chain ended:
  - **PERFECT** x1.5: ended on a kill, nothing left to chain, and the chain
    killed the whole spawned chain from its first enemy to its last
  - **CLEAN** x1: ended on a kill, but some of the spawned chain wasn't part
    of it (you joined late or skipped one)
  - **dropped** x0.5: the "your move" pause ran out (shows **TOO SLOW**), or
    you teleported into empty space while an enemy was under a marker
    (shows **MISSED**)
  - a one-kill chain counts x1 but never levels you up
- When a chain ends, the bar acts it out before counting it: PERFECT turns solid
  while an extra half grows in gold, CLEAN turns solid, a dropped chain keeps half
  while the other half crumbles off. (Colours: `PROGRESS_*` at the top of `scripts/hud.gd`.)
- No overflow. You level up only when a PERFECT or CLEAN chain ends with the
  bar full.
- Bar size = 3 x the average chain length at that level (so two perfect
  chains fill it). See `scripts/progression.gd`.
- Levels 1-3 use the hand-made patterns; each level adds new ones, which show
  up twice as often as the previous level's (older ones drop out). From level
  4, chains are generated: x-2 to x+2 enemies long at level x (at least 3),
  each step F, V or D with equal odds. On a level-up, the patterns not yet on
  screen are rebuilt for the new level.

## Art

- Enemy: "Martial Hero 3" asset pack (CC0, see `assets/sprites/martial_hero/License.txt`).
- `art/`: layered Piskel sources for the Red Flash sprites (the game uses the flattened PNGs in `assets/sprites`).

## Running it

Open the folder in **Godot 4.3** (GL Compatibility renderer) and press Play.
It targets a web export so it can be played in desktop and mobile browsers.

## Project layout

```
scenes/main.tscn        the only scene: Level, Player, FX, Camera, HUD
scripts/
  rules.gd              every gameplay number (distances, cooldown, speeds, scoring)
  patterns.gd           enemy patterns in step notation, generated chains, what spawns per level
  progression.gd        the progression bar and level
  chunk_solver.gd       brute-force "can this be played?" search (validator + bot)
  main.gd               game flow, input, per-frame rules, chains and grades
  level.gd              endless level built from the level's patterns, grey-box drawing
  player.gd             player + landing markers (drawing only; main.gd moves it)
  enemy.gd              enemy sprite (idle, death animation)
  camera_rig.gd         follow with fast catch-up after teleports, screen shake
  fx.gd                 trails, rings, slashes, particles, floating text
  hud.gd                progression bar, level-up banner, messages, rotate-device overlay, flash
  debug_tools.gd        bot / soak test / screenshots (only with command-line args)
tools/validate_patterns.gd
```

## Level design: patterns

The endless level is built from enemy **patterns** in `scripts/patterns.gd`,
written in step notation. The first enemy is the entry; each step places the
next enemy relative to the previous one:

| Step | Next enemy | You do |
| --- | --- | --- |
| `F` | same row, 6 ahead | forward right away |
| `V` | other row, straight across | vertical right away |
| `D` | other row, 6 ahead | diagonal right away |
| `F+` `V+` `D+` | same, 3 tiles further | run a beat, then that move (not spawned for now: `MAYBE_BEATS`) |
| `\|` | same row, 10 ahead | chain ends on purpose |

Example: `F V D F`. Each hand-made pattern has the level it's introduced at
(1-3); later levels are generated (see Progression).

After editing patterns, run the validator. It **proves every enemy in each
pattern can be chained**, flags duplicate layouts (mirrors included), checks
sample generated chains for levels 4-10, and prints the bar size per level:

```bash
godot --headless --path . -s tools/validate_patterns.gd
```

## Testing with the bot

A bot that plays using the same solver can soak-test the whole generator:

```bash
godot --headless --fixed-fps 60 --path . -- --bot --soak=4000 --seed=1
```

It prints `SOAK OK` if it reaches the distance, or `SOAK FAIL` with the chunk it
died in. Other options are listed at the top of `scripts/debug_tools.gd`
(`--autostart`, `--shots=DIR` for screenshots).

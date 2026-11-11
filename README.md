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

The three outlines show exactly where each teleport lands. On the ceiling you
run upside down.

## Rules

- Running into an enemy in your row kills you.
- Teleporting passes through everything; only the landing spot matters.
- Landing on an enemy kills it and snaps you exactly onto it.
- No cooldown for now (`COOLDOWN_TILES` in `scripts/rules.gd`; shared by all teleports).
- Every kill gets a short hit freeze. If another enemy is under one of your
  markers, it becomes a 0.7 s "your move" pause (tap to skip).
- Run speed is a constant 6 tiles/s.
- Score and chain are tracked but **not shown** for now; distance is shown.
  Toggle with `SHOW_SCORE_UI` / `SHOW_DISTANCE_UI` at the top of `scripts/hud.gd`.

## Running it

Open the folder in **Godot 4.3** (GL Compatibility renderer) and press Play.
It targets a web export so it can be played in desktop and mobile browsers.

## Project layout

```
scenes/main.tscn        the only scene: Level, Player, FX, Camera, HUD
scripts/
  rules.gd              every gameplay number (distances, cooldown, speeds, scoring)
  patterns.gd           enemy patterns in step notation (the level design)
  chunk_solver.gd       brute-force "can this be played?" search (validator + bot)
  main.gd               game flow, input, per-frame rules, scoring
  level.gd              endless level built from random patterns, grey-box drawing
  player.gd             player + landing markers (drawing only; main.gd moves it)
  enemy.gd              grey-box enemy
  camera_rig.gd         follow with fast catch-up after teleports, screen shake
  fx.gd                 trails, rings, slashes, particles, floating text
  hud.gd                score, chain, messages, rotate-device overlay, flash
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
| `F+` `V+` `D+` | same, 3 tiles further | run a beat, then that move (switched off for now: `INCLUDE_BEATS`) |
| `\|` | same row, 10 ahead | chain ends on purpose |

Example: `F V D+ F`. Patterns have a difficulty from 1 to 5; the further you
get, the harder the patterns it picks, with an occasional easy one.

After editing patterns, run the validator. It **proves every enemy in each
pattern can be chained**:

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

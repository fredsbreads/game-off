# Red Flash (working title)

An entry for [GitHub Game Off 2026](https://itch.io/jam/game-off-2026), theme **SHIFT**.

You're always running right. Throw your sword ahead and instantly teleport to it,
**shifting** between a short and a long distance. Land on enemies to slash them and
chain kills; long-jump over spikes.

> Status: grey-box prototype. Everything is drawn with placeholder shapes.

## Controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Short teleport (4.5 tiles) | `←` / `J` / `A` / `Left Shift` | tap the left half of the screen |
| Long teleport (9 tiles) | `→` / `K` / `D` / `Right Shift` | tap the right half of the screen |

Pause with `P` / `Esc` or the button in the top-right corner; any key or tap resumes.
The game also pauses itself when the window or app loses focus.

The two outlines ahead of the player show exactly where each teleport lands.
They dim while the teleport is recharging (the sword also disappears from your back).

## Rules

- Running into an enemy or spikes kills you.
- Teleporting passes through everything; only the landing spot matters.
- Landing on an enemy kills it **and instantly resets the cooldown**, so kills can chain.
- No spikes for now. Spike support is still in the code and can come back as a pattern step.
- **Score** = metres travelled + 100 × chain count per kill.
  The chain breaks after 1.5 s without a kill; clearing a hazard refreshes the timer.
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
| `S` | 4.5 tiles ahead | short teleport right away |
| `L` | 9 tiles ahead | long teleport right away |
| `s+` | 6.75 tiles ahead | run a beat, then short |
| `l+` | 11.25 tiles ahead | run a beat, then long |
| `\|` | 14 tiles ahead | chain ends on purpose |

Example: `S L s+ S`. Patterns have a difficulty from 1 to 5; the further you
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

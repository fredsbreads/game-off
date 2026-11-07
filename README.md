# Red Flash (working title)

An entry for [GitHub Game Off 2026](https://itch.io/jam/game-off-2026), theme **SHIFT**.

You're always running right. Throw your sword ahead and instantly teleport to it,
**shifting** between a short and a long distance. Land on enemies to slash them and
chain kills; long-jump over spikes.

> Status: grey-box prototype. Everything is drawn with placeholder shapes.

## Controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Short teleport (3 tiles) | `←` / `J` / `A` / `Left Shift` | tap the left half of the screen |
| Long teleport (6 tiles) | `→` / `K` / `D` / `Right Shift` | tap the right half of the screen |

The two outlines ahead of the player show exactly where each teleport lands.
They dim while the teleport is recharging (the sword also disappears from your back).

## Rules

- Running into an enemy or spikes kills you.
- Teleporting passes through everything; only the landing spot matters.
- Landing on an enemy kills it **and instantly resets the cooldown**, so kills can chain.
- Spikes are always 4–5 tiles wide: too wide for a short teleport, clearable with a long one.
- **Score** = metres travelled + 100 × chain count per kill.
  The chain breaks after 1.5 s without a kill; clearing a hazard refreshes the timer.
- Speed ramps from 6 to 10 tiles/s over the first 2000 m.
- Score, distance and chain are tracked but **not shown** for now
  (`SHOW_SCORE_UI` in `scripts/hud.gd`).

## Running it

Open the folder in **Godot 4.3** (GL Compatibility renderer) and press Play.
It targets a web export so it can be played in desktop and mobile browsers.

## Project layout

```
scenes/main.tscn        the only scene: Level, Player, FX, Camera, HUD
scripts/
  rules.gd              every gameplay number (distances, cooldown, speeds, scoring)
  chunks.gd             the hand-made level pieces + format validation
  chunk_solver.gd       brute-force "is this survivable?" search (validator + bot)
  main.gd               game flow, input, per-frame rules, scoring
  level.gd              endless tile strip built from random chunks, grey-box drawing
  player.gd             player + landing markers (drawing only; main.gd moves it)
  enemy.gd              grey-box enemy
  camera_rig.gd         follow with fast catch-up after teleports, screen shake
  fx.gd                 trails, rings, slashes, particles, floating text
  hud.gd                score, chain, messages, rotate-device overlay, flash
  debug_tools.gd        bot / soak test / screenshots (only with command-line args)
tools/validate_chunks.gd
```

## Level design: chunks

The endless level is made of short hand-made **chunks** in `scripts/chunks.gd`,
written as strings (`.` ground, `E` enemy, `^` spikes) with a difficulty
from 1 to 5. The further you get, the harder the chunks it picks, with an
occasional easy "breather" chunk.

After editing chunks, run the validator. It checks the format rules and **proves
each chunk is survivable** at slow, medium and top speed:

```bash
godot --headless --path . -s tools/validate_chunks.gd
```

## Testing with the bot

A bot that plays using the same solver can soak-test the whole generator:

```bash
godot --headless --fixed-fps 60 --path . -- --bot --soak=4000 --seed=1
```

It prints `SOAK OK` if it reaches the distance, or `SOAK FAIL` with the chunk it
died in. Other options are listed at the top of `scripts/debug_tools.gd`
(`--autostart`, `--shots=DIR` for screenshots).

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

The three katana markers show exactly where each teleport lands. On the ceiling you
run upside down.

## Rules

- Running into an enemy in your row kills you.
- Teleporting passes through everything; only the landing spot matters.
- Landing on an enemy kills it and puts you 0.7 tiles short of it, facing it
  (`STRIKE_OFFSET`; chains still line up: the next enemy is then just ahead
  of a marker's middle). Exception: an across teleport onto an enemy behind you only pulls you
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
- Each teleport has a marker: a small katana floating over its landing spot
  (the line on the floor/ceiling under it is the landing zone). When an enemy
  is in that teleport's range (touching the line), the katana turns red and
  hovers over his head, following him; it snaps back when he's out of range.
  In the "your move" pause the red drains toward the tip as the time to act
  runs out.
- Run speed is a constant 6 tiles/s.
- **The knight** (from level 5, `scripts/knight.gd`), a woman, takes 3-4
  hits. Each hit (swords clash) she blinks, with green lightning, to one of
  your three landing spots, picked when her chain was generated, so it's
  always catchable, and you chase her down. Each hit counts double on the
  bar, and the freeze after a clash is 1.5x as long, plus a short beat. On
  the clash frame she's already standing at her next spot (with the player's
  teleport strike in green from where she was), while the clash plays out
  where she was: both mid-swing, her swing left as a fading afterimage, a
  zoom, a flash and a shake. You can go again as soon as you could after any
  kill. She never blinks onto another enemy's spot, or back onto one she's
  been on.
  You can teleport past her, but not run past her across the rows: while
  you're straight across from her (your across teleport would hit her) she
  raises her sword and a swish starts; run on out of reach, or let a freeze
  run out (TOO SLOW) while across from her, and she teleports to you and cuts
  you down. A teleport that drops a chain (MISSED) and lands you across from
  her gets the same warning and grace as running there. Same if a freeze
  ends with her hit but not finished and within a teleport (6 tiles) of you.
  If two knights would strike at once (a freeze running out, running on or
  past, or running into one), both do: the one further ahead from the front,
  the other from behind the player (more than two: the two nearest).
  Level 5 opens with a knight alone (`KNIGHT_DEBUT_LEVEL`): her debut, always
  met by hand. While the power-up is charged or playing it waits (knight-free
  chains come instead, even past level 5) and comes once it's spent; the
  auto-chain never plays through her. From then on any
  enemy in a generated chain is a knight with a 5% chance at level 5, +2% per
  level (`KNIGHT_CHANCE`, `KNIGHT_CHANCE_STEP` in `scripts/patterns.gd`). A chain's
  length counts every hit (a knight's 3-4 hits use up 3-4 of it), so knights
  don't make chains longer.
  You may leave a duel early (chain onto another enemy instead of her), so a
  chain never ends within reach of a knight unless it ends on her: after each
  knight, it goes on more than a forward teleport past her furthest spot
  (`_strands_by_knight` in `scripts/patterns.gd`). Finishing a chain always
  leaves you clear of her.
- **The streak reward**: the Flawless Streak (shown right of the level bar)
  counts kills in a row, knight hits included, without letting an enemy get
  away or dropping a chain (TOO SLOW / MISSED); either one resets it. At 50
  (`STREAK_REWARD` in `scripts/main.gd`), the next chain that ends on a kill
  plays the finisher on that enemy: she blinks to the enemy's other side and back in
  each of her three strike poses (slowed, the world grey, a bolt onto each
  spot), the last held as a freeze frame while a wave sweeps across the
  screen turning her colour from red to her reward colour: hair, lightning,
  slashes, afterimages, markers, the target glint, and blood
  (`BLOOD_FOLLOWS_COLOUR`). She keeps it until the streak breaks, then snaps
  back to red with a crack (`streak_break.ogg`). `FINISHER_*` in
  `scripts/main.gd`; colours in `scripts/palette.gd` and
  `shaders/accent.gdshaderinc`.
- **The auto-chain power-up**: a thin meter under the level bar fills as
  chains end (CLEAN +1, PERFECT +2; full at 10; dropped and one-kill chains
  add nothing, and nothing drains it). Full = she's charged: her lightning
  ring loops around her (the "your move" freeze shows sparkles on her
  instead), the meter flashes. The meter is her red (her colour once she has
  it). Her next kill that has a chain
  after it sets it off: the rest of that chain plays itself, perfectly and
  fast (`AUTO_STEP` between hops); its last kill holds, zoomed in
  (`AUTO_FINALE_FREEZE`, `AUTO_FINALE_ZOOM`, `AUTO_FINALE_CRACKLE`; the music
  drops away through it, `AUTO_FINALE_DUCK_DB`), then the bang on a short
  frozen white frame (`AUTO_FINALE_IMPACT`), its thunder the loudest sound
  in the game (`AUTO_FINALE_DB`, a deep heavy hit under it; a limiter on the
  master bus keeps it clean): a big lightning strike, a
  full-screen flash and thunder (the hold is grey and crackling, like a
  freeze frame). No new chain is laid while it plays, so nothing pops in or
  out, and anyone still on screen ahead is struck down by the final strike; the next one comes in past the screen's edge (`AUTO_GAP_TILES`). The meter starts again from empty (the auto-chain
  adds nothing to it). Its kills count for the bar and the streak, but
  the streak finisher only plays at the end of a chain she played herself.
  `CHARGE_*`, `_auto_*` in `scripts/main.gd`.
- **Her reward colour** is one setting: `COLOUR` at the top of
  `scripts/palette.gd` (default `"yellow"`; every name is in `COLOURS`
  there). The pause screen's **Color** button steps through them (saved);
  on a keyboard, **C** does too and shows the name (off with `CYCLE_KEY`).
- Score, distance and the kill counter are tracked but **not shown** for now
  (kills, level reached and the best Flawless Streak (No Survivors) are on
  the game-over screen).
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
- Bar size = 2 x the average chain length at that level (so two clean
  chains fill it; one perfect fills three quarters). See `scripts/progression.gd`.
- Levels 1-3 use the hand-made patterns; each level adds new ones, which show
  up twice as often as the previous level's (older ones drop out). From level
  4, chains are generated: x-2 to x+2 enemies long at level x (at least 3),
  each step F, V or D with equal odds. In level 4 (so level 5 opens with
  the knight alone), once the chains already laid could (at best) fill the
  bar, no more are laid until it's decided, so the chain that levels you up
  is the last one at the old level; level 5's first chain starts just off
  screen. If those chains are dropped instead, laying resumes just off screen
  too. Every other level flows straight into the next.

## Art and sound

- Background music: "Suspense Tension Building" by Monume (Pixabay), in `assets/music/background.ogg`: the quiet intro plays once, then the body loops (seven 16 s phrases, a 1 s crossfade baked into the end of the file); the quiet fade-out is cut (`MUSIC_*` in `scripts/main.gd`).
- Enemy: "Martial Hero 3" asset pack (CC0, see `assets/sprites/martial_hero/License.txt`).
- Knight: "Hero Knight" asset pack (CC0, see `assets/sprites/hero_knight/License.txt`); her lightning is the Frostwindz pack recoloured green.
- Knight wind-up sound: "Sword blade swish" from Mixkit (same licence), in `assets/sounds/knight_warn.ogg`.
- Knight kill sound: "Samurai sword impact" from Mixkit (same licence), the impact only (the build-up cut off), in `assets/sounds/knight_kill.ogg`.
- Clash sound: "Heavy sword smashes metal" from Mixkit (same licence as the other Mixkit sounds), the crash only, in `assets/sounds/clash.ogg`.
- Lightning effects: "Pixel Art Skill Animations - Lightning" by Frostwindz (https://frostwindz.itch.io/), recoloured red, in `assets/vfx`.
- Kill sound: "Quick saber cut" from Mixkit (Mixkit free sound effects licence), trimmed to `assets/sounds/saber_cut.ogg`.
- Death sound: "Sword slash swoosh" from Mixkit (same licence), slowed down with echoes and a reverb tail, with the hit of "Big cinematic impact" under it, in `assets/sounds/death_slash.ogg`.
- TOO SLOW sound: the rumble after the hit of "Big cinematic impact" from Mixkit (same licence), in `assets/sounds/too_slow.ogg`.
- PERFECT chain sound: the kill sound with a higher layer, echoes and reverb added (`assets/sounds/perfect.ogg`).
- Teleport sounds: lightning strikes 16 (a move that hits nothing) and 13 (its first crack, quieter, under a kill) from the "Strike Solo" set (HoveAud, Lightning Magic), trimmed, in `assets/sounds/strike_*.ogg`.
- Level-up sound: the PERFECT sound with the hit of "Big cinematic impact" (filtered) under it (`assets/sounds/level_up.ogg`).
- `art/`: layered Piskel sources for the Red Flash sprites (the game uses the flattened PNGs in `assets/sprites`).
  After editing `art/red_flash_attack_frames.piskel`, regenerate the strike poses and slash arcs (needs Pillow):
  `python3 tools/build_attack_arcs.py art/red_flash_attack_frames.piskel assets/sprites/attack`.
  The arcs sweep along the swing in the game (`shaders/swing_arc.gdshader`, `ARC_*` in `scripts/player.gd`).

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
  knight.gd             the knight: several hits, blinks between landing spots
  palette.gd            her colour: red, her reward colour with a flawless streak
  camera_rig.gd         follow with fast catch-up after teleports, screen shake
  fx.gd                 trails, rings, slashes, particles, floating text
  hud.gd                progression bar, messages, rotate-device overlay, flash
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
(`--autostart`, `--shots=DIR` for screenshots, `--level=N` to start at a level).

The start screen has a **Start at level 1 / 5** button (tap it, or press L,
1 or 5): 5 goes straight to the knight's debut. The pause screen has a **Color**
button that steps through her reward colours. Both choices are saved
between visits (`user://save.cfg`).

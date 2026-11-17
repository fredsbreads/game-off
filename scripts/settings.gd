class_name Settings
extends RefCounted
## The player's options (the Options screen, see OptionsMenu), kept between
## visits in the save file (main.gd SAVE_PATH, section "settings"). In the
## browser the file lives in the browser's storage for the game's site, so it
## lasts as long as the player doesn't clear it (private windows forget it).

const SAVE_PATH := "user://save.cfg"

## Her flawless colour: "default" = Palette.COLOUR, else a name in Palette.COLOURS.
static var colour := "default"
## Volumes, 0 (off) to 1 (as mixed).
static var music := 1.0
static var sfx := 1.0
## Screen shake, 0 (none) to 1 (as tuned).
static var shake := 1.0
## Full-screen flashes: 1 = as tuned, FLASH_SOFT = gentler.
static var flashes := 1.0
const FLASH_SOFT := 0.3

const DEFAULTS := {"colour": "default", "music": 1.0, "sfx": 1.0, "shake": 1.0, "flashes": 1.0}


static func load_all() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # (missing on a first visit: every value stays default)
	colour = String(cfg.get_value("settings", "colour", DEFAULTS["colour"]))
	music = float(cfg.get_value("settings", "music", DEFAULTS["music"]))
	sfx = float(cfg.get_value("settings", "sfx", DEFAULTS["sfx"]))
	shake = float(cfg.get_value("settings", "shake", DEFAULTS["shake"]))
	flashes = float(cfg.get_value("settings", "flashes", DEFAULTS["flashes"]))
	apply()


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # keep the best score and the rest
	for key in DEFAULTS:
		cfg.set_value("settings", key, get_value(key))
	cfg.save(SAVE_PATH)


static func reset() -> void:
	for key in DEFAULTS:
		set_value(key, DEFAULTS[key])
	apply()
	save_all()


static func get_value(key: String) -> Variant:
	match key:
		"colour": return colour
		"music": return music
		"sfx": return sfx
		"shake": return shake
		"flashes": return flashes
	return null


static func set_value(key: String, value: Variant) -> void:
	match key:
		"colour": colour = String(value)
		"music": music = float(value)
		"sfx": sfx = float(value)
		"shake": shake = float(value)
		"flashes": flashes = float(value)


## Puts every setting into effect.
static func apply() -> void:
	_ensure_buses()
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	Palette.use_colour(Palette.COLOUR if colour == "default" or not Palette.COLOURS.has(colour) else colour)


## Two buses under Master: the music plays on "Music", every sound effect on
## "SFX" (main.gd sets each player's bus).
static func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


static func _set_bus(bus: String, volume: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, volume <= 0.001)
	# Squared, so the steps sound even (50% is about half as loud, not barely quieter).
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume * volume, 0.000001)))

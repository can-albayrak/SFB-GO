extends Node
## Local user settings: name, last loadout, FOV, sensitivity, crosshair (graphics/keys later).
## Persisted to user://settings.cfg; a settings menu comes in stage 9.

const CS_DEG_PER_COUNT: float = 0.022
const PATH: String = "user://settings.cfg"

var player_name: String = "Player"

## Last confirmed loadout (GDD: remembered, one click to respawn with it).
var loadout_class: StringName = &"wolf"
var loadout_primary: int = 0
var loadout_ability: int = 0

## Horizontal FOV measured at 4:3, same convention as CS (80–110).
var fov: float = 90.0
## CS-compatible: a CS sensitivity value feels the same here.
var mouse_sensitivity: float = 2.0

var crosshair_color: Color = Color(0.3, 1.0, 0.45)
var crosshair_length: float = 8.0
var crosshair_gap: float = 4.0
var crosshair_thickness: float = 2.0
var crosshair_dot: bool = false


func _ready() -> void:
	load_settings()


func get_vertical_fov() -> float:
	var half_h: float = deg_to_rad(fov) * 0.5
	return rad_to_deg(2.0 * atan(tan(half_h) * 0.75))


func get_look_degrees_per_count() -> float:
	return mouse_sensitivity * CS_DEG_PER_COUNT


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	player_name = _read(config, "player", "name", player_name)
	loadout_class = StringName(_read(config, "loadout", "class", String(loadout_class)))
	loadout_primary = _read(config, "loadout", "primary", loadout_primary)
	loadout_ability = _read(config, "loadout", "ability", loadout_ability)
	fov = _read(config, "view", "fov", fov)
	mouse_sensitivity = _read(config, "view", "sensitivity", mouse_sensitivity)
	crosshair_color = _read(config, "crosshair", "color", crosshair_color)
	crosshair_length = _read(config, "crosshair", "length", crosshair_length)
	crosshair_gap = _read(config, "crosshair", "gap", crosshair_gap)
	crosshair_thickness = _read(config, "crosshair", "thickness", crosshair_thickness)
	crosshair_dot = _read(config, "crosshair", "dot", crosshair_dot)


## A hand-edited file with a wrong type falls back to the current value instead of erroring.
func _read(config: ConfigFile, section: String, key: String, fallback: Variant) -> Variant:
	var value: Variant = config.get_value(section, key, fallback)
	if typeof(value) == typeof(fallback):
		return value
	if typeof(fallback) == TYPE_FLOAT and typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("loadout", "class", String(loadout_class))
	config.set_value("loadout", "primary", loadout_primary)
	config.set_value("loadout", "ability", loadout_ability)
	config.set_value("view", "fov", fov)
	config.set_value("view", "sensitivity", mouse_sensitivity)
	config.set_value("crosshair", "color", crosshair_color)
	config.set_value("crosshair", "length", crosshair_length)
	config.set_value("crosshair", "gap", crosshair_gap)
	config.set_value("crosshair", "thickness", crosshair_thickness)
	config.set_value("crosshair", "dot", crosshair_dot)
	config.save(PATH)

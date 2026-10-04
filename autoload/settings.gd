extends Node
## Local user settings: name, last loadout, FOV, sensitivity, crosshair, camera feel, graphics (keys later).
## Persisted to user://settings.cfg; edited in SettingsPanel (main menu and Esc menu).

## A value changed in the settings panel (crosshair redraws, etc.).
@warning_ignore("unused_signal")
signal changed

const CS_DEG_PER_COUNT: float = 0.022
const PATH: String = "user://settings.cfg"

var player_name: String = "Player"
## Last host address that connected (main menu "Last host" button).
var last_host: String = ""

## Last confirmed loadout (GDD: remembered, one click to respawn with it).
var loadout_class: StringName = &"wolf"
var loadout_primary: int = 0
var loadout_ability: int = 0

## Test Range only: abilities without a cooldown (toggle in the Esc panel).
var practice_unlimited_abilities: bool = false

## Horizontal FOV measured at 4:3, same convention as CS (80–110).
var fov: float = 90.0
## CS-compatible: a CS sensitivity value feels the same here.
var mouse_sensitivity: float = 2.0
## Sound effects volume, 0 (mute) .. 1.
var sfx_volume: float = 0.8

var crosshair_color: Color = Color(0.3, 1.0, 0.45)
var crosshair_length: float = 8.0
var crosshair_gap: float = 4.0
var crosshair_thickness: float = 2.0
var crosshair_dot: bool = false
## Show the X hit marker when the host confirms a hit.
var hit_marker_enabled: bool = true

## Camera feel, each 0 (off) .. 1 (full, as tuned in data/camera/default.tres).
var camera_fov_shift: float = 1.0
var camera_head_bob: float = 1.0
var camera_landing: float = 1.0
var camera_slide: float = 1.0
var camera_damage_shake: float = 1.0

## Graphics (GDD): PS2-style screen filter (grain, vignette, colour crush) and 3D render scale.
var post_process: bool = true
var render_scale: float = 1.0
## Borderless fullscreen on the current screen; false = a 1280x720 window. Alt+Enter / F11 toggle.
var fullscreen: bool = true


func _ready() -> void:
	load_settings()
	apply_window_mode()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		fullscreen = not fullscreen
		apply_window_mode()
		save_settings()
		changed.emit()
		get_viewport().set_input_as_handled()


## Sets the window to `fullscreen`. Left alone in headless runs and frame captures
## (--write-movie), so tests and preview shots keep the project's 1280x720.
func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless" or "--write-movie" in OS.get_cmdline_args():
		return
	var wanted: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)


## `extra` = degrees added to the horizontal FOV first (camera speed shift).
func get_vertical_fov(extra: float = 0.0) -> float:
	var half_h: float = deg_to_rad(clampf(fov + extra, 1.0, 170.0)) * 0.5
	return rad_to_deg(2.0 * atan(tan(half_h) * 0.75))


func get_look_degrees_per_count() -> float:
	return mouse_sensitivity * CS_DEG_PER_COUNT


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	player_name = _read(config, "player", "name", player_name)
	last_host = _read(config, "network", "last_host", last_host)
	loadout_class = StringName(_read(config, "loadout", "class", String(loadout_class)))
	loadout_primary = _read(config, "loadout", "primary", loadout_primary)
	loadout_ability = _read(config, "loadout", "ability", loadout_ability)
	practice_unlimited_abilities = _read(config, "practice", "unlimited_abilities", practice_unlimited_abilities)
	fov = _read(config, "view", "fov", fov)
	mouse_sensitivity = _read(config, "view", "sensitivity", mouse_sensitivity)
	crosshair_color = _read(config, "crosshair", "color", crosshair_color)
	crosshair_length = _read(config, "crosshair", "length", crosshair_length)
	crosshair_gap = _read(config, "crosshair", "gap", crosshair_gap)
	crosshair_thickness = _read(config, "crosshair", "thickness", crosshair_thickness)
	crosshair_dot = _read(config, "crosshair", "dot", crosshair_dot)
	hit_marker_enabled = _read(config, "crosshair", "hit_marker", hit_marker_enabled)
	sfx_volume = _read(config, "audio", "sfx_volume", sfx_volume)
	camera_fov_shift = _read(config, "camera", "fov_shift", camera_fov_shift)
	camera_head_bob = _read(config, "camera", "head_bob", camera_head_bob)
	camera_landing = _read(config, "camera", "landing", camera_landing)
	camera_slide = _read(config, "camera", "slide", camera_slide)
	camera_damage_shake = _read(config, "camera", "damage_shake", camera_damage_shake)
	post_process = _read(config, "graphics", "post_process", post_process)
	render_scale = clampf(_read(config, "graphics", "render_scale", render_scale), 0.5, 1.0)
	fullscreen = _read(config, "graphics", "fullscreen", fullscreen)


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
	config.set_value("network", "last_host", last_host)
	config.set_value("loadout", "class", String(loadout_class))
	config.set_value("loadout", "primary", loadout_primary)
	config.set_value("loadout", "ability", loadout_ability)
	config.set_value("practice", "unlimited_abilities", practice_unlimited_abilities)
	config.set_value("view", "fov", fov)
	config.set_value("view", "sensitivity", mouse_sensitivity)
	config.set_value("crosshair", "color", crosshair_color)
	config.set_value("crosshair", "length", crosshair_length)
	config.set_value("crosshair", "gap", crosshair_gap)
	config.set_value("crosshair", "thickness", crosshair_thickness)
	config.set_value("crosshair", "dot", crosshair_dot)
	config.set_value("crosshair", "hit_marker", hit_marker_enabled)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("camera", "fov_shift", camera_fov_shift)
	config.set_value("camera", "head_bob", camera_head_bob)
	config.set_value("camera", "landing", camera_landing)
	config.set_value("camera", "slide", camera_slide)
	config.set_value("camera", "damage_shake", camera_damage_shake)
	config.set_value("graphics", "post_process", post_process)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.save(PATH)

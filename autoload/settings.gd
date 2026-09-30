extends Node
## Local user settings: FOV, sensitivity, crosshair, key bindings, graphics.
## Persisted to user://settings.cfg (settings menu comes in a later stage).

const CS_DEG_PER_COUNT: float = 0.022

var player_name: String = "Player"

## Horizontal FOV measured at 4:3, same convention as CS (80–110).
var fov: float = 90.0
## CS-compatible: a CS sensitivity value feels the same here.
var mouse_sensitivity: float = 2.0

var crosshair_color: Color = Color(0.3, 1.0, 0.45)
var crosshair_length: float = 8.0
var crosshair_gap: float = 4.0
var crosshair_thickness: float = 2.0
var crosshair_dot: bool = false


func get_vertical_fov() -> float:
	var half_h: float = deg_to_rad(fov) * 0.5
	return rad_to_deg(2.0 * atan(tan(half_h) * 0.75))


func get_look_degrees_per_count() -> float:
	return mouse_sensitivity * CS_DEG_PER_COUNT

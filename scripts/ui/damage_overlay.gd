class_name DamageOverlay
extends CanvasLayer
## Red at the screen edges (own player only, visual): a short flash on every hit, and a lasting
## edge that grows as health drops. Values in CameraFeelDef (data/camera/default.tres);
## Settings.camera_damage_shake scales it with the damage shake. Drawn above the PS2 screen
## filter (ScreenFx), which would otherwise wash the red out. Also the hit direction
## indicator: a thin faint arc around the crosshair toward whoever hurt us (Events.local_hurt_from).

const LAYER: int = ScreenFx.LAYER + 1

const SHADER_CODE: String = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.25, length(centred * vec2(1.0, 0.85)));
	COLOR = vec4(0.55, 0.0, 0.0, clamp(edge * strength * 1.25, 0.0, 0.7));
}
"""

var _flash: float = 0.0
var _lasting: float = 0.0
var _last_health: int = -1
var _material: ShaderMaterial
var _rect: ColorRect
var _arcs: Control
var _player: Player
var _hits: Array[Array] = [] ## [source: Vector3, seconds left: float], newest last.


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	_arcs = Control.new()
	_arcs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arcs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arcs.draw.connect(_draw_arcs)
	add_child(_arcs)
	Events.local_hurt_from.connect(_on_hurt_from)


## HUD: a new local player (respawn or class change) starts clean.
func watch(player: Player) -> void:
	_last_health = -1
	_flash = 0.0
	_player = player
	_hits.clear()
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.class_def.max_health if player.class_def != null else player.health)


func _on_health_changed(health: int, max_health: int) -> void:
	var def: CameraFeelDef = CameraFeel.DEF
	if _last_health >= 0 and health < _last_health and health > 0:
		var share: float = clampf(float(_last_health - health) / maxf(def.hurt_full_damage, 1.0), def.hurt_min_share, 1.0)
		_flash = maxf(_flash, def.hurt_flash_alpha * share)
		Sfx.play_ui(self, Sfx.HURT, Sfx.UI_DB + 2.0 * share)
	_last_health = health
	var left: float = float(health) / float(maxi(max_health, 1))
	_lasting = 0.0
	if health > 0 and left < def.low_health_start:
		_lasting = def.low_health_alpha * (1.0 - left / def.low_health_start)


func _on_hurt_from(source: Vector3) -> void:
	for hit: Array in _hits:
		if (hit[0] as Vector3).distance_to(source) < 2.0: # Same shooter: refresh, don't stack.
			_hits.erase(hit)
			break
	_hits.append([source, CameraFeel.DEF.hit_dir_time])
	if _hits.size() > 4:
		_hits.pop_front()


func _draw_arcs() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(_player) or not _player.is_alive:
		return
	var def: CameraFeelDef = CameraFeel.DEF
	var size: Vector2 = _arcs.size
	var centre: Vector2 = size * 0.5
	var radius: float = size.y * def.hit_dir_radius
	var half_arc: float = deg_to_rad(def.hit_dir_arc_degrees) * 0.5
	var width: float = maxf(def.hit_dir_width * size.y / 1080.0, 1.0)
	var forward: Vector3 = -camera.global_basis.z
	var right: Vector3 = camera.global_basis.x
	for hit: Array in _hits:
		var to_source: Vector3 = (hit[0] as Vector3) - _player.global_position
		# 0 = straight ahead (top of the screen), positive = to the right.
		var angle: float = atan2(to_source.dot(right), Vector2(forward.x, forward.z).normalized().dot(Vector2(to_source.x, to_source.z)))
		var alpha: float = def.hit_dir_alpha * clampf(float(hit[1]) / maxf(def.hit_dir_time, 0.01), 0.0, 1.0)
		var mid: float = angle - PI * 0.5 # draw_arc: 0 = +X, screen y points down.
		_arcs.draw_arc(centre, radius, mid - half_arc, mid + half_arc, 16, Color(0.85, 0.08, 0.05, alpha), width, true)


func _process(delta: float) -> void:
	var def: CameraFeelDef = CameraFeel.DEF
	for i: int in range(_hits.size() - 1, -1, -1):
		_hits[i][1] = float(_hits[i][1]) - delta
		if float(_hits[i][1]) <= 0.0:
			_hits.remove_at(i)
	_arcs.queue_redraw()
	_flash = maxf(_flash - delta * def.hurt_flash_alpha / maxf(def.hurt_flash_time, 0.01), 0.0)
	var strength: float = clampf((_flash + _lasting) * Settings.camera_damage_shake, 0.0, 1.0)
	_rect.visible = strength > 0.001
	_material.set_shader_parameter(&"strength", strength)

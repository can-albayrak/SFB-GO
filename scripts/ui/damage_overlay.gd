class_name DamageOverlay
extends CanvasLayer
## Red at the screen edges (own player only, visual): a short flash on every hit, and a lasting
## edge that grows as health drops. Values in CameraFeelDef (data/camera/default.tres);
## Settings.camera_damage_shake scales it with the damage shake. Drawn above the PS2 screen
## filter (ScreenFx), which would otherwise wash the red out.

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


## HUD: a new local player (respawn or class change) starts clean.
func watch(player: Player) -> void:
	_last_health = -1
	_flash = 0.0
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.class_def.max_health if player.class_def != null else player.health)


func _on_health_changed(health: int, max_health: int) -> void:
	var def: CameraFeelDef = CameraFeel.DEF
	if _last_health >= 0 and health < _last_health and health > 0:
		var share: float = clampf(float(_last_health - health) / maxf(def.hurt_full_damage, 1.0), def.hurt_min_share, 1.0)
		_flash = maxf(_flash, def.hurt_flash_alpha * share)
	_last_health = health
	var left: float = float(health) / float(maxi(max_health, 1))
	_lasting = 0.0
	if health > 0 and left < def.low_health_start:
		_lasting = def.low_health_alpha * (1.0 - left / def.low_health_start)


func _process(delta: float) -> void:
	var def: CameraFeelDef = CameraFeel.DEF
	_flash = maxf(_flash - delta * def.hurt_flash_alpha / maxf(def.hurt_flash_time, 0.01), 0.0)
	var strength: float = clampf((_flash + _lasting) * Settings.camera_damage_shake, 0.0, 1.0)
	_rect.visible = strength > 0.001
	_material.set_shader_parameter(&"strength", strength)

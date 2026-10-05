class_name GoldSrcMap
extends Node3D
## Root of a map converted from a GoldSrc BSP (tools/maps/import_goldsrc_bsp.py). On load,
## swaps the imported materials for an unshaded shader: the map's texture (pixelated) times
## its own baked lightmap (second UV set, `lightmap`). Cut-out ("{") textures keep their holes.

const SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, %s;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D lightmap : source_color, filter_linear, repeat_disable;
uniform float light_gain = 1.6;
uniform float light_gamma = 0.8;
void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	if (texel.a < 0.5) {
		discard;
	}
	vec3 light = pow(texture(lightmap, UV2).rgb, vec3(light_gamma));
	ALBEDO = texel.rgb * light * light_gain;
}
"""

@export var lightmap: Texture2D
@export var light_gain: float = 1.9 ## GoldSrc draws lightmaps brighter than their raw bytes.
@export var light_gamma: float = 0.75 ## Below 1 lifts the shadows.

static var _solid: Shader
static var _cut_out: Shader ## Fences, grates: holes and both sides drawn.


func _ready() -> void:
	if _solid == null:
		_solid = Shader.new()
		_solid.code = SHADER_CODE % "cull_back"
		_cut_out = Shader.new()
		_cut_out.code = SHADER_CODE % "cull_disabled"
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var mesh: Mesh = mesh_instance.mesh
		for surface: int in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface) as BaseMaterial3D
			var cut_out: bool = source != null and source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var material := ShaderMaterial.new()
			material.shader = _cut_out if cut_out else _solid
			material.set_shader_parameter(&"lightmap", lightmap)
			material.set_shader_parameter(&"light_gain", light_gain)
			material.set_shader_parameter(&"light_gamma", light_gamma)
			if source != null:
				material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
			mesh_instance.set_surface_override_material(surface, material)

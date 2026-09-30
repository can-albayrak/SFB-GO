class_name ShotEffects
extends RefCounted
## Cosmetic-only shot visuals (tracer line, impact mark). Never affects gameplay.

const TRACER_TIME: float = 0.05
const TRACER_COLOR: Color = Color(1.0, 0.85, 0.4)
const IMPACT_RADIUS: float = 0.025
const IMPACT_LIFETIME: float = 8.0

static var _tracer_material: StandardMaterial3D
static var _impact_mesh: SphereMesh


## `parent` must sit at the world origin (map or Players root); vertices are in its space.
static func spawn_tracer(parent: Node3D, from: Vector3, to: Vector3) -> void:
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.albedo_color = TRACER_COLOR
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _tracer_material)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	parent.get_tree().create_timer(TRACER_TIME).timeout.connect(instance.queue_free)


static func spawn_impact(parent: Node3D, point: Vector3) -> void:
	if _impact_mesh == null:
		_impact_mesh = SphereMesh.new()
		_impact_mesh.radius = IMPACT_RADIUS
		_impact_mesh.height = IMPACT_RADIUS * 2.0
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.BLACK
		_impact_mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = _impact_mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = point # Before add_child so interpolation never starts at the origin.
	parent.add_child(instance)
	parent.get_tree().create_timer(IMPACT_LIFETIME).timeout.connect(instance.queue_free)

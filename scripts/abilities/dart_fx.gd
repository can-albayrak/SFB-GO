class_name DartFx
extends MeshInstance3D
## Cosmetic Swap Dart on every peer: flies straight from the host's start with its velocity and
## vanishes at the first wall or when its time is up. The host's SwapDart decides any hit.

const WORLD_MASK: int = 1
const COLOR: Color = Color(1.0, 0.85, 0.3)

var _velocity: Vector3
var _left: float = 0.0
var _exclude: Array[RID] = []


static func create(start: Vector3, velocity: Vector3, seconds: float, exclude: Array[RID]) -> DartFx:
	var dart := DartFx.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.018
	mesh.height = PlayerEffects.DART_LENGTH
	mesh.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR
	mesh.material = material
	dart.mesh = mesh
	dart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dart.position = start
	dart._velocity = velocity
	dart._left = seconds
	dart._exclude = exclude
	return dart


func _ready() -> void:
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity, Vector3.UP if absf(_velocity.normalized().y) < 0.99 else Vector3.FORWARD)
		rotate_object_local(Vector3.RIGHT, -PI * 0.5) # The cone's tip (+Y) leads.


func _process(delta: float) -> void:
	_left -= delta
	var to: Vector3 = global_position + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, to, WORLD_MASK, _exclude)
	if _left <= 0.0 or not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = to

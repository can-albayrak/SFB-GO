class_name Tracer
extends MeshInstance3D
## Cosmetic bullet streak: a short glowing bar that flies from the muzzle to the hit point.

const SPEED: float = 280.0 ## m/s; fast enough to read as hitscan, slow enough to see.
const LENGTH: float = 1.6
const WIDTH: float = 0.018

static var _mesh: BoxMesh

var _dir: Vector3 = Vector3.ZERO
var _remaining: float = 0.0


static func create(from: Vector3, to: Vector3) -> Tracer:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(WIDTH, WIDTH, LENGTH)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(1.0, 0.78, 0.35, 0.85)
		_mesh.material = material
	var tracer := Tracer.new()
	tracer.mesh = _mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var distance: float = from.distance_to(to)
	tracer._dir = (to - from) / maxf(distance, 0.001)
	# The streak's tail starts at the muzzle; it stops when its head reaches the target.
	tracer._remaining = maxf(distance - LENGTH, 0.0)
	tracer.position = from + tracer._dir * LENGTH * 0.5
	if tracer._dir.cross(Vector3.UP).length_squared() > 0.0001:
		tracer.basis = Basis.looking_at(tracer._dir, Vector3.UP)
	else:
		tracer.basis = Basis.looking_at(tracer._dir, Vector3.FORWARD)
	return tracer


func _process(delta: float) -> void:
	var step: float = SPEED * delta
	if step >= _remaining:
		queue_free()
		return
	_remaining -= step
	position += _dir * step

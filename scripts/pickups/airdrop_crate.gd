class_name AirdropCrate
extends Node3D
## A falling airdrop crate (visual only; the AirdropManager owns the rules). It hangs under a
## parachute and drifts down onto its point over `fall_time`, with a light beam marking the
## spot from far away until it is opened. Every peer runs the same descent from its own clock.

const FALL_HEIGHT: float = 40.0
const CRATE_SIZE: Vector3 = Vector3(1.0, 0.75, 1.0)
const CRATE_COLOR: Color = Color(0.3, 0.32, 0.24)
const STRIPE_COLOR: Color = Color(0.85, 0.75, 0.25)
const CANOPY_RADIUS: float = 1.6
const CANOPY_HEIGHT: float = 2.8
const CANOPY_COLOR: Color = Color(0.75, 0.75, 0.72)
const BEAM_HEIGHT: float = 80.0
const BEAM_RADIUS: float = 0.35
const BEAM_COLOR: Color = Color(0.95, 0.35, 0.25, 0.22)
const LIGHT_COLOR: Color = Color(1.0, 0.4, 0.3)
const WORLD_LAYER: int = 1 ## Landed crates are solid like the map: players stand on it, shots stop.

var crate_id: int = 0
var landing_point: Vector3 = Vector3.ZERO
var fall_time: float = 10.0
var _fall_left: float = 0.0
var _body: Node3D
var _canopy: Node3D
var _solid: StaticBody3D


static func create(id: int, point: Vector3, seconds_left: float, total_fall: float) -> AirdropCrate:
	var crate := AirdropCrate.new()
	crate.crate_id = id
	crate.name = "Crate%d" % id
	crate.landing_point = point
	crate.fall_time = maxf(total_fall, 0.01)
	crate._fall_left = clampf(seconds_left, 0.0, crate.fall_time)
	return crate


func is_landed() -> bool:
	return _fall_left <= 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_position = landing_point
	_body = Node3D.new()
	add_child(_body)
	_body.add_child(_box(CRATE_SIZE, CRATE_COLOR, Vector3(0.0, CRATE_SIZE.y * 0.5, 0.0)))
	for x: float in [-0.3, 0.3]:
		_body.add_child(_box(Vector3(0.12, CRATE_SIZE.y + 0.02, CRATE_SIZE.z + 0.02), STRIPE_COLOR, Vector3(x, CRATE_SIZE.y * 0.5, 0.0)))
	_canopy = _cone()
	_canopy.position.y = CANOPY_HEIGHT
	_body.add_child(_canopy)
	var light := OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position.y = 1.2
	_body.add_child(light)
	add_child(_beam())
	_solid = StaticBody3D.new()
	_solid.collision_layer = WORLD_LAYER
	_solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = CRATE_SIZE
	shape.shape = box
	shape.position.y = CRATE_SIZE.y * 0.5
	_solid.add_child(shape)
	add_child(_solid)
	_update_fall()


func _process(delta: float) -> void:
	if _fall_left > 0.0:
		_fall_left = maxf(_fall_left - delta, 0.0)
		_update_fall()


func _update_fall() -> void:
	var share: float = _fall_left / fall_time
	_body.position.y = FALL_HEIGHT * share
	_body.rotation.y = share * 2.0 # A slow turn on the way down.
	_canopy.visible = _fall_left > 0.0
	_solid.process_mode = Node.PROCESS_MODE_INHERIT if _fall_left <= 0.0 else Node.PROCESS_MODE_DISABLED


func _box(box_size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance


func _cone() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = CANOPY_RADIUS
	mesh.height = 0.9
	mesh.radial_segments = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = CANOPY_COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## A tall glowing column over the landing point, seen across the map.
func _beam() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEAM_RADIUS
	mesh.bottom_radius = BEAM_RADIUS
	mesh.height = BEAM_HEIGHT
	mesh.radial_segments = 10
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = BEAM_COLOR
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = BEAM_HEIGHT * 0.5
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

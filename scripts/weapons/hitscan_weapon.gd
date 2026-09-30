class_name HitscanWeapon
extends Weapon
## Instant ray from the eye along the aim. Draws a tracer and an impact mark.

const HIT_MASK: int = 1 | 4 # world | hitbox
const TRACER_TIME: float = 0.05
const TRACER_COLOR: Color = Color(1.0, 0.85, 0.4)
const IMPACT_RADIUS: float = 0.025
const IMPACT_LIFETIME: float = 8.0

static var _tracer_material: StandardMaterial3D
static var _impact_mesh: SphereMesh


func _fire() -> void:
	var origin: Vector3 = player.get_aim_origin()
	var dir: Vector3 = -player.get_aim_basis().z
	var end_point: Vector3 = origin + dir * def.max_range

	var query := PhysicsRayQueryParameters3D.create(origin, end_point, HIT_MASK, player.get_hit_exclusions())
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		end_point = hit["position"]
		var collider: Object = hit["collider"]
		if collider is Hitbox:
			_apply_hit(collider as Hitbox)
		else:
			_spawn_impact(end_point)
	_spawn_tracer(muzzle.global_position, end_point)


# Stage 1: resolved locally. Stage 2 moves this to the host behind request_fire().
func _apply_hit(hitbox: Hitbox) -> void:
	var receiver: Node = hitbox.get_receiver()
	if receiver == null or not receiver.has_method(&"take_hit"):
		return
	var amount: float = def.damage * def.zone_multiplier(hitbox.zone)
	var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, player.get_multiplayer_authority())
	Events.hit_confirmed.emit(hitbox.zone, killed)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
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
	player.get_parent().add_child(instance)
	get_tree().create_timer(TRACER_TIME).timeout.connect(instance.queue_free)


func _spawn_impact(point: Vector3) -> void:
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
	player.get_parent().add_child(instance)
	instance.global_position = point
	get_tree().create_timer(IMPACT_LIFETIME).timeout.connect(instance.queue_free)

class_name SwapDart
extends Node3D
## Host only: the Trickster's dart in flight. Each tick it sweeps a sphere of `radius` along its
## path against player hitboxes (a wall stops it first). On a hit the thrower and the target
## swap places (Player.server_teleport). Others see a cosmetic copy (PlayerEffects._show_dart).

const WORLD_MASK: int = 1
const HITBOX_MASK: int = 4
const SWEEP_SAMPLES: int = 4

var _thrower: Player
var _velocity: Vector3
var _left: float = 0.0
var _radius: float = 0.3


func setup(thrower: Player, start: Vector3, velocity: Vector3, max_range: float, radius: float) -> void:
	_thrower = thrower
	_velocity = velocity
	_left = max_range / maxf(velocity.length(), 0.1)
	_radius = maxf(radius, 0.05)
	position = start


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(_thrower) or not _thrower.is_alive:
		queue_free()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + _velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var exclude: Array[RID] = _thrower.get_hit_exclusions()
	var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude))
	var limit: float = from.distance_to(wall["position"]) / maxf(from.distance_to(to), 0.0001) if not wall.is_empty() else 1.0
	var target: Player = _sweep(space, from, to, limit, exclude)
	if target != null:
		_swap(target)
		queue_free()
	elif not wall.is_empty():
		queue_free()
	else:
		global_position = to


func _sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, limit: float, exclude: Array[RID]) -> Player:
	var sphere := SphereShape3D.new()
	sphere.radius = _radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = HITBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = exclude
	for i: int in range(1, SWEEP_SAMPLES + 1):
		var share: float = float(i) / SWEEP_SAMPLES
		if share > limit:
			break
		params.transform = Transform3D(Basis.IDENTITY, from.lerp(to, share))
		for result: Dictionary in space.intersect_shape(params, 4):
			var hitbox := result["collider"] as Hitbox
			if hitbox == null:
				continue
			var target := hitbox.get_receiver() as Player
			if target != null and target != _thrower and target.is_alive:
				return target
	return null


func _swap(target: Player) -> void:
	var here: Vector3 = _thrower.global_position
	var there: Vector3 = target.global_position
	_thrower.server_teleport(there)
	target.server_teleport(here)
	_thrower.confirm_hit.rpc_id(_thrower.get_multiplayer_authority(), Hitbox.Zone.BODY, false, 0.0, there + Vector3.UP)

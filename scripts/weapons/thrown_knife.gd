class_name ThrownKnife
extends Node3D
## Thrown knife (Bear's secondary). The host simulates the flight each tick (a ray for walls,
## a sphere of def.projectile_radius along the path for players) and replicates
## position/rotation (Sync). A hit damages and removes it; a miss sticks it into
## the world where the thrower can pick it up by walking over it. Either way the knife is
## back in the thrower's inventory after def.return_time.

const WORLD_MASK: int = 1
const HITBOX_MASK: int = 4
const SWEEP_SAMPLES: int = 3 ## Sphere checks along each tick's path (radius 0.2 at 34 m/s: no gaps).
const PICKUP_RADIUS: float = 1.3
const PICKUP_CENTER_HEIGHT: float = 1.0
const STICK_DEPTH: float = 0.04 ## Metres the blade sinks into the surface.
const KILL_Y: float = -60.0

var def: WeaponDef
var thrower_id: int = 0

var _velocity: Vector3 = Vector3.ZERO
var _stuck: bool = false
var _return_left: float = 0.0


## Called on every peer by Game's spawn function, before the node enters the tree.
func setup(knife_def: WeaponDef, thrower: int, velocity: Vector3) -> void:
	def = knife_def
	thrower_id = thrower
	_velocity = velocity
	_return_left = def.return_time
	$Sync.set_multiplayer_authority(1)


func _ready() -> void:
	if not multiplayer.is_server():
		set_physics_process(false)
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		return
	_face(_velocity)


func _physics_process(delta: float) -> void:
	_return_left -= delta
	if _return_left <= 0.0 or global_position.y < KILL_Y:
		_give_back()
		queue_free()
		return
	if _stuck:
		_check_pickup()
		return
	_velocity.y -= def.throw_gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, _get_thrower_exclusions()))
	var wall_share: float = from.distance_to(wall["position"]) / maxf(from.distance_to(to), 0.0001) if not wall.is_empty() else INF
	var body: Array = _sweep_hitboxes(space, from, to, wall_share)
	if not body.is_empty():
		_hit_player(body[0] as Hitbox, body[1])
	elif not wall.is_empty():
		_stick(wall["position"], wall["collider"])
	else:
		global_position = to
		_face(_velocity)


## [hitbox, point] of the first player hitbox within def.projectile_radius of the path before
## `limit` (share of the path where a wall stops it), or [] for none.
func _sweep_hitboxes(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, limit: float) -> Array:
	if def.projectile_radius <= 0.0:
		var query := PhysicsRayQueryParameters3D.create(from, to, HITBOX_MASK, _get_thrower_exclusions())
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or from.distance_to(hit["position"]) / maxf(from.distance_to(to), 0.0001) > limit:
			return []
		return [hit["collider"], hit["position"]]
	var sphere := SphereShape3D.new()
	sphere.radius = def.projectile_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = HITBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = _get_thrower_exclusions()
	for i: int in range(1, SWEEP_SAMPLES + 1):
		var share: float = float(i) / SWEEP_SAMPLES
		if share > limit:
			break
		var point: Vector3 = from.lerp(to, share)
		params.transform = Transform3D(Basis.IDENTITY, point)
		for result: Dictionary in space.intersect_shape(params, 4):
			if result["collider"] is Hitbox:
				return [result["collider"], point]
	return []


func _hit_player(hitbox: Hitbox, point: Vector3) -> void:
	var receiver: Node = hitbox.get_receiver()
	if receiver != null and receiver.has_method(&"take_hit") \
			and not (receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage")):
		var amount: float = def.damage * def.zone_multiplier(hitbox.zone)
		var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, thrower_id, def.display_name, def.counts_as_knife)
		var dealt: float = receiver.get(&"last_damage_dealt")
		var thrower: Player = _get_thrower()
		if thrower != null and (dealt > 0.0 or killed):
			thrower.confirm_hit.rpc_id(thrower_id, hitbox.zone, killed, dealt, point)
	# The knife is gone; it still returns when its timer would have run out.
	var game: Game = Game.find(get_tree())
	if game != null:
		get_tree().create_timer(maxf(_return_left, 0.0)).timeout.connect(game.server_return_knife.bind(thrower_id))
	queue_free()


func _stick(point: Vector3, _collider: Object) -> void:
	_stuck = true
	var dir: Vector3 = _velocity.normalized()
	global_position = point + dir * STICK_DEPTH
	_face(dir)


func _check_pickup() -> void:
	var thrower: Player = _get_thrower()
	if thrower == null or not thrower.is_alive:
		return
	var center: Vector3 = thrower.global_position + Vector3.UP * PICKUP_CENTER_HEIGHT
	if center.distance_to(global_position) <= PICKUP_RADIUS:
		thrower.status.server_return_throwable()
		queue_free()


func _give_back() -> void:
	var thrower: Player = _get_thrower()
	if thrower != null:
		thrower.status.server_return_throwable()


func _face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	global_basis = Basis.looking_at(dir, up)


func _get_thrower() -> Player:
	var game: Game = Game.find(get_tree())
	if game == null:
		return null
	return game.players_root.get_node_or_null(str(thrower_id)) as Player


func _get_thrower_exclusions() -> Array[RID]:
	var thrower: Player = _get_thrower()
	if thrower == null:
		return []
	return thrower.get_hit_exclusions()

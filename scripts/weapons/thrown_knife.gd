class_name ThrownKnife
extends Node3D
## Thrown knife (Bear's secondary). The host simulates the arc with a ray per tick and
## replicates position/rotation (Sync). A hit damages and removes it; a miss sticks it into
## the world where the thrower can pick it up by walking over it. Either way the knife is
## back in the thrower's inventory after def.return_time.

const HIT_MASK: int = 1 | 4 # world | hitbox
const GRAVITY: float = 14.0
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
	_velocity.y -= GRAVITY * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, _get_thrower_exclusions())
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_face(_velocity)
		return
	if hit["collider"] is Hitbox:
		_hit_player(hit["collider"] as Hitbox, hit["position"])
	else:
		_stick(hit["position"], hit["collider"])


func _hit_player(hitbox: Hitbox, point: Vector3) -> void:
	var receiver: Node = hitbox.get_receiver()
	if receiver != null and receiver.has_method(&"take_hit") \
			and not (receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage")):
		var amount: float = def.damage * def.zone_multiplier(hitbox.zone)
		var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, thrower_id, def.display_name, false)
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
		thrower.server_return_throwable()
		queue_free()


func _give_back() -> void:
	var thrower: Player = _get_thrower()
	if thrower != null:
		thrower.server_return_throwable()


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

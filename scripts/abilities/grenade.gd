class_name Grenade
extends RigidBody3D
## Host-simulated explosive (Frag Grenade, Flashbang, Grenade Launcher round, Sticky Bomb,
## Landmine). The host simulates physics and detonates it; clients freeze their copy and
## follow the replicated transform (Sync), then Game broadcasts the explosion effect.
## GrenadeDef's behaviour flags pick what happens on contact; the defaults are a plain
## fused grenade that skids to a stop.

const SPIN: float = 8.0
const GROUND_DRAG: float = 5.0 ## Per-second velocity loss while touching something, so it does not skate.
const SETTLE_SPEED: float = 0.4 ## Mine: frozen in place once it rests slower than this...
const GROUND_PROBE: float = 0.25 ## ... on ground found this far below its centre (not on a wall).
const WORLD_MASK: int = 1

var def: GrenadeDef
var thrower_id: int = 0

var _fuse_left: float = 0.0
var _age: float = 0.0
var _stuck: bool = false
var _stuck_player: Player = null
var _stuck_local: Vector3 = Vector3.ZERO


## Called on every peer by Game's spawn function, before the node enters the tree.
func setup(grenade_def: GrenadeDef, thrower: int, velocity: Vector3) -> void:
	def = grenade_def
	thrower_id = thrower
	linear_velocity = velocity
	if def.trigger_radius <= 0.0: # Mines fly flat so they land the right way up.
		angular_velocity = Vector3(randf_range(-SPIN, SPIN), randf_range(-SPIN, SPIN), randf_range(-SPIN, SPIN))
	_fuse_left = def.fuse_time
	$Sync.set_multiplayer_authority(1)


func _ready() -> void:
	if not multiplayer.is_server():
		freeze = true
		collision_layer = 0
		collision_mask = 0
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		return
	# Rounds that can touch players must never touch the one who fired them.
	var thrower: Player = _get_thrower()
	if thrower != null:
		add_collision_exception_with(thrower)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_age += delta
	if _stuck:
		_follow_anchor()
	elif get_contact_count() > 0:
		if def.explode_on_impact:
			_explode()
			return
		if def.sticky:
			_stick()
		elif def.trigger_radius > 0.0 and linear_velocity.length() < SETTLE_SPEED and _has_ground_below():
			_stuck = true # A mine stays where it came to rest.
			freeze = true
		else:
			linear_velocity *= maxf(1.0 - GROUND_DRAG * delta, 0.0)

	if def.trigger_radius > 0.0 and _age >= def.arm_time and _enemy_on_top():
		_explode()
		return
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		if def.explode_on_fuse:
			_explode()
		else:
			set_physics_process(false)
			queue_free()


func _explode() -> void:
	set_physics_process(false)
	var game: Game = Game.find(get_tree())
	if game != null:
		game.server_explode(def, thrower_id, global_position)
	queue_free()


## Sticky Bomb: stop dead; on a player, ride along with them until they die.
func _stick() -> void:
	_stuck = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	for body: Node3D in get_colliding_bodies():
		if body is Player:
			_stuck_player = body as Player
			_stuck_local = _stuck_player.to_local(global_position)
			return


func _follow_anchor() -> void:
	if not is_instance_valid(_stuck_player) or not _stuck_player.is_alive:
		_stuck_player = null # Stays where the victim fell.
		return
	global_position = _stuck_player.to_global(_stuck_local)


## Mine: is a living enemy (not the one who placed it) standing on or right next to it?
func _enemy_on_top() -> bool:
	var game: Game = Game.find(get_tree())
	if game == null:
		return false
	for node: Node in game.players_root.get_children():
		var target := node as Player
		if target == null or target.get_multiplayer_authority() == thrower_id or not target.can_take_damage():
			continue
		var offset: Vector3 = target.global_position - global_position
		if offset.y < -def.trigger_depth or offset.y > def.trigger_height:
			continue
		if Vector2(offset.x, offset.z).length() <= def.trigger_radius:
			return true
	return false


func _has_ground_below() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * GROUND_PROBE, WORLD_MASK)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _get_thrower() -> Player:
	var game: Game = Game.find(get_tree())
	if game == null:
		return null
	return game.players_root.get_node_or_null(str(thrower_id)) as Player

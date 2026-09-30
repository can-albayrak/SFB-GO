class_name Grenade
extends RigidBody3D
## Thrown grenade. The host simulates physics and detonates it; clients freeze their copy
## and follow the replicated transform (Sync), then Game broadcasts the explosion effect.

const SPIN: float = 8.0
const GROUND_DRAG: float = 5.0 ## Per-second velocity loss while touching something, so it does not skate.

var def: GrenadeDef
var thrower_id: int = 0

var _fuse_left: float = 0.0


## Called on every peer by Game's spawn function, before the node enters the tree.
func setup(grenade_def: GrenadeDef, thrower: int, velocity: Vector3) -> void:
	def = grenade_def
	thrower_id = thrower
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-SPIN, SPIN), randf_range(-SPIN, SPIN), randf_range(-SPIN, SPIN))
	_fuse_left = def.fuse_time
	$Sync.set_multiplayer_authority(1)


func _ready() -> void:
	if not multiplayer.is_server():
		freeze = true
		collision_layer = 0
		collision_mask = 0
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if get_contact_count() > 0:
		linear_velocity *= maxf(1.0 - GROUND_DRAG * delta, 0.0)
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		set_physics_process(false)
		var game: Game = Game.find(get_tree())
		if game != null:
			game.server_explode(def, thrower_id, global_position)
		queue_free()

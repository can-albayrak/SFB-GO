class_name ThrowingKnifeWeapon
extends Weapon
## Bear's secondary: a few throwing knives. Ammo is the knives in hand; there is no reload,
## thrown knives come back by pickup or timer (see ThrownKnife). Host spawns the projectile.

const HAND_OFFSET: float = 0.5 ## Metres in front of the eye where the knife appears.
const WALL_MARGIN: float = 0.1
const WORLD_MASK: int = 1


## Owner: the host spawns the knife, so the request is all there is to do.
func _fire() -> void:
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var game: Game = Game.find(get_tree())
	if game == null:
		return origin
	# Never spawn on the far side of a thin wall the thrower is hugging.
	var spawn: Vector3 = origin + dir * HAND_OFFSET
	var query := PhysicsRayQueryParameters3D.create(origin, spawn, WORLD_MASK)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn = (hit["position"] as Vector3) - dir * WALL_MARGIN
	game.server_spawn_knife(def, player.get_multiplayer_authority(), spawn, dir * def.throw_speed + Vector3.UP * def.throw_lift)
	return spawn


## No reloading: knives return on their own.
func _start_reload() -> void:
	pass

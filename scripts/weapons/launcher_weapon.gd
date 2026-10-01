class_name LauncherWeapon
extends Weapon
## Volcano's Grenade Launcher: fires WeaponDef.grenade as a host-simulated physical round
## (same Grenade / Game.server_explode path as Wolf's frag). It arcs, bursts on impact and
## its blast also hurts the shooter.

const HAND_OFFSET: float = 0.5 ## Metres in front of the eye where the round appears.
const WALL_MARGIN: float = 0.1
const WORLD_MASK: int = 1


## Owner: muzzle flash now; the host spawns the round.
func _fire() -> void:
	ShotEffects.spawn_muzzle_flash(muzzle)
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var game: Game = Game.find(get_tree())
	if game == null or def.grenade == null:
		return origin
	# Never spawn on the far side of a thin wall the shooter is hugging.
	var spawn: Vector3 = origin + dir * HAND_OFFSET
	var query := PhysicsRayQueryParameters3D.create(origin, spawn, WORLD_MASK)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn = (hit["position"] as Vector3) - dir * WALL_MARGIN
	var velocity: Vector3 = dir * def.grenade.throw_speed + Vector3.UP * def.grenade.throw_lift
	game.server_spawn_grenade(def.grenade, player.get_multiplayer_authority(), spawn, velocity)
	return spawn

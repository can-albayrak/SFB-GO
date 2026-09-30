class_name GrenadeAbility
extends Ability
## Throws the GrenadeDef's projectile (Frag Grenade, Flashbang). Host spawns and simulates it.

const HAND_OFFSET: float = 0.5 ## Metres in front of the eye where the grenade appears.
const WALL_MARGIN: float = 0.1 ## Pulled back this far from a wall between eye and hand.
const WORLD_MASK: int = 1


func server_use(origin: Vector3, dir: Vector3) -> void:
	var grenade_def: GrenadeDef = def
	var game: Game = Game.find(player.get_tree())
	if game == null:
		return
	# Never spawn on the far side of a thin wall the thrower is hugging.
	var spawn: Vector3 = origin + dir * HAND_OFFSET
	var query := PhysicsRayQueryParameters3D.create(origin, spawn, WORLD_MASK)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn = (hit["position"] as Vector3) - dir * WALL_MARGIN
	var velocity: Vector3 = dir * grenade_def.throw_speed + Vector3.UP * grenade_def.throw_lift
	game.server_spawn_grenade(grenade_def, player.get_multiplayer_authority(), spawn, velocity)

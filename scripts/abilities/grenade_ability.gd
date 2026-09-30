class_name GrenadeAbility
extends Ability
## Throws the GrenadeDef's projectile (Frag Grenade, Flashbang). Host spawns and simulates it.

const HAND_OFFSET: float = 0.5 ## Metres in front of the eye where the grenade appears.


func server_use(origin: Vector3, dir: Vector3) -> void:
	var grenade_def: GrenadeDef = def
	var game: Game = Game.find(player.get_tree())
	if game == null:
		return
	var velocity: Vector3 = dir * grenade_def.throw_speed + Vector3.UP * grenade_def.throw_lift
	game.server_spawn_grenade(grenade_def, player.get_multiplayer_authority(), origin + dir * HAND_OFFSET, velocity)

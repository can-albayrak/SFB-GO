class_name GrenadeAbility
extends Ability
## Throws the GrenadeDef's projectile (Frag Grenade, Flashbang, Sticky Bomb, Landmine).
## Host spawns and simulates it; Player.get_throw_launch picks the hand, aim and carried speed.


func server_use(origin: Vector3, dir: Vector3) -> void:
	_server_throw(origin, dir)


## Owner: the last accepted use threw something (others see the throw animation).
func threw_last() -> bool:
	return true


func _server_throw(origin: Vector3, dir: Vector3) -> Grenade:
	var grenade_def: GrenadeDef = def
	var game: Game = Game.find(player.get_tree())
	if game == null:
		return null
	var launch: Array = player.get_throw_launch(origin, dir, grenade_def.throw_speed, grenade_def.throw_lift)
	return game.server_spawn_grenade(grenade_def, player.get_multiplayer_authority(), launch[0], launch[1])

class_name GrenadeAbility
extends Ability
## Throws the GrenadeDef's projectile (Frag Grenade, Flashbang, Sticky Bomb, Landmine).
## Host spawns and simulates it; Player.get_throw_launch picks the hand, aim and carried speed.


func server_use(origin: Vector3, dir: Vector3) -> void:
	var grenade_def: GrenadeDef = def
	var game: Game = Game.find(player.get_tree())
	if game == null:
		return
	var launch: Array = player.get_throw_launch(origin, dir, grenade_def.throw_speed, grenade_def.throw_lift)
	game.server_spawn_grenade(grenade_def, player.get_multiplayer_authority(), launch[0], launch[1])

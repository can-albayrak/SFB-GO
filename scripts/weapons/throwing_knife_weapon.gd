class_name ThrowingKnifeWeapon
extends Weapon
## Bear's secondary: a few throwing knives. Ammo is the knives in hand; there is no reload,
## thrown knives come back by pickup or timer (see ThrownKnife). Host spawns the projectile.


## Owner: the host spawns the knife, so the request is all there is to do.
func _fire() -> void:
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var game: Game = Game.find(get_tree())
	if game == null:
		return origin
	var launch: Array = player.get_throw_launch(origin, dir, def.throw_speed, def.throw_lift)
	game.server_spawn_knife(def, player.get_multiplayer_authority(), launch[0], launch[1])
	return launch[0]


## No reloading: knives return on their own.
func _start_reload() -> void:
	pass

class_name ShieldAbility
extends Ability
## Bear Shield: for def.duration seconds hits from the front are blocked (host-side in Player).


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	player.status.server_activate_shield(def.duration)

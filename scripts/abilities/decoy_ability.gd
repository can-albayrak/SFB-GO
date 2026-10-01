class_name DecoyAbility
extends Ability
## Hawk Decoy: leaves a hologram of the player where they stand for def.duration seconds.


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	player.effects.show_decoy(def.duration)

class_name AdrenalineAbility
extends Ability
## Cheetah Adrenaline: def.duration seconds of extra movement speed and fire rate.
## The owner applies it to its handling; the host mirrors it for its speed and fire checks.


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	player.status.start_buff_local(def.duration, def.speed_mult, def.fire_rate_mult)


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	player.status.server_start_buff(def.duration, def.speed_mult, def.fire_rate_mult)

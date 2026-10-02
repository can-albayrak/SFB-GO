class_name AdrenalineAbility
extends Ability
## Timed self-boost for def.duration seconds: Cheetah's Adrenaline (speed + fire rate) and
## Cowboy's Smoke Break (fire rate + reload speed + health over time). The owner applies it
## to its handling; the host mirrors it for its speed and fire checks and owns the healing.


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	player.status.start_buff_local(def.duration, def.speed_mult, def.fire_rate_mult, def.reload_speed_mult)


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	player.status.server_start_buff(def.duration, def.speed_mult, def.fire_rate_mult, def.heal_per_second)

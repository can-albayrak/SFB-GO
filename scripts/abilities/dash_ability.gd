class_name DashAbility
extends Ability
## Cheetah Dash: an instant short burst in the held movement direction (the look direction
## when no key is held), also in the air. Movement is owner-authoritative like all movement;
## the host only validates the cooldown (the burst fits its movement budget).


func _use_local(_origin: Vector3, dir: Vector3) -> void:
	var wish: Vector3 = player.movement.last_wish_dir
	player.movement.start_dash(wish if wish != Vector3.ZERO else dir, def.speed, def.duration, def.exit_speed)

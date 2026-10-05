class_name SwapDartAbility
extends Ability
## Trickster Swap Dart: blows a fast dart; the first player it touches swaps places with the
## Trickster at once. The host flies the dart (SwapDart) and moves both players; every peer
## draws a cosmetic dart along the same line. A miss still costs the cooldown.


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	Sfx.play_ui(player, Sfx.DART)


func server_use(origin: Vector3, dir: Vector3) -> void:
	var start: Vector3 = origin + dir * 0.4
	var dart := SwapDart.new()
	dart.setup(player, start, dir * def.speed, def.max_range, def.projectile_radius)
	player.get_parent().add_child(dart)
	player.effects.server_show_dart(start, dir * def.speed, def.max_range / maxf(def.speed, 0.1))

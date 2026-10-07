class_name SonarAbility
extends Ability
## Hound Sonar: everyone within def.max_range of the Hound shows through walls on the Hound's
## screen for def.duration seconds. Each of them hears a ping, so they know and can move.
## The host picks the targets (positions are the host's); only the owner sees them.


var dummies_found: int = 0 ## Test Range dummies the last use marked (owner; HUD count).


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	Sfx.play_ui(player, Sfx.SONAR)
	dummies_found = 0
	# Test Range dummies never move or fight back, so the owner marks them itself (visual).
	for node: Node in get_tree().get_nodes_in_group(TargetDummy.GROUP):
		var dummy := node as TargetDummy
		if dummy.global_position.distance_to(player.global_position) <= def.max_range:
			dummy.reveal(PlayerEffects.get_sonar_material(), def.duration)
			dummies_found += 1


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	var found: PackedInt32Array = PackedInt32Array()
	for node: Node in player.get_parent().get_children():
		var other := node as Player
		if other == null or other == player or not other.is_alive:
			continue
		if other.global_position.distance_to(player.global_position) > def.max_range:
			continue
		found.append(other.get_multiplayer_authority())
		other.effects.server_sonar_ping(player.global_position)
	player.effects.server_show_sonar(found, def.duration)

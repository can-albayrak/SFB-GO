class_name RailgunWeapon
extends HitscanWeapon
## Airdrop Railgun (GDD): a beam with unlimited range that goes through every wall and every
## player on its line. Each player it crosses takes one hit (the first zone the beam meets).

const HITBOX_MASK: int = 4
const MAX_PIERCED: int = 16


func _fire() -> void:
	var origin: Vector3 = player.get_aim_origin()
	var dir: Vector3 = _apply_spread(-player.get_aim_basis().z)
	ShotEffects.spawn_muzzle_flash(muzzle)
	Sfx.shot(player.get_parent(), def, muzzle.global_position)
	ShotEffects.spawn_beam(player.get_parent(), muzzle.global_position, origin + dir * def.max_range)
	player.send_fire(origin, dir, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var exclude: Array[RID] = player.get_hit_exclusions()
	var hit_receivers: Array[Node] = []
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for i: int in MAX_PIERCED:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * def.max_range, HITBOX_MASK, exclude)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		var hitbox := hit["collider"] as Hitbox
		if hitbox == null:
			break
		exclude.append(hitbox.get_rid())
		var receiver: Node = hitbox.get_receiver()
		if receiver == null or receiver in hit_receivers:
			continue
		hit_receivers.append(receiver)
		_apply_hit(hitbox, hit["position"])
	return origin + dir * def.max_range

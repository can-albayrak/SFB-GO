class_name HitscanWeapon
extends Weapon
## Instant ray from the eye along the aim.
## Owner: draws the tracer from its own trace and asks the host to fire.
## Host: traces again and applies damage (no lag compensation until stage 3).

const HIT_MASK: int = 1 | 4 # world | hitbox


func _fire() -> void:
	var origin: Vector3 = player.get_aim_origin()
	var dir: Vector3 = _apply_spread(-player.get_aim_basis().z)
	var hit: Dictionary = _trace(origin, dir)
	var end_point: Vector3 = hit["position"] if not hit.is_empty() else origin + dir * def.max_range
	if not hit.is_empty() and not (hit["collider"] is Hitbox):
		ShotEffects.spawn_impact(player.get_parent(), end_point)
	ShotEffects.spawn_muzzle_flash(muzzle)
	ShotEffects.spawn_tracer(player.get_parent(), muzzle.global_position, end_point)
	player.send_fire(origin, dir, player.weapons.find(self))


## Scoped weapons fired from the hip scatter inside a cone (Hawk balance rule).
func _apply_spread(dir: Vector3) -> Vector3:
	if def.unscoped_spread <= 0.0 or player.is_scoped:
		return dir
	var angle: float = deg_to_rad(def.unscoped_spread) * sqrt(randf())
	var around: float = randf() * TAU
	var local := Vector3(sin(angle) * cos(around), sin(angle) * sin(around), -cos(angle))
	return (Basis.looking_at(dir) * local).normalized()


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var hit: Dictionary = _trace(origin, dir)
	if hit.is_empty():
		return origin + dir * def.max_range
	var collider: Object = hit["collider"]
	if collider is Hitbox:
		_apply_hit(collider as Hitbox)
	return hit["position"]


func _trace(origin: Vector3, dir: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * def.max_range, HIT_MASK, player.get_hit_exclusions())
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _apply_hit(hitbox: Hitbox) -> void:
	var receiver: Node = hitbox.get_receiver()
	if receiver == null or not receiver.has_method(&"take_hit"):
		return
	if receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage"):
		return # Protected / dead / between matches: no damage, so no hit marker.
	var amount: float = def.damage * def.zone_multiplier(hitbox.zone)
	var shooter_id: int = player.get_multiplayer_authority()
	var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, shooter_id, def.display_name)
	player.confirm_hit.rpc_id(shooter_id, hitbox.zone, killed)

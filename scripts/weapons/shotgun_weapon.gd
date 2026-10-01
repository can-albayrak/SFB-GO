class_name ShotgunWeapon
extends HitscanWeapon
## Volcano's Shotgun: one hitscan ray per WeaponDef.pellet_pattern entry around the aim.
## The pattern is fixed, so the owner (tracers) and the host (damage) trace the same rays
## from the same aim; only the aim direction travels over the network.
## Host: pellet damage falls off with distance and is summed per target, so each target
## gets one take_hit and the shooter one hit marker / damage number per target.

## Host: end points of the last server_fire's pellets (Player broadcasts them as tracers).
var last_pellet_ends: PackedVector3Array = PackedVector3Array()


func _fire() -> void:
	var origin: Vector3 = player.get_aim_origin()
	var dir: Vector3 = _apply_spread(-player.get_aim_basis().z)
	for offset: Vector2 in def.pellet_pattern:
		var pellet_dir: Vector3 = pellet_direction(dir, offset)
		var hit: Dictionary = _trace(origin, pellet_dir)
		var end_point: Vector3 = hit["position"] if not hit.is_empty() else origin + pellet_dir * def.max_range
		if not hit.is_empty() and not (hit["collider"] is Hitbox):
			ShotEffects.spawn_impact(player.get_parent(), end_point)
		ShotEffects.spawn_tracer(player.get_parent(), muzzle.global_position, end_point)
	ShotEffects.spawn_muzzle_flash(muzzle)
	player.send_fire(origin, dir, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	last_pellet_ends = PackedVector3Array()
	# Per target: [summed damage, best zone (HEAD < BODY < LEG), first hit point].
	var targets: Dictionary[Node, Array] = {}
	for offset: Vector2 in def.pellet_pattern:
		var pellet_dir: Vector3 = pellet_direction(dir, offset)
		var hit: Dictionary = _trace(origin, pellet_dir)
		if hit.is_empty():
			last_pellet_ends.append(origin + pellet_dir * def.max_range)
			continue
		var point: Vector3 = hit["position"]
		last_pellet_ends.append(point)
		var hitbox := hit["collider"] as Hitbox
		if hitbox == null:
			continue
		var receiver: Node = hitbox.get_receiver()
		if receiver == null or not receiver.has_method(&"take_hit"):
			continue
		var amount: float = def.damage * def.zone_multiplier(hitbox.zone) * def.get_falloff_mult(origin.distance_to(point))
		if not targets.has(receiver):
			targets[receiver] = [0.0, hitbox.zone, point]
		var entry: Array = targets[receiver]
		entry[0] = float(entry[0]) + amount
		if int(hitbox.zone) < int(entry[1]):
			entry[1] = hitbox.zone

	var shooter_id: int = player.get_multiplayer_authority()
	for receiver: Node in targets:
		if receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage"):
			continue # Protected / dead / between matches: no damage, so no hit marker.
		var entry: Array = targets[receiver]
		var total: float = entry[0]
		var zone: Hitbox.Zone = entry[1]
		var point: Vector3 = entry[2]
		var killed: bool = receiver.call(&"take_hit", total, zone, shooter_id, def.display_name)
		player.confirm_hit.rpc_id(shooter_id, zone, killed, total, point)
	return origin + dir * def.max_range


## The direction of a pellet offset by (right, up) degrees from `dir`. Same math on every peer.
static func pellet_direction(dir: Vector3, offset: Vector2) -> Vector3:
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	var aim := Basis.looking_at(dir, up)
	var local := Vector3(tan(deg_to_rad(offset.x)), tan(deg_to_rad(offset.y)), -1.0)
	return (aim * local).normalized()

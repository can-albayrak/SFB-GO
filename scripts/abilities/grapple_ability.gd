class_name GrappleAbility
extends Ability
## Hawk Grapple: pulls the owner toward the world point under the crosshair.
## Movement is owner-authoritative (like all movement); the host only validates the
## cooldown and shows the rope to everyone.

const WORLD_MASK: int = 1
const ANCHOR_OUT: float = 0.6 ## Metres the pull target sits off the surface, along its normal.
const ANCHOR_UP: float = 1.0 ## ... and above the anchor, so ledges can be climbed.
const BEAM_EXTRA_TIME: float = 0.3


## A miss costs nothing: no cooldown, no request to the host.
func try_use(origin: Vector3, dir: Vector3) -> bool:
	if cooldown_left > 0.0:
		return false
	var hit: Dictionary = _raycast(origin, dir)
	if hit.is_empty():
		return false
	cooldown_left = def.cooldown
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	player.movement.start_grapple(point + normal * ANCHOR_OUT + Vector3.UP * ANCHOR_UP, def.speed)
	return true


func server_use(origin: Vector3, dir: Vector3) -> void:
	var hit: Dictionary = _raycast(origin, dir)
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	player.show_grapple(point, origin.distance_to(point) / maxf(def.speed, 0.1) + BEAM_EXTRA_TIME)


func _raycast(origin: Vector3, dir: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * def.max_range, WORLD_MASK)
	return player.get_world_3d().direct_space_state.intersect_ray(query)

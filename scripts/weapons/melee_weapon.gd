class_name MeleeWeapon
extends Weapon
## Quick melee (V). Not an equipped slot: the owner swings it over the current weapon.
## def.fire_interval = cooldown, def.max_range = reach. Host resolves with a small fan of rays.

const SWING_TIME: float = 0.35 ## Owner cannot fire the current weapon during the swing.
const SWING_ANGLE: float = 70.0 ## Degrees the knife sweeps across the view.
## Offsets (metres at full reach) of the extra rays around the aim, for a forgiving hit.
const RAY_SPREAD: Array[Vector2] = [Vector2.ZERO, Vector2(0.2, 0.0), Vector2(-0.2, 0.0), Vector2(0.0, 0.15), Vector2(0.0, -0.2)]
const HIT_MASK: int = 1 | 4 # world | hitbox

var _swing_left: float = 0.0
var _rest_rotation: Vector3


func _ready() -> void:
	_rest_rotation = rotation_degrees
	visible = false


func is_swinging() -> bool:
	return _swing_left > 0.0


func is_ready() -> bool:
	return _cooldown <= 0.0


## Owner: cooldown + swing animation. Returns false when still on cooldown.
func swing() -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = def.fire_interval
	_swing_left = SWING_TIME
	visible = true
	rotation_degrees = _rest_rotation + Vector3(0.0, SWING_ANGLE * 0.5, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees", _rest_rotation + Vector3(-20.0, -SWING_ANGLE * 0.5, 0.0), SWING_TIME * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true


## Owner, every tick (cooldown and swing timers only; no firing through tick()).
func tick_melee(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _swing_left > 0.0:
		_swing_left -= delta
		if _swing_left <= 0.0:
			visible = false
			rotation_degrees = _rest_rotation


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var aim_basis: Basis = Basis.looking_at(dir, Vector3.UP) if absf(dir.y) < 0.99 else Basis.looking_at(dir, Vector3.FORWARD)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best_hitbox: Hitbox = null
	var best_distance: float = INF
	for offset: Vector2 in RAY_SPREAD:
		var end: Vector3 = origin + dir * def.max_range + aim_basis.x * offset.x + aim_basis.y * offset.y
		var query := PhysicsRayQueryParameters3D.create(origin, end, HIT_MASK, player.get_hit_exclusions())
		query.collide_with_areas = true
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not (hit["collider"] is Hitbox):
			continue
		var distance: float = origin.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best_hitbox = hit["collider"]
	if best_hitbox != null:
		_apply_melee_hit(best_hitbox)
	return origin + dir * def.max_range


func _apply_melee_hit(hitbox: Hitbox) -> void:
	var receiver: Node = hitbox.get_receiver()
	if receiver == null or not receiver.has_method(&"take_hit"):
		return
	if receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage"):
		return
	var amount: float = def.damage * def.zone_multiplier(hitbox.zone)
	var shooter_id: int = player.get_multiplayer_authority()
	var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, shooter_id, def.display_name, true)
	player.confirm_hit.rpc_id(shooter_id, hitbox.zone, killed)

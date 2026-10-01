class_name MeleeWeapon
extends Weapon
## Melee weapon. Two uses:
## - Quick melee (V): not an equipped slot, the owner swings it over the current weapon.
## - Primary (Bear's Sledgehammer / Claws / Chainsaw): equipped like a gun, fired through tick().
## def.fire_interval = cooldown, def.max_range = reach. Host resolves with a fan of rays.

const SWING_TIME: float = 0.35 ## Owner cannot fire the current weapon during the quick swing.
const SWING_ANGLE: float = 70.0 ## Degrees the quick melee sweeps across the view.
const PRIMARY_SWING_MAX_TIME: float = 0.25 ## Longest forward stroke of a primary's swing.
const PRIMARY_RETURN_TIME: float = 0.12
## Offsets (metres at full reach) of the extra rays around the aim, for a forgiving hit.
const RAY_SPREAD: Array[Vector2] = [Vector2.ZERO, Vector2(0.2, 0.0), Vector2(-0.2, 0.0), Vector2(0.0, 0.15), Vector2(0.0, -0.2)]
const HIT_MASK: int = 1 | 4 # world | hitbox
const KNOCKBACK_LIFT: float = 2.0 ## Upward share of a knockback push.

var _swing_left: float = 0.0
var _rest_rotation: Vector3
var _tween: Tween


func _ready() -> void:
	_rest_rotation = rotation_degrees
	visible = false


func is_swinging() -> bool:
	return _swing_left > 0.0


func is_ready() -> bool:
	return _cooldown <= 0.0


func holster() -> void:
	super.holster()
	_stop_tween()
	rotation_degrees = _rest_rotation


## Quick melee, owner: cooldown + swing animation. Returns false when still on cooldown.
func swing() -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = def.fire_interval
	_swing_left = SWING_TIME
	visible = true
	rotation_degrees = _rest_rotation + Vector3(0.0, SWING_ANGLE * 0.5, 0.0)
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees", _rest_rotation + Vector3(-20.0, -SWING_ANGLE * 0.5, 0.0), SWING_TIME * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true


## Quick melee, owner, every tick (cooldown and swing timers only).
func tick_melee(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _swing_left > 0.0:
		_swing_left -= delta
		if _swing_left <= 0.0:
			visible = false
			rotation_degrees = _rest_rotation


## Primary melee, owner: swing animation and the hit request (called by Weapon.tick).
func _fire() -> void:
	_play_primary_swing()
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func _play_primary_swing() -> void:
	if def.melee_swing_angle <= 0.0:
		return
	var half: float = def.melee_swing_angle * 0.5
	var stroke: float = minf(def.fire_interval * 0.5, PRIMARY_SWING_MAX_TIME)
	_stop_tween()
	rotation_degrees = _rest_rotation + Vector3(0.0, half, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees", _rest_rotation + Vector3(-20.0, -half, 0.0), stroke) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees", _rest_rotation, PRIMARY_RETURN_TIME)


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var aim_basis: Basis = Basis.looking_at(dir, Vector3.UP) if absf(dir.y) < 0.99 else Basis.looking_at(dir, Vector3.FORWARD)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best_hitbox: Hitbox = null
	var best_distance: float = INF
	var best_point: Vector3 = Vector3.ZERO
	for offset: Vector2 in RAY_SPREAD:
		var scaled: Vector2 = offset * def.melee_spread_scale
		var end: Vector3 = origin + dir * def.max_range + aim_basis.x * scaled.x + aim_basis.y * scaled.y
		var query := PhysicsRayQueryParameters3D.create(origin, end, HIT_MASK, player.get_hit_exclusions())
		query.collide_with_areas = true
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not (hit["collider"] is Hitbox):
			continue
		var distance: float = origin.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best_hitbox = hit["collider"]
			best_point = hit["position"]
	if best_hitbox != null:
		_apply_melee_hit(best_hitbox, dir, best_point)
	return origin + dir * def.max_range


func _apply_melee_hit(hitbox: Hitbox, dir: Vector3, point: Vector3) -> void:
	var receiver: Node = hitbox.get_receiver()
	if receiver == null or not receiver.has_method(&"take_hit"):
		return
	if receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage"):
		return
	var amount: float = def.damage * def.zone_multiplier(hitbox.zone)
	var shooter_id: int = player.get_multiplayer_authority()
	var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, shooter_id, def.display_name, true)
	player.confirm_hit.rpc_id(shooter_id, hitbox.zone, killed, amount, point)
	if def.knockback > 0.0 and not killed and receiver is Player:
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		(receiver as Player).server_knockback(flat * def.knockback + Vector3.UP * KNOCKBACK_LIFT)

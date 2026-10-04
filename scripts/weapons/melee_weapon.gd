class_name MeleeWeapon
extends Weapon
## Melee weapon. Two uses:
## - Quick melee (V): not an equipped slot, the owner swings it over the current weapon.
## - Equipped like a gun, fired through tick(): Bear's Sledgehammer / Claws / Chainsaw and every
##   class's knife in slot 3 (CS style; a hit from behind kills, WeaponDef.backstab_damage).
## def.fire_interval = cooldown, def.max_range = reach. Host resolves with a fan of rays.
## Held knife right click (def.heavy_damage > 0, CS:GO): a slower, heavier stab sent with
## Player.requests.send_stab; the host resolves it like a swing with the heavy damage.

const SWING_TIME: float = 0.35 ## Owner cannot fire the current weapon during the quick swing.
const PRIMARY_SWING_MAX_TIME: float = 0.45 ## Longest whole swing (wind-up, stroke, return) of a primary.
const PRIMARY_SWING_SHARE: float = 0.8 ## A primary's swing takes at most this share of its fire interval.
## View swing, keyed as offsets from the rest pose in the holder's space: position (metres) and
## rotation (degrees). The arms follow the hand (IK), so the whole arm moves. One-handed blades
## slash from the right down to the left; two-handed weapons chop from overhead.
## WeaponDef.melee_swing_angle scales it down (SWING_KEY_ANGLE or more = as keyed, 0 = no swing).
const SLASH_WINDUP_POS: Vector3 = Vector3(0.1, 0.07, 0.06)
const SLASH_WINDUP_ROT: Vector3 = Vector3(10.0, 40.0, -25.0)
const SLASH_END_POS: Vector3 = Vector3(-0.22, -0.07, -0.12)
const SLASH_END_ROT: Vector3 = Vector3(-15.0, -5.0, 30.0)
const CHOP_WINDUP_POS: Vector3 = Vector3(0.03, 0.14, 0.08)
const CHOP_WINDUP_ROT: Vector3 = Vector3(40.0, 10.0, 0.0)
const CHOP_END_POS: Vector3 = Vector3(-0.05, -0.14, -0.08)
const CHOP_END_ROT: Vector3 = Vector3(-60.0, -15.0, 10.0)
const SWING_KEY_ANGLE: float = 70.0
## Heavy stab: pulled back, then driven straight ahead.
const STAB_WINDUP_POS: Vector3 = Vector3(0.04, 0.04, 0.1)
const STAB_WINDUP_ROT: Vector3 = Vector3(25.0, 10.0, 0.0)
const STAB_END_POS: Vector3 = Vector3(-0.1, 0.02, -0.28)
const STAB_END_ROT: Vector3 = Vector3(-30.0, -15.0, 0.0)
const HEAVY_SWING_TIME: float = 0.6
const WINDUP_END: float = 0.2 ## Share of the swing spent winding up...
const STROKE_END: float = 0.5 ## ...and where the stroke ends; the rest goes back to rest.
## Offsets (metres at full reach) of the extra rays around the aim, for a forgiving hit.
const RAY_SPREAD: Array[Vector2] = [Vector2.ZERO, Vector2(0.2, 0.0), Vector2(-0.2, 0.0), Vector2(0.0, 0.15), Vector2(0.0, -0.2)]
const HIT_MASK: int = 1 | 4 # world | hitbox
const KNOCKBACK_LIFT: float = 2.0 ## Upward share of a knockback push.

var _swing_left: float = 0.0
var _rest: Transform3D
var _tween: Tween
var _stab_pose: bool = false ## The playing swing is the heavy stab.
## Host: the hit being resolved is a heavy stab (set around server_fire by the request).
var server_heavy: bool = false


func _ready() -> void:
	_rest = transform
	visible = false


func is_swinging() -> bool:
	return _swing_left > 0.0


func is_ready() -> bool:
	return _cooldown <= 0.0


func holster() -> void:
	super.holster()
	_stop_tween()
	transform = _rest


## Quick melee, owner: cooldown + swing animation. Returns false when still on cooldown.
func swing() -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = def.fire_interval
	_swing_left = SWING_TIME
	visible = true
	_play_swing(SWING_TIME)
	return true


## Quick melee, owner, every tick (cooldown and swing timers only).
func tick_melee(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _swing_left > 0.0:
		_swing_left -= delta
		if _swing_left <= 0.0:
			visible = false
			_stop_tween()
			transform = _rest


## Owner: left click through the base tick, right click = heavy stab (shares the cooldown).
func tick(delta: float, cmd: PlayerCommand) -> void:
	super.tick(delta, cmd)
	if def.heavy_damage <= 0.0 or not cmd.secondary_pressed or _cooldown > 0.0:
		return
	_cooldown = def.heavy_interval / player.status.get_fire_rate_mult()
	_play_swing(minf(def.heavy_interval * PRIMARY_SWING_SHARE, HEAVY_SWING_TIME), true)
	player.requests.send_stab(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


## Primary melee, owner: swing animation and the hit request (called by Weapon.tick).
func _fire() -> void:
	_play_swing(minf(def.fire_interval * PRIMARY_SWING_SHARE, PRIMARY_SWING_MAX_TIME))
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func _play_swing(duration: float, stab: bool = false) -> void:
	Sfx.play_at(player.get_parent(), Sfx.SWING, global_position, Sfx.STEP_DB)
	player.effects.report_action(SoldierRig.Action.SWING, duration)
	_stop_tween()
	transform = _rest
	_stab_pose = stab
	if def.melee_swing_angle <= 0.0:
		return
	_tween = create_tween()
	_tween.tween_method(_set_swing_pose, 0.0, 1.0, duration)


## Swing pose at `t` (0..1): rest -> wind-up -> end of the stroke -> rest, eased per segment.
func _set_swing_pose(t: float) -> void:
	var chop: bool = def.view_hands == WeaponDef.ViewHands.BOTH
	var windup := Transform3D(Basis.from_euler(_to_radians(CHOP_WINDUP_ROT if chop else SLASH_WINDUP_ROT)),
		CHOP_WINDUP_POS if chop else SLASH_WINDUP_POS)
	var stroke := Transform3D(Basis.from_euler(_to_radians(CHOP_END_ROT if chop else SLASH_END_ROT)),
		CHOP_END_POS if chop else SLASH_END_POS)
	if _stab_pose:
		windup = Transform3D(Basis.from_euler(_to_radians(STAB_WINDUP_ROT)), STAB_WINDUP_POS)
		stroke = Transform3D(Basis.from_euler(_to_radians(STAB_END_ROT)), STAB_END_POS)
	var pose: Transform3D
	if t < WINDUP_END:
		pose = Transform3D.IDENTITY.interpolate_with(windup, _ease(t / WINDUP_END))
	elif t < STROKE_END:
		pose = windup.interpolate_with(stroke, _ease((t - WINDUP_END) / (STROKE_END - WINDUP_END)))
	else:
		pose = stroke.interpolate_with(Transform3D.IDENTITY, _ease((t - STROKE_END) / (1.0 - STROKE_END)))
	pose = Transform3D.IDENTITY.interpolate_with(pose, clampf(def.melee_swing_angle / SWING_KEY_ANGLE, 0.0, 1.0))
	transform = Transform3D(pose.basis * _rest.basis, _rest.origin + pose.origin)


static func _to_radians(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


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
	var amount: float = (def.heavy_damage if server_heavy else def.damage) * def.zone_multiplier(hitbox.zone)
	if _is_backstab(receiver):
		amount = def.heavy_backstab_damage if server_heavy else def.backstab_damage
	var shooter_id: int = player.get_multiplayer_authority()
	var killed: bool = receiver.call(&"take_hit", amount, hitbox.zone, shooter_id, def.display_name, def.counts_as_knife)
	var dealt: float = receiver.get(&"last_damage_dealt")
	if dealt <= 0.0 and not killed:
		return # Blocked by a raised shield.
	player.confirm_hit.rpc_id(shooter_id, hitbox.zone, killed, dealt, point)
	if def.knockback > 0.0 and not killed and receiver is Player:
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		(receiver as Player).status.server_knockback(flat * def.knockback + Vector3.UP * KNOCKBACK_LIFT)


## Host: the held knife (not the V quick swing) hit someone facing away from us. CS rule: the
## victim's facing and the line from us to the victim point the same way (dot > backstab_dot).
## Players are at their rewound pose here (lag compensation).
func _is_backstab(receiver: Node) -> bool:
	if def.backstab_damage <= 0.0 or player.melee_weapon == self or not receiver.has_method(&"get_facing"):
		return false
	var to_victim: Vector3 = (receiver as Node3D).global_position - player.global_position
	to_victim.y = 0.0
	if to_victim.length_squared() < 0.0001:
		return false
	var facing: Vector3 = receiver.call(&"get_facing")
	return facing.dot(to_victim.normalized()) > def.backstab_dot

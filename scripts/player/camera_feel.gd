class_name CameraFeel
extends RefCounted
## Owner-only camera polish: speed FOV shift, head bob, landing dip, slide drop + tilt and
## damage shake. Purely visual: shots use Player.get_aim_origin / get_aim_basis, never the
## camera, so aim stays consistent. Every effect is scaled by its Settings value (0 = off).

const DEF: CameraFeelDef = preload("res://data/camera/default.tres")

## Degrees of horizontal FOV (4:3) to add to the view.
var fov_extra: float = 0.0
## Metres added to the eye height.
var vertical: float = 0.0
## Metres to the player's right.
var lateral: float = 0.0
## View roll in radians.
var roll: float = 0.0
## View-only kick in degrees (x = right, y = up).
var shake: Vector2 = Vector2.ZERO

var _bob_phase: float = 0.0
var _bob_weight: float = 0.0
var _landing: float = 0.0
var _landing_target: float = 0.0
var _slide: float = 0.0
var _shake_left: float = 0.0
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
## Shot kick (degrees, visual): the gun in view uses all of it, the camera kick_view_share.
var kick: float = 0.0
## Roll direction of the last kick (alternates); its size is the gun's WeaponDef.kick_roll_mult.
var kick_roll_sign: float = 1.0
var _kick_recover_mult: float = 1.0


## Every frame on the owning client.
func update(delta: float, movement: Movement, scoped: bool) -> void:
	var speed: float = movement.get_horizontal_speed()
	if movement.is_grappling():
		speed = movement.body.velocity.length() # Climbing counts too.

	var fov_target: float = 0.0
	if not scoped and DEF.fov_shift_full_speed > DEF.fov_shift_start_speed:
		var share: float = clampf(inverse_lerp(DEF.fov_shift_start_speed, DEF.fov_shift_full_speed, speed), 0.0, 1.0)
		fov_target = DEF.fov_shift_max * share * Settings.camera_fov_shift
	fov_extra = lerpf(fov_extra, fov_target, _smooth(DEF.fov_shift_smoothing, delta))

	var bobbing: bool = movement.body.is_on_floor() and not movement.is_sliding and not scoped
	var bob_target: float = clampf(speed / DEF.bob_ref_speed, 0.0, 1.0) if bobbing and DEF.bob_ref_speed > 0.0 else 0.0
	_bob_weight = lerpf(_bob_weight, bob_target, _smooth(DEF.bob_blend, delta))
	_bob_phase = fmod(_bob_phase + speed * DEF.bob_cycles_per_metre * TAU * delta, TAU)
	var bob_scale: float = _bob_weight * Settings.camera_head_bob

	_landing_target = lerpf(_landing_target, 0.0, _smooth(DEF.landing_recover, delta))
	_landing = lerpf(_landing, _landing_target, _smooth(DEF.landing_follow, delta))

	_slide = lerpf(_slide, 1.0 if movement.is_sliding else 0.0, _smooth(DEF.slide_smoothing, delta))
	var slide_scale: float = _slide * Settings.camera_slide

	vertical = sin(_bob_phase * 2.0) * DEF.bob_height * bob_scale + _landing - DEF.slide_drop * slide_scale
	lateral = sin(_bob_phase) * DEF.bob_sway * bob_scale
	roll = deg_to_rad(DEF.slide_tilt) * slide_scale

	kick = lerpf(kick, 0.0, _smooth(DEF.kick_recover * _kick_recover_mult, delta))
	shake = Vector2.ZERO
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		_shake_time += delta
		var fade: float = _shake_left / maxf(DEF.shake_time, 0.001)
		var phase: float = _shake_time * DEF.shake_frequency * TAU
		shake = Vector2(sin(phase), cos(phase * 1.3)) * _shake_strength * fade


## Owner fired a weapon with WeaponDef.view_kick (sniper, shotgun, launchers...).
func add_kick(degrees: float, recover_mult: float = 1.0, roll_mult: float = 1.0) -> void:
	kick = maxf(kick, degrees)
	_kick_recover_mult = recover_mult
	kick_roll_sign = -signf(kick_roll_sign) * roll_mult


## Movement.landed: a small dip that scales with the fall speed.
func on_landed(fall_speed: float) -> void:
	if DEF.landing_full_fall_speed <= DEF.landing_min_fall_speed:
		return
	var share: float = clampf(inverse_lerp(DEF.landing_min_fall_speed, DEF.landing_full_fall_speed, fall_speed), 0.0, 1.0)
	_landing_target = minf(_landing_target, -DEF.landing_dip * share * Settings.camera_landing)


## The host confirmed we took `amount` damage.
func add_shake(amount: float) -> void:
	var share: float = clampf(amount / maxf(DEF.shake_full_damage, 0.001), DEF.shake_min_share, 1.0)
	var strength: float = DEF.shake_angle * share * Settings.camera_damage_shake
	if strength <= 0.0:
		return
	_shake_strength = maxf(strength, _shake_strength if _shake_left > 0.0 else 0.0)
	_shake_left = DEF.shake_time
	_shake_time = 0.0


## Frame-rate independent lerp weight for a per-second rate.
func _smooth(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)

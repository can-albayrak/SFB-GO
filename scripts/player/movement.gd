class_name Movement
extends Node
## Quake/Source-style movement: ground friction + acceleration, air strafing,
## timed bunny hop with a speed cap, crouch, crouch-jump and slide.
## Runs only on the owning peer. Tuning comes from MovementDef (data/movement/).

const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.15
const HEIGHT_DIFF: float = STAND_HEIGHT - CROUCH_HEIGHT
const STAND_EYE: float = 1.6
const CROUCH_EYE: float = 0.95
const EYE_LERP_SPEED: float = 14.0
const MIN_SPEED: float = 0.05
const SLIDE_FORWARD_INPUT: float = 0.5
const SLIDE_STRAFE_LIMIT: float = 0.3
const GRAPPLE_ARRIVE_DISTANCE: float = 0.8
const GRAPPLE_CHEST: float = 1.0 ## Height above the feet that is pulled to the anchor.
const GRAPPLE_STUCK_SPEED: float = 2.0 ## Pull ends when a wall stops us below this speed.
const GRAPPLE_STUCK_GRACE: float = 0.25
const GRAPPLE_ACCEL: float = 40.0 ## m/s^2 toward the pull speed, so the start is not a hard snap.

@export var collision: CollisionShape3D
@export var head: Node3D

## Set by Player from its ClassDef before the first step.
var def: MovementDef
## Full run speed this tick (class speed * weapon mult * buffs). Set by Player.
var base_speed: float = 6.0
var is_crouched: bool = false
var is_sliding: bool = false

var _jump_buffer: float = 0.0
var _slide_left: float = 0.0
var _slide_cooldown_left: float = 0.0
var _eye_height: float = STAND_EYE
var _grapple_target: Vector3 = Vector3.ZERO
var _grapple_speed: float = 0.0
var _grapple_time: float = 0.0
var _grappling: bool = false

@onready var body: CharacterBody3D = get_parent()
@onready var _capsule: CapsuleShape3D = collision.shape


func physics_step(delta: float, cmd: PlayerCommand) -> void:
	var on_floor: bool = body.is_on_floor()
	_jump_buffer = def.jump_buffer_time if cmd.jump else maxf(_jump_buffer - delta, 0.0)
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)

	if _grappling and _step_grapple(delta, cmd):
		return

	var vel: Vector3 = body.velocity
	var hvel := Vector3(vel.x, 0.0, vel.z)

	hvel = _update_slide(delta, cmd, on_floor, hvel)
	_update_crouch(cmd.crouch or is_sliding, on_floor)

	var wish_dir: Vector3 = _get_wish_dir(cmd.move)
	var wish_speed: float = _get_wish_speed(cmd) if wish_dir != Vector3.ZERO else 0.0

	if on_floor and _jump_buffer > 0.0:
		# Jumping on the landing tick skips friction, which preserves speed (bunny hop).
		_jump_buffer = 0.0
		is_sliding = false
		hvel = hvel.limit_length(base_speed * def.bhop_cap_mult)
		vel.y = def.jump_velocity
		hvel = _air_accelerate(hvel, wish_dir, wish_speed, delta)
	elif on_floor:
		hvel = _apply_friction(hvel, def.slide_friction if is_sliding else def.friction, delta)
		if not is_sliding:
			hvel = _accelerate(hvel, wish_dir, wish_speed, def.ground_accel, delta)
	else:
		vel.y -= def.gravity * delta
		hvel = _air_accelerate(hvel, wish_dir, wish_speed, delta)

	body.velocity = Vector3(hvel.x, vel.y, hvel.z)
	body.move_and_slide()
	_update_eye(delta)


## Owner: pulls the body toward `target` at up to `speed` until it arrives, hits a wall or jumps off.
func start_grapple(target: Vector3, speed: float) -> void:
	_grapple_target = target
	_grapple_speed = speed
	_grapple_time = 0.0
	_grappling = true
	is_sliding = false


func is_grappling() -> bool:
	return _grappling


func get_horizontal_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func reset() -> void:
	_grappling = false
	is_sliding = false
	_jump_buffer = 0.0
	_slide_left = 0.0
	set_crouch_shape(false)
	_eye_height = STAND_EYE
	head.position.y = _eye_height


## Resizes the movement capsule, feet fixed. Also used for remote players' crouch state.
func set_crouch_shape(crouched: bool) -> void:
	is_crouched = crouched
	_capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
	collision.position.y = _capsule.height * 0.5


## Returns true while the pull owns this tick (normal movement is skipped).
func _step_grapple(delta: float, cmd: PlayerCommand) -> bool:
	var to_target: Vector3 = _grapple_target - (body.global_position + Vector3.UP * GRAPPLE_CHEST)
	var stuck: bool = _grapple_time > GRAPPLE_STUCK_GRACE and body.get_real_velocity().length() < GRAPPLE_STUCK_SPEED
	if cmd.jump or to_target.length() < GRAPPLE_ARRIVE_DISTANCE or stuck or _grapple_time > 4.0:
		_grappling = false # Keep the velocity: releasing mid-pull flings the player onward.
		return false
	_grapple_time += delta
	var wanted: Vector3 = to_target.normalized() * _grapple_speed
	body.velocity = body.velocity.move_toward(wanted, GRAPPLE_ACCEL * delta)
	body.move_and_slide()
	_update_eye(delta)
	return true


func _update_slide(delta: float, cmd: PlayerCommand, on_floor: bool, hvel: Vector3) -> Vector3:
	var speed: float = hvel.length()
	if is_sliding:
		_slide_left -= delta
		if _slide_left <= 0.0 or not cmd.crouch or not on_floor or speed < base_speed * def.crouch_mult:
			is_sliding = false
		return hvel

	# Slides start only while running straight forward (W, no strafe keys).
	var moving_forward: bool = cmd.move.y < -SLIDE_FORWARD_INPUT and absf(cmd.move.x) < SLIDE_STRAFE_LIMIT
	var can_slide: bool = on_floor and cmd.crouch_pressed and moving_forward \
		and _slide_cooldown_left <= 0.0 and speed >= base_speed * def.slide_min_speed_mult
	if not can_slide:
		return hvel

	is_sliding = true
	_slide_left = def.slide_duration
	_slide_cooldown_left = def.slide_cooldown
	return (hvel * def.slide_boost_mult).limit_length(base_speed * def.slide_max_speed_mult)


func _update_crouch(want: bool, on_floor: bool) -> void:
	if want and not is_crouched:
		set_crouch_shape(true)
		if not on_floor:
			# Crouch-jump: pull the legs up instead of lowering the head.
			body.position.y += HEIGHT_DIFF
			_eye_height -= HEIGHT_DIFF
	elif not want and is_crouched:
		var xform: Transform3D = body.global_transform
		if on_floor:
			if not body.test_move(xform, Vector3.UP * HEIGHT_DIFF):
				set_crouch_shape(false)
		elif not body.test_move(xform, Vector3.DOWN * HEIGHT_DIFF):
			body.position.y -= HEIGHT_DIFF
			_eye_height += HEIGHT_DIFF
			set_crouch_shape(false)
		elif not body.test_move(xform, Vector3.UP * HEIGHT_DIFF):
			set_crouch_shape(false)


func _update_eye(delta: float) -> void:
	var target: float = CROUCH_EYE if is_crouched else STAND_EYE
	_eye_height = lerpf(_eye_height, target, minf(EYE_LERP_SPEED * delta, 1.0))
	head.position.y = _eye_height


func _get_wish_dir(move: Vector2) -> Vector3:
	var dir: Vector3 = body.global_basis * Vector3(move.x, 0.0, move.y)
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()


func _get_wish_speed(cmd: PlayerCommand) -> float:
	if is_crouched:
		return base_speed * def.crouch_mult
	if cmd.sprint:
		return base_speed * def.sprint_mult
	return base_speed


func _accelerate(hvel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	var add_speed: float = wish_speed - hvel.dot(wish_dir)
	if add_speed <= 0.0:
		return hvel
	return hvel + wish_dir * minf(accel * wish_speed * delta, add_speed)


func _air_accelerate(hvel: Vector3, wish_dir: Vector3, wish_speed: float, delta: float) -> Vector3:
	var add_speed: float = minf(wish_speed, def.air_speed_cap) - hvel.dot(wish_dir)
	if add_speed <= 0.0:
		return hvel
	return hvel + wish_dir * minf(def.air_accel * wish_speed * delta, add_speed)


func _apply_friction(hvel: Vector3, fric: float, delta: float) -> Vector3:
	var speed: float = hvel.length()
	if speed < MIN_SPEED:
		return Vector3.ZERO
	var drop: float = maxf(speed, def.stop_speed) * fric * delta
	return hvel * (maxf(speed - drop, 0.0) / speed)

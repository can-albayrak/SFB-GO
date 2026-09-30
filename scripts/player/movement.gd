class_name Movement
extends Node
## Quake/Source-style movement: ground friction + acceleration, air strafing,
## timed bunny hop with a speed cap, crouch, crouch-jump and slide.
## Tuning values are exported so they can be adjusted per scene in the inspector.

const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.15
const HEIGHT_DIFF: float = STAND_HEIGHT - CROUCH_HEIGHT
const STAND_EYE: float = 1.6
const CROUCH_EYE: float = 0.95
const EYE_LERP_SPEED: float = 14.0
const MIN_SPEED: float = 0.05

@export var collision: CollisionShape3D
@export var head: Node3D

@export_group("Ground")
@export var ground_accel: float = 10.0
@export var friction: float = 6.0
@export var stop_speed: float = 2.0 ## Below this speed friction acts as if moving this fast (quick stops).
@export var walk_mult: float = 0.52
@export var crouch_mult: float = 0.4

@export_group("Air")
@export var gravity: float = 16.0
@export var jump_velocity: float = 5.6
@export var air_accel: float = 12.0
@export var air_speed_cap: float = 0.8 ## Limits air gain per direction, which is what makes strafing work.
@export var bhop_cap_mult: float = 1.3 ## Horizontal speed is clamped to base * this on every jump.
@export var jump_buffer_time: float = 0.08 ## Jump pressed this early before landing still counts.

@export_group("Slide")
@export var slide_min_speed_mult: float = 0.85
@export var slide_boost_mult: float = 1.2
@export var slide_friction: float = 0.8
@export var slide_duration: float = 0.75
@export var slide_cooldown: float = 0.8

## Full run speed this tick (class speed * weapon mult * buffs). Set by Player.
var base_speed: float = 6.0
var is_crouched: bool = false
var is_sliding: bool = false

var _jump_buffer: float = 0.0
var _slide_left: float = 0.0
var _slide_cooldown_left: float = 0.0
var _eye_height: float = STAND_EYE

@onready var body: CharacterBody3D = get_parent()
@onready var _capsule: CapsuleShape3D = collision.shape


func physics_step(delta: float, cmd: PlayerCommand) -> void:
	var on_floor: bool = body.is_on_floor()
	_jump_buffer = jump_buffer_time if cmd.jump else maxf(_jump_buffer - delta, 0.0)
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)

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
		hvel = hvel.limit_length(base_speed * bhop_cap_mult)
		vel.y = jump_velocity
		hvel = _air_accelerate(hvel, wish_dir, wish_speed, delta)
	elif on_floor:
		hvel = _apply_friction(hvel, slide_friction if is_sliding else friction, delta)
		if not is_sliding:
			hvel = _accelerate(hvel, wish_dir, wish_speed, ground_accel, delta)
	else:
		vel.y -= gravity * delta
		hvel = _air_accelerate(hvel, wish_dir, wish_speed, delta)

	body.velocity = Vector3(hvel.x, vel.y, hvel.z)
	body.move_and_slide()
	_update_eye(delta)


func get_horizontal_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func reset() -> void:
	is_sliding = false
	_jump_buffer = 0.0
	_slide_left = 0.0
	_set_crouched(false)
	_eye_height = STAND_EYE
	head.position.y = _eye_height


func _update_slide(delta: float, cmd: PlayerCommand, on_floor: bool, hvel: Vector3) -> Vector3:
	var speed: float = hvel.length()
	if is_sliding:
		_slide_left -= delta
		if _slide_left <= 0.0 or not cmd.crouch or not on_floor or speed < base_speed * crouch_mult:
			is_sliding = false
		return hvel

	var can_slide: bool = on_floor and cmd.crouch_pressed and not cmd.walk \
		and _slide_cooldown_left <= 0.0 and speed >= base_speed * slide_min_speed_mult
	if not can_slide:
		return hvel

	is_sliding = true
	_slide_left = slide_duration
	_slide_cooldown_left = slide_cooldown
	return (hvel * slide_boost_mult).limit_length(base_speed * bhop_cap_mult)


func _update_crouch(want: bool, on_floor: bool) -> void:
	if want and not is_crouched:
		_set_crouched(true)
		if not on_floor:
			# Crouch-jump: pull the legs up instead of lowering the head.
			body.position.y += HEIGHT_DIFF
			_eye_height -= HEIGHT_DIFF
	elif not want and is_crouched:
		var xform: Transform3D = body.global_transform
		if on_floor:
			if not body.test_move(xform, Vector3.UP * HEIGHT_DIFF):
				_set_crouched(false)
		elif not body.test_move(xform, Vector3.DOWN * HEIGHT_DIFF):
			body.position.y -= HEIGHT_DIFF
			_eye_height += HEIGHT_DIFF
			_set_crouched(false)
		elif not body.test_move(xform, Vector3.UP * HEIGHT_DIFF):
			_set_crouched(false)


func _set_crouched(crouched: bool) -> void:
	is_crouched = crouched
	_capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
	collision.position.y = _capsule.height * 0.5


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
		return base_speed * crouch_mult
	if cmd.walk:
		return base_speed * walk_mult
	return base_speed


func _accelerate(hvel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	var add_speed: float = wish_speed - hvel.dot(wish_dir)
	if add_speed <= 0.0:
		return hvel
	return hvel + wish_dir * minf(accel * wish_speed * delta, add_speed)


func _air_accelerate(hvel: Vector3, wish_dir: Vector3, wish_speed: float, delta: float) -> Vector3:
	var add_speed: float = minf(wish_speed, air_speed_cap) - hvel.dot(wish_dir)
	if add_speed <= 0.0:
		return hvel
	return hvel + wish_dir * minf(air_accel * wish_speed * delta, add_speed)


func _apply_friction(hvel: Vector3, fric: float, delta: float) -> Vector3:
	var speed: float = hvel.length()
	if speed < MIN_SPEED:
		return Vector3.ZERO
	var drop: float = maxf(speed, stop_speed) * fric * delta
	return hvel * (maxf(speed - drop, 0.0) / speed)

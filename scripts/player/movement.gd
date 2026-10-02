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
const CHARGE_STUCK_SPEED: float = 2.0 ## Charge ends early when a wall stops us below this speed.
const CHARGE_STUCK_GRACE: float = 0.15
const DASH_STUCK_SPEED: float = 2.0 ## Dash ends early when a wall stops us below this speed.
const DASH_STUCK_GRACE: float = 0.05
const FLOOR_PROBE_MIN: float = 0.15 ## Metres: a floor this close below always counts as landing.
const GRAPPLE_ACCEL: float = 40.0 ## m/s^2 toward the pull speed, so the start is not a hard snap.
const STEP_WALL_NORMAL_Y: float = 0.7 ## Contacts steeper than this (walls, stair faces) may be stepped over.
const STEP_MIN_RISE: float = 0.02 ## Metres: smaller rises are left to the capsule sliding.
const STEP_MIN_GAIN: float = 0.01 ## Metres: the step must get further than sliding along the wall did.
const STEP_PROBE_INSET: float = 0.03 ## Metres past the step's edge where its top is checked.
const STEP_PROBE_HEIGHT: float = 0.05
## Metres: a step moves at least this far forward, so the capsule ends over the step
## instead of perched on its edge (a tilted contact that is not floor).
const STEP_TOP_TOLERANCE: float = 0.03 ## Metres a step top may sit above step_height (contact rounding).
const STEP_MIN_FORWARD: float = 0.15

## Touched the ground after being in the air (camera landing dip).
signal landed(fall_speed: float)

@export var collision: CollisionShape3D
@export var head: Node3D

## Set by Player from its ClassDef before the first step.
var def: MovementDef
## Full run speed this tick (class speed * weapon mult * buffs). Set by Player.
var base_speed: float = 6.0
var is_crouched: bool = false
var is_sliding: bool = false
## Input direction of the last tick (world, flat); zero when no movement key is held.
var last_wish_dir: Vector3 = Vector3.ZERO
## Extra jumps allowed in the air this tick (Double Jump pickup); set by the player.
var air_jumps: int = 0

var _jump_buffer: float = 0.0
var _coyote_left: float = 0.0
var _air_jumps_used: int = 0
var _coyote_from_slide: bool = false ## Was sliding on the last tick on the ground.
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _slide_left: float = 0.0
var _slide_cooldown_left: float = 0.0
var _eye_height: float = STAND_EYE
var _grapple_target: Vector3 = Vector3.ZERO
var _grapple_speed: float = 0.0
var _grapple_time: float = 0.0
var _grappling: bool = false
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_speed: float = 0.0
var _charge_left: float = 0.0
var _charge_time: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_left: float = 0.0
var _dash_time: float = 0.0
var _dash_exit_speed: float = 0.0

@onready var body: CharacterBody3D = get_parent()
@onready var _capsule: CapsuleShape3D = collision.shape


func physics_step(delta: float, cmd: PlayerCommand) -> void:
	var on_floor: bool = body.is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(_fall_speed)
	_was_on_floor = on_floor
	_fall_speed = 0.0 if on_floor else maxf(-body.velocity.y, 0.0)
	_jump_buffer = def.jump_buffer_time if cmd.jump else maxf(_jump_buffer - delta, 0.0)
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	last_wish_dir = _get_wish_dir(cmd.move)
	if on_floor:
		_coyote_left = def.coyote_time
		_coyote_from_slide = is_sliding
		_air_jumps_used = 0
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)

	if _grappling and _step_grapple(delta, cmd):
		return
	if _charge_left > 0.0:
		_step_charge(delta)
		return
	if _dash_left > 0.0:
		_step_dash(delta)
		return

	var vel: Vector3 = body.velocity
	var hvel := Vector3(vel.x, 0.0, vel.z)

	# A slide started on this very tick does not count: slide + jump together gains nothing.
	var was_sliding: bool = is_sliding
	hvel = _update_slide(delta, cmd, on_floor, hvel)
	_update_crouch(cmd.crouch or is_sliding, on_floor)

	var wish_dir: Vector3 = last_wish_dir
	var wish_speed: float = _get_wish_speed(cmd) if wish_dir != Vector3.ZERO else 0.0

	if (on_floor or _coyote_left > 0.0) and _jump_buffer > 0.0:
		# Jumping on the landing tick skips friction, which preserves speed (bunny hop).
		# Off a ledge, coyote time still accepts the jump for a moment.
		var from_slide: bool = was_sliding if on_floor else _coyote_from_slide
		_jump_buffer = 0.0
		_coyote_left = 0.0
		is_sliding = false
		var cap: float = base_speed * def.bhop_cap_mult
		if def.slide_jump_keeps_speed and from_slide:
			cap = maxf(cap, hvel.length()) # Slide speed is kept, never raised.
		hvel = hvel.limit_length(cap)
		vel.y = def.jump_velocity
		hvel = _air_accelerate(hvel, wish_dir, wish_speed, delta)
	elif not on_floor and _jump_buffer > 0.0 and _air_jumps_used < air_jumps and not _floor_just_below(vel.y):
		# Double Jump pickup: a second jump in the air, no speed gain.
		_jump_buffer = 0.0
		_air_jumps_used += 1
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
	_move_and_step(on_floor and vel.y <= 0.0)
	_update_eye(delta)


## move_and_slide, then: walking into something low (a stair, a kerb) retries the move
## raised by up to def.step_height and sets the body down on top of it. The eye is lowered
## by the rise, so the camera climbs smoothly instead of popping up.
func _move_and_step(grounded: bool) -> void:
	body.floor_snap_length = def.step_height # Feet stay on the floor walking down stairs.
	var start: Transform3D = body.global_transform
	var vel: Vector3 = body.velocity
	body.move_and_slide()
	if not grounded or def.step_height <= 0.0 or not _hit_wall():
		return
	var motion := Vector3(vel.x, 0.0, vel.z) * get_physics_process_delta_time()
	if motion.length_squared() < 0.000001:
		return
	if motion.length() < STEP_MIN_FORWARD:
		motion = motion.normalized() * STEP_MIN_FORWARD
	var offset: Vector3 = _find_step(start, motion)
	if offset == Vector3.INF:
		return
	var dir: Vector3 = motion.normalized()
	var slid: Vector3 = body.global_position - start.origin
	if offset.dot(dir) - slid.dot(dir) < STEP_MIN_GAIN:
		return
	body.global_position = start.origin + offset
	body.velocity = Vector3(vel.x, 0.0, vel.z) # The wall contact took speed away; the step keeps it.
	_eye_height -= offset.y


func _hit_wall() -> bool:
	for i: int in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_normal().y < STEP_WALL_NORMAL_Y:
			return true
	return false


## Up, forward, down from `start`. Returns the offset to stand on the step, or INF when
## there is no headroom, the obstacle is too high, or there is no walkable top.
func _find_step(start: Transform3D, motion: Vector3) -> Vector3:
	var hit := KinematicCollision3D.new()
	var up: Vector3 = Vector3.UP * def.step_height
	if body.test_move(start, up, hit):
		up = hit.get_travel()
		if up.y < STEP_MIN_RISE:
			return Vector3.INF
	var raised: Transform3D = start.translated(up)
	if body.test_move(raised, motion):
		return Vector3.INF
	var ahead: Transform3D = raised.translated(motion)
	if not body.test_move(ahead, Vector3.DOWN * up.y, hit):
		return Vector3.INF
	if not _is_walkable_top(hit.get_position(), motion.normalized()):
		return Vector3.INF
	# The rounded capsule bottom can also come to rest on the edge of a taller block (the
	# down probe stops at once). Its top must be within step height of the feet, or a fast
	# run would climb it in two steps.
	if hit.get_position().y - start.origin.y > def.step_height + STEP_TOP_TOLERANCE:
		return Vector3.INF
	var offset: Vector3 = up + motion + hit.get_travel()
	if offset.y < STEP_MIN_RISE:
		return Vector3.INF
	return offset


## The rounded capsule bottom lands on the step's edge, so the contact normal is tilted
## even on a flat stair. A short ray just past the contact finds the real top surface.
func _is_walkable_top(contact: Vector3, dir: Vector3) -> bool:
	var from: Vector3 = contact + dir * STEP_PROBE_INSET + Vector3.UP * STEP_PROBE_HEIGHT
	var to: Vector3 = from + Vector3.DOWN * STEP_PROBE_HEIGHT * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, [body.get_rid()])
	var result: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and (result.normal as Vector3).y >= cos(body.floor_max_angle)


## Falling onto a floor within the jump buffer: that press is a buffered landing hop
## (bunny hop), not a Double Jump.
func _floor_just_below(vertical_speed: float) -> bool:
	if vertical_speed >= 0.0:
		return false
	var reach: float = maxf(-vertical_speed * def.jump_buffer_time, FLOOR_PROBE_MIN)
	var from: Vector3 = body.global_position + Vector3.UP * 0.05
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (reach + 0.05), 1, [body.get_rid()])
	return not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Owner: pulls the body toward `target` at up to `speed` until it arrives, hits a wall or jumps off.
func start_grapple(target: Vector3, speed: float) -> void:
	_grapple_target = target
	_grapple_speed = speed
	_grapple_time = 0.0
	_grappling = true
	is_sliding = false


## Owner: Bear's Charge. Runs at `speed` along `dir` (flattened) for `seconds`, no steering.
func start_charge(dir: Vector3, speed: float, seconds: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	_charge_dir = flat.normalized()
	_charge_speed = speed
	_charge_left = seconds
	_charge_time = 0.0
	is_sliding = false


## Owner: Cheetah's Dash. A short flat burst along `dir` (also in the air, no gravity
## during it); afterwards the horizontal speed is limited to `exit_speed` (0 = keep it).
func start_dash(dir: Vector3, speed: float, seconds: float, exit_speed: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	_dash_velocity = flat.normalized() * speed
	_dash_left = seconds
	_dash_time = 0.0
	_dash_exit_speed = exit_speed
	_grappling = false
	is_sliding = false


## Owner: a stun ends any grapple pull, charge or dash at once.
func cancel_specials() -> void:
	_grappling = false
	_charge_left = 0.0
	if _dash_left > 0.0:
		_dash_left = 0.0
		var hvel := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if _dash_exit_speed > 0.0:
			hvel = hvel.limit_length(_dash_exit_speed)
		body.velocity = Vector3(hvel.x, body.velocity.y, hvel.z)


func is_dashing() -> bool:
	return _dash_left > 0.0


func is_grappling() -> bool:
	return _grappling


func get_horizontal_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func reset() -> void:
	_grappling = false
	_charge_left = 0.0
	_dash_left = 0.0
	is_sliding = false
	_jump_buffer = 0.0
	_coyote_left = 0.0
	_coyote_from_slide = false
	_air_jumps_used = 0
	_was_on_floor = true
	_fall_speed = 0.0
	_slide_left = 0.0
	set_crouch_shape(false)
	_eye_height = STAND_EYE
	head.position.y = _eye_height


## Resizes the movement capsule, feet fixed. Also used for remote players' crouch state.
func set_crouch_shape(crouched: bool) -> void:
	is_crouched = crouched
	_capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
	collision.position.y = _capsule.height * 0.5


func _step_charge(delta: float) -> void:
	_charge_left -= delta
	_charge_time += delta
	var vel: Vector3 = body.velocity
	vel.x = _charge_dir.x * _charge_speed
	vel.z = _charge_dir.z * _charge_speed
	var grounded: bool = body.is_on_floor()
	if grounded:
		vel.y = maxf(vel.y, 0.0)
	else:
		vel.y -= def.gravity * delta
	body.velocity = vel
	_move_and_step(grounded and vel.y <= 0.0)
	if _charge_time > CHARGE_STUCK_GRACE and Vector2(body.get_real_velocity().x, body.get_real_velocity().z).length() < CHARGE_STUCK_SPEED:
		_charge_left = 0.0 # Ran into a wall.
	_update_eye(delta)


func _step_dash(delta: float) -> void:
	_dash_left -= delta
	_dash_time += delta
	body.velocity = _dash_velocity
	_move_and_step(body.is_on_floor())
	var real: Vector3 = body.get_real_velocity()
	if _dash_time > DASH_STUCK_GRACE and Vector2(real.x, real.z).length() < DASH_STUCK_SPEED:
		_dash_left = 0.0 # Ran into a wall.
	if _dash_left <= 0.0:
		var hvel := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if _dash_exit_speed > 0.0:
			hvel = hvel.limit_length(_dash_exit_speed)
		body.velocity = Vector3(hvel.x, 0.0, hvel.z)
	_update_eye(delta)


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
	var free_air: bool = def.air_speed_cap <= 0.0
	var add_speed: float = (wish_speed if free_air else minf(wish_speed, def.air_speed_cap)) - hvel.dot(wish_dir)
	if add_speed <= 0.0:
		return hvel
	var accel: float = def.air_control_accel if free_air else def.air_accel
	var result: Vector3 = hvel + wish_dir * minf(accel * wish_speed * delta, add_speed)
	if not free_air:
		return result # Quake strafing: the jump clamp limits the gain.
	# Free air control may steer but never pushes past the horizontal cap (or the speed we already had).
	return result.limit_length(maxf(hvel.length(), base_speed * def.bhop_cap_mult))


func _apply_friction(hvel: Vector3, fric: float, delta: float) -> Vector3:
	var speed: float = hvel.length()
	if speed < MIN_SPEED:
		return Vector3.ZERO
	var drop: float = maxf(speed, def.stop_speed) * fric * delta
	return hvel * (maxf(speed - drop, 0.0) / speed)

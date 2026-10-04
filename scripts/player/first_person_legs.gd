class_name FirstPersonLegs
extends Node3D
## Owner only: your own legs, seen when looking down and while sliding (placeholder boxes
## until stage 8 models). Purely visual and procedural: a two-bone leg solved toward a foot
## target that walks with your speed, folds when crouched, tucks in the air and reaches
## forward in a slide (hips ahead of the eye, as in a real slide, so the boots come into view).

const THIGH: float = 0.44
const SHIN: float = 0.44
const ANKLE_HEIGHT: float = 0.09
const HIP_WIDTH: float = 0.11
const LEG_THICKNESS: float = 0.15
const BOOT_SIZE: Vector3 = Vector3(0.14, 0.12, 0.28)
const BOOT_FORWARD: float = 0.06

const STAND_HIP: Vector2 = Vector2(0.88, 0.12) ## (height above the feet, z behind the eye).
const CROUCH_HIP: Vector2 = Vector2(0.52, 0.12)
const SLIDE_HIP: Vector2 = Vector2(0.32, -0.24)
const SLIDE_FOOT_FORWARD: float = 0.82
const SLIDE_FOOT_HEIGHT: float = 0.16
const SLIDE_FOOT_PITCH: float = 0.25 ## Radians toe-up in a slide.
const CROUCH_FOOT_FORWARD: float = 0.12
const AIR_TUCK: Vector2 = Vector2(0.12, 0.22) ## Foot forward / lift while airborne.
const STRIDE_LENGTH: float = 1.3 ## Metres per full step cycle.
const STRIDE_REACH: float = 0.3 ## Foot swing forward / back at full run.
const STEP_LIFT: float = 0.13
const BLEND_RATE: float = 10.0 ## Per second, how fast poses change.
const MIN_WALK_SPEED: float = 0.3

const SLEEVE_COLOR: Color = Color(0.1, 0.11, 0.15) ## Saul's suit trousers.
const BOOT_COLOR: Color = Color(0.05, 0.04, 0.04) ## Black dress shoes.

var _player: Player
var _legs: Array[Dictionary] = [] ## {hip, knee, ankle} per leg, left then right.
var _phase: float = 0.0
var _slide: float = 0.0
var _air: float = 0.0
var _walk: float = 0.0


static func create(player: Player) -> FirstPersonLegs:
	var legs := FirstPersonLegs.new()
	legs._player = player
	legs.name = "FirstPersonLegs"
	return legs


func _ready() -> void:
	var sleeve := _material(SLEEVE_COLOR)
	var boot := _material(BOOT_COLOR)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position.x = HIP_WIDTH * side
		add_child(hip)
		var thigh := _box(Vector3(LEG_THICKNESS, THIGH, LEG_THICKNESS), sleeve)
		thigh.position.y = -THIGH * 0.5
		hip.add_child(thigh)
		var knee := Node3D.new()
		knee.position.y = -THIGH
		hip.add_child(knee)
		var shin := _box(Vector3(LEG_THICKNESS * 0.9, SHIN, LEG_THICKNESS * 0.9), sleeve)
		shin.position.y = -SHIN * 0.5
		knee.add_child(shin)
		var ankle := Node3D.new()
		ankle.position.y = -SHIN
		knee.add_child(ankle)
		var foot := _box(BOOT_SIZE, boot)
		foot.position = Vector3(0.0, -ANKLE_HEIGHT + BOOT_SIZE.y * 0.5, -BOOT_FORWARD)
		ankle.add_child(foot)
		_legs.append({"hip": hip, "knee": knee, "ankle": ankle})


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	visible = _player.is_alive
	if not visible:
		return
	var movement: Movement = _player.movement
	var weight: float = 1.0 - exp(-BLEND_RATE * delta)
	var speed: float = movement.get_horizontal_speed()
	var on_floor: bool = _player.is_on_floor()
	_slide = lerpf(_slide, 1.0 if movement.is_sliding else 0.0, weight)
	_air = lerpf(_air, 0.0 if on_floor or movement.is_sliding else 1.0, weight)
	var walking: bool = on_floor and not movement.is_sliding and speed > MIN_WALK_SPEED
	_walk = lerpf(_walk, clampf(speed / maxf(movement.base_speed, 0.1), 0.0, 1.2) if walking else 0.0, weight)
	if on_floor:
		_phase = fmod(_phase + speed / STRIDE_LENGTH * TAU * delta, TAU)

	# Hip height follows the eye: standing, crouched, or down in a slide.
	var crouch: float = clampf((Movement.STAND_EYE - _player.head.position.y) / (Movement.STAND_EYE - Movement.CROUCH_EYE), 0.0, 1.0)
	var hip: Vector2 = STAND_HIP.lerp(CROUCH_HIP, crouch).lerp(SLIDE_HIP, _slide)
	# Walking backwards swings the stride the other way.
	var forward_speed: float = -_player.velocity.dot(_player.global_basis.z)
	var direction: float = -1.0 if forward_speed < -MIN_WALK_SPEED else 1.0

	for i: int in _legs.size():
		var leg: Dictionary = _legs[i]
		var phase: float = _phase + (PI if i == 1 else 0.0)
		var foot_forward: float = sin(phase) * STRIDE_REACH * _walk * direction
		var lift: float = maxf(cos(phase) * direction, 0.0) * STEP_LIFT * _walk
		foot_forward = lerpf(foot_forward, CROUCH_FOOT_FORWARD, crouch * (1.0 - _slide))
		foot_forward = lerpf(foot_forward, AIR_TUCK.x, _air)
		lift = lerpf(lift, AIR_TUCK.y, _air)
		foot_forward = lerpf(foot_forward, SLIDE_FOOT_FORWARD, _slide)
		lift = lerpf(lift, SLIDE_FOOT_HEIGHT, _slide)
		var hip_node: Node3D = leg["hip"]
		hip_node.position.y = hip.x
		hip_node.position.z = hip.y
		_solve(leg, foot_forward, hip.x - ANKLE_HEIGHT - lift, _slide * SLIDE_FOOT_PITCH)


## Two-bone leg in the sagittal plane: hip -> ankle target `forward` ahead and `down` below.
## Knees bend forward; the boot keeps `foot_pitch` radians (toe up) to the ground.
func _solve(leg: Dictionary, forward: float, down: float, foot_pitch: float) -> void:
	var reach: float = clampf(Vector2(forward, down).length(), 0.1, THIGH + SHIN - 0.001)
	var to_target: float = atan2(forward, maxf(down, 0.001))
	var hip_bend: float = acos(clampf((THIGH * THIGH + reach * reach - SHIN * SHIN) / (2.0 * THIGH * reach), -1.0, 1.0))
	var knee_inner: float = acos(clampf((THIGH * THIGH + SHIN * SHIN - reach * reach) / (2.0 * THIGH * SHIN), -1.0, 1.0))
	var thigh_angle: float = to_target + hip_bend
	var knee_angle: float = -(PI - knee_inner)
	(leg["hip"] as Node3D).rotation.x = thigh_angle
	(leg["knee"] as Node3D).rotation.x = knee_angle
	(leg["ankle"] as Node3D).rotation.x = -(thigh_angle + knee_angle) + foot_pitch


func _box(box_size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

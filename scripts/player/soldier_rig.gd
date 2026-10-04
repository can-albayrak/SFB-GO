class_name SoldierRig
extends Node3D
## Animated third-person body (Mixamo clips on the placeholder soldier). Purely visual:
## hitboxes, hits and deaths stay host-authoritative and never read the animation.
## Driven every frame from what each peer already knows: the interpolated position,
## yaw, look pitch, crouch and the shots it is shown.

const BLEND_RADIUS: float = 2.2 ## Blend space ring (m/s); faster runs speed the clip up instead.
const MAX_TIME_SCALE: float = 2.4
const VELOCITY_SMOOTHING: float = 12.0 ## Per second.
const MAX_SPEED: float = 15.0 ## Teleports (respawn) never read as a sprint.
const MIN_MOVE_SPEED: float = 0.4
const STATE_FADE: float = 0.15
const FIRE_HOLD: float = 0.35 ## Seconds the upper body stays in the firing pose per shot.
const FIRE_FADE: float = 8.0 ## Per second, back to the run's arms.
const GROUND_PROBE: float = 0.3 ## Metres below the feet that still count as standing.
const GROUND_MASK: int = 1
const FALL_SPEED: float = -1.5 ## Below this vertical speed in the air: falling clip.
const MAX_SPINE_PITCH: float = deg_to_rad(60.0)
const CROWN_ABOVE_HEAD: float = 0.45
## Player.apply_pose squashes the body by this when crouched: the crouch-walk clip stands
## taller than the crouched head hitbox (0.98 m), so the drawn head is pulled down onto it.
const CROUCH_SCALE: float = 0.74
const UPPER_BODY_BONES: Array[String] = [
	"Spine", "Spine1", "Spine2", "Neck", "Head", "Shoulder", "Arm", "ForeArm", "Hand",
]

var skeleton: Skeleton3D

var _player: Player
var _tree: AnimationTree
var _velocity: Vector3 = Vector3.ZERO
var _last_position: Vector3
var _has_last_position: bool = false
var _fire_left: float = 0.0
var _fire_amount: float = 0.0
var _state: String = "" ## Empty until the first frame picks one (the Transition starts with none).
var _hand_bone: int = -1
var _head_bone: int = -1
var _spine_aim: SpineAimModifier


static func create() -> SoldierRig:
	var rig := SoldierRig.new()
	rig.name = "Rig"
	var body := Node3D.new()
	body.name = "Body"
	body.rotation.y = PI # Mixamo faces +Z, the game faces -Z.
	rig.add_child(body)
	rig.skeleton = SoldierAnimations.create_skeleton()
	body.add_child(rig.skeleton)
	var mesh: MeshInstance3D = SoldierMesh.create(rig.skeleton)
	rig.skeleton.add_child(mesh)
	mesh.skeleton = ^".."
	var animations := AnimationPlayer.new()
	animations.name = "AnimationPlayer"
	animations.add_animation_library(&"", SoldierAnimations.get_library())
	body.add_child(animations)
	rig._spine_aim = SpineAimModifier.new()
	rig._spine_aim.name = "SpineAim"
	rig.skeleton.add_child(rig._spine_aim)
	rig._tree = AnimationTree.new()
	rig._tree.name = "AnimationTree"
	rig._tree.tree_root = _build_tree(rig.skeleton)
	body.add_child(rig._tree)
	rig._tree.anim_player = rig._tree.get_path_to(animations)
	rig._tree.active = false
	return rig


## Corpse use: plays one clip from the start (call once the rig is in the tree).
func play_clip(clip: StringName, speed: float = 1.0) -> void:
	var animations: AnimationPlayer = get_node("Body/AnimationPlayer") as AnimationPlayer
	animations.play(clip, -1.0, speed)


func _ready() -> void:
	# Decoy copies are made with duplicate(), which does not carry plain script variables.
	skeleton = get_node("Body/Skeleton3D") as Skeleton3D
	_tree = get_node("Body/AnimationTree") as AnimationTree
	_spine_aim = get_node("Body/Skeleton3D/SpineAim") as SpineAimModifier
	_hand_bone = skeleton.find_bone("mixamorig_RightHand")
	_head_bone = skeleton.find_bone("mixamorig_Head")
	if _player == null:
		_tree.active = false # Decoy copy or corpse: no live player drives it.
		set_process(false)


## The live body of a player (every peer, own player included so decoys copy a real pose).
func setup(player: Player) -> void:
	_player = player
	_spine_aim.upright = true
	_tree.set(&"parameters/crouch_aim/blend_amount", 1.0)
	_tree.active = true
	set_process(true)
	_tree.advance(0.0)


## Every peer that is shown a shot from this player.
func play_fire() -> void:
	_fire_left = FIRE_HOLD


## Respawn: no running start from the death spot.
func reset_motion() -> void:
	_has_last_position = false
	_velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if _player == null or delta <= 0.0:
		return
	var position_now: Vector3 = _player.global_position
	var velocity: Vector3 = Vector3.ZERO
	if _player.is_local:
		velocity = _player.velocity
	elif _has_last_position:
		velocity = (position_now - _last_position) / delta
	if velocity.length() > MAX_SPEED:
		velocity = Vector3.ZERO
	_last_position = position_now
	_has_last_position = true
	_velocity = _velocity.lerp(velocity, minf(VELOCITY_SMOOTHING * delta, 1.0))

	var local: Vector3 = _player.global_basis.inverse() * _velocity
	var planar := Vector2(local.x, -local.z) # x = right, y = forward.
	var speed: float = planar.length()
	var crouched: bool = _player.is_pose_crouched()
	var state: String = "crouch" if crouched else "ground"
	if not _on_ground():
		state = "fall" if _velocity.y < FALL_SPEED else "jump"
	if state != _state:
		_state = state
		_tree.set(&"parameters/state/transition_request", state)

	if crouched:
		var side: float = signf(planar.x) if absf(planar.x) > MIN_MOVE_SPEED else 1.0
		var amount: float = minf(speed, SoldierAnimations.crouch_speed) if speed > MIN_MOVE_SPEED else 0.0
		_tree.set(&"parameters/crouch_space/blend_position", side * amount / SoldierAnimations.crouch_speed)
		_tree.set(&"parameters/crouch_speed/scale", clampf(speed / SoldierAnimations.crouch_speed, 1.0, MAX_TIME_SCALE))
	else:
		var point: Vector2 = Vector2.ZERO
		if speed > MIN_MOVE_SPEED:
			point = planar.normalized() * minf(speed, BLEND_RADIUS)
		_tree.set(&"parameters/ground_space/blend_position", point)
		_tree.set(&"parameters/ground_speed/scale", clampf(speed / BLEND_RADIUS, 1.0, MAX_TIME_SCALE))

	_fire_left -= delta
	var fire_target: float = 1.0 if _fire_left > 0.0 else 0.0
	_fire_amount = move_toward(_fire_amount, fire_target, FIRE_FADE * delta) if fire_target < _fire_amount else fire_target
	_tree.set(&"parameters/fire/blend_amount", _fire_amount)

	_spine_aim.pitch = clampf(_player.look_pitch, -MAX_SPINE_PITCH, MAX_SPINE_PITCH)
	_place_attachments(_player.hand, _player.crown)


## The held weapon sits in the right hand, aimed where the player looks; the leader
## crown floats over the head.
func _place_attachments(hand: Node3D, crown: Node3D) -> void:
	var hand_point: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(_hand_bone).origin
	var yaw_basis := Basis(Vector3.UP, _player.global_rotation.y)
	var aim := yaw_basis * Basis(Vector3.RIGHT, _player.look_pitch)
	hand.global_transform = Transform3D(aim, hand_point)
	var head_point: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(_head_bone).origin
	crown.global_position = head_point + Vector3.UP * CROWN_ABOVE_HEAD


func _on_ground() -> bool:
	if _player.is_local:
		return _player.is_on_floor()
	var from: Vector3 = _player.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (0.1 + GROUND_PROBE), GROUND_MASK, [_player.get_rid()])
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _build_tree(skel: Skeleton3D) -> AnimationNodeBlendTree:
	var root := AnimationNodeBlendTree.new()

	var ground := AnimationNodeBlendSpace2D.new()
	ground.min_space = Vector2(-BLEND_RADIUS, -BLEND_RADIUS)
	ground.max_space = Vector2(BLEND_RADIUS, BLEND_RADIUS)
	ground.add_blend_point(_clip(&"idle"), Vector2.ZERO, -1, &"idle")
	for clip: StringName in SoldierAnimations.ground_points:
		var point: Vector2 = SoldierAnimations.ground_points[clip]
		ground.add_blend_point(_clip(clip), point.normalized() * BLEND_RADIUS, -1, clip)
	root.add_node(&"ground_space", ground)
	root.add_node(&"ground_speed", AnimationNodeTimeScale.new())
	root.connect_node(&"ground_speed", 0, &"ground_space")

	var crouch := AnimationNodeBlendSpace1D.new()
	crouch.min_space = -1.0
	crouch.max_space = 1.0
	crouch.add_blend_point(_clip(&"crouch_left"), -1.0, -1, &"crouch_left")
	crouch.add_blend_point(_clip(&"crouch_idle"), 0.0, -1, &"crouch_idle")
	crouch.add_blend_point(_clip(&"crouch_right"), 1.0, -1, &"crouch_right")
	root.add_node(&"crouch_space", crouch)
	root.add_node(&"crouch_speed", AnimationNodeTimeScale.new())
	root.connect_node(&"crouch_speed", 0, &"crouch_space")

	root.add_node(&"jump_clip", _clip(&"jump_up"))
	root.add_node(&"fall_clip", _clip(&"jump_down"))

	var state := AnimationNodeTransition.new()
	state.xfade_time = STATE_FADE
	for input: String in ["ground", "crouch", "jump", "fall"]:
		state.add_input(input)
	root.add_node(&"state", state)
	root.connect_node(&"state", 0, &"ground_speed")
	root.connect_node(&"state", 1, &"crouch_speed")
	root.connect_node(&"state", 2, &"jump_clip")
	root.connect_node(&"state", 3, &"fall_clip")

	var fire := AnimationNodeBlend2.new()
	fire.filter_enabled = true
	for bone: int in skel.get_bone_count():
		var bone_name: String = skel.get_bone_name(bone)
		if _is_upper_body(bone_name):
			fire.set_filter_path(NodePath("Skeleton3D:" + bone_name), true)
	root.add_node(&"fire_clip", _clip(&"fire"))
	root.add_node(&"fire", fire)
	root.connect_node(&"fire", 0, &"state")
	root.connect_node(&"fire", 1, &"fire_clip")
	root.connect_node(&"output", 0, &"fire")
	return root


static func _clip(clip: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	return node


static func _is_upper_body(bone_name: String) -> bool:
	var short: String = bone_name.trim_prefix(SoldierMesh.BONE_PREFIX)
	if short.begins_with("Right") or short.begins_with("Left"):
		return not (short.contains("Leg") or short.contains("Foot") or short.contains("Toe"))
	return short in UPPER_BODY_BONES

class_name FirstPersonArms
extends Node3D
## Owner only: the rigged PSX arms (assets/models/characters/fp_arms) holding the weapon in
## view. A child of the WeaponHolder, so it shares the view model's space. The arms play an idle
## animation (fists for guns, the knife pose for blades) and ArmsIK bends each arm every frame
## so the fist sits on the shown weapon's grip (recoil, melee swings and swaps included).
## Grips: a "RightHand" / "LeftHand" Marker3D in the weapon scene wins: its position is the
## centre of the fist, its rotation turns the fist (identity = around a pistol grip, rolled about
## the barrel = under a handguard). Without markers they are guessed from the muzzle (long gun:
## support hand on the handguard; short gun: both on the grip).
## A weapon scene's "arms_twist" metadata (degrees) turns the arms about the view's vertical
## axis, left shoulder forward: the bladed stance that lets the support hand reach a handguard.
## WeaponDef.view_hands says which hands are used; an unused arm hangs down out of view.

const ARMS_SCENE: PackedScene = preload("res://assets/models/characters/fp_arms/arms_rig.glb")
## The model faces +Z with its camera bone at this height; turned to face -Z and moved so the
## camera bone sits on the view, then nudged by ARMS_OFFSET (shoulders forward and down) and
## scaled by ARMS_SCALE, so the support hand reaches a rifle's handguard.
const MODEL_EYE_HEIGHT: float = 1.743
const ARMS_OFFSET: Vector3 = Vector3(0.0, -0.15, -0.22)
const ARMS_SCALE: float = 1.15
const GUN_ANIMATION: StringName = &"guard_idle" ## Both hands in fists: holds a grip.
## Blades too: the pack's knife_idle hand is half open, the tight fist closes round the handle.
const KNIFE_ANIMATION: StringName = &"guard_idle"
const POSE_ANIMATION: StringName = &"guard_idle" ## Measured once: grip point and fist rotation.
const RIGHT_POLE: Vector3 = Vector3(0.7, -1.0, 0.35) ## Elbows bend down and outward.
const LEFT_POLE: Vector3 = Vector3(-0.7, -1.0, 0.35)
## An unused arm reaches here (holder space): hanging below the view.
const RIGHT_REST: Vector3 = Vector3(0.32, -0.8, 0.05)
const LEFT_REST: Vector3 = Vector3(-0.32, -0.8, 0.05)
const FINGER_JOINTS: Array[String] = ["f_index.02", "f_middle.02", "f_ring.02", "f_pinky.02"]

const LONG_GUN_REACH: float = 0.25 ## |muzzle z| above this: support hand on the handguard.
const RIGHT_GRIP: Vector3 = Vector3(0.0, -0.07, 0.06)
const SHORT_SUPPORT_GRIP: Vector3 = Vector3(-0.04, -0.085, 0.07)
const DUAL_GRIP: Vector3 = Vector3(0.0, -0.067, 0.155) ## From each pistol's muzzle.
const HANDGUARD_SHARE: float = 0.55 ## Support hand this far toward the muzzle.
const HANDGUARD_DROP: float = -0.035
## Support hand on a handguard: the fist rolled about the barrel (degrees, + = counter-clockwise
## as you look down the barrel) so it holds the gun from below instead of punching it.
const HANDGUARD_ROLL: float = 100.0
const MELEE_SUPPORT_BACK: float = 0.16 ## Two-handed melee: second fist this far down the handle (model units).
const TWIST_SPEED: float = 10.0 ## Per second; how fast the stance turns on a weapon swap.

var _player: Player
var _model: Node3D
var _skeleton: Skeleton3D
var _animation: AnimationPlayer
var _ik: ArmsIK
var _right: ArmsIK.Arm
var _left: ArmsIK.Arm
var _base_transform: Transform3D
var _twist: float = 0.0 ## Radians the arms are turned right now (eases toward the weapon's).


static func create(player: Player) -> FirstPersonArms:
	var arms := FirstPersonArms.new()
	arms._player = player
	arms.name = "FirstPersonArms"
	return arms


func _ready() -> void:
	_model = ARMS_SCENE.instantiate() as Node3D
	_base_transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * ARMS_SCALE),
		Vector3(0.0, -MODEL_EYE_HEIGHT * ARMS_SCALE, 0.0) + ARMS_OFFSET)
	_model.transform = _base_transform
	add_child(_model)
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not node.get_parent() is Skeleton3D:
			geometry.visible = false # The pack's stray helper sphere.
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_animation = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for animation_name: StringName in [GUN_ANIMATION, KNIFE_ANIMATION]:
		_animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	_right = _measure_arm("R")
	_left = _measure_arm("L")
	_ik = ArmsIK.new()
	_ik.arms = [_right, _left]
	_skeleton.add_child(_ik)
	_animation.play(GUN_ANIMATION)


## Bones of one side and its fist measured in POSE_ANIMATION: where the grip is inside the
## hand and how the fist is turned relative to the view (a weapon pointing straight ahead).
func _measure_arm(side: String) -> ArmsIK.Arm:
	var arm := ArmsIK.Arm.new()
	arm.upper = _skeleton.find_bone("upper_arm." + side)
	arm.fore = _skeleton.find_bone("forearm." + side)
	arm.hand = _skeleton.find_bone("hand." + side)
	_animation.play(POSE_ANIMATION)
	_animation.seek(0.0, true)
	var hand: Transform3D = _skeleton.get_bone_global_pose(arm.hand)
	var grip := Vector3.ZERO
	for joint: String in FINGER_JOINTS:
		grip += _skeleton.get_bone_global_pose(_skeleton.find_bone("%s.%s" % [joint, side])).origin
	grip /= FINGER_JOINTS.size()
	arm.grip_local = hand.affine_inverse() * grip
	# Skeleton space -> this node's space (the weapons' space).
	var skeleton_to_holder: Basis = _model.transform.basis * _skeleton_local_basis()
	arm.hand_rotation = (skeleton_to_holder * hand.basis).orthonormalized()
	return arm


func _skeleton_local_basis() -> Basis:
	var basis := Basis.IDENTITY
	var node: Node = _skeleton
	while node != _model:
		basis = (node as Node3D).transform.basis * basis
		node = node.get_parent()
	return basis


func _process(delta: float) -> void:
	var weapon: Weapon = _shown_weapon()
	var hands: WeaponDef.ViewHands = weapon.def.view_hands if weapon != null else WeaponDef.ViewHands.NONE
	_model.visible = hands != WeaponDef.ViewHands.NONE
	if not _model.visible:
		return
	var wanted_twist: float = deg_to_rad(float(weapon.get_meta(&"arms_twist", 0.0)))
	_twist = lerpf(_twist, wanted_twist, minf(TWIST_SPEED * delta, 1.0))
	_model.transform = Transform3D(Basis(Vector3.UP, -_twist)) * _base_transform
	var blade: bool = _held_by_handle(weapon) and hands == WeaponDef.ViewHands.RIGHT
	var wanted: StringName = KNIFE_ANIMATION if blade else GUN_ANIMATION
	if _animation.current_animation != wanted:
		_animation.play(wanted, 0.15)
	_set_arm(_right, weapon, true, true)
	_set_arm(_left, weapon, hands == WeaponDef.ViewHands.BOTH, false)


func _shown_weapon() -> Weapon:
	if not is_instance_valid(_player) or not _player.is_alive:
		return null
	if _player.melee_weapon != null and _player.melee_weapon.visible:
		return _player.melee_weapon
	var weapon: Weapon = _player.current_weapon
	return weapon if weapon != null and weapon.visible else null


func _set_arm(arm: ArmsIK.Arm, weapon: Weapon, holds: bool, right: bool) -> void:
	arm.enabled = true
	var to_global: Transform3D = global_transform
	arm.pole = to_global.basis * (RIGHT_POLE if right else LEFT_POLE)
	if not holds:
		arm.target = to_global * Transform3D(Basis.IDENTITY, RIGHT_REST if right else LEFT_REST)
		return
	var grip: Vector3 = weapon.transform * _grip(weapon, right)
	var hold: Basis = weapon.transform.basis.orthonormalized()
	var model := weapon.get_node_or_null(^"Model") as Node3D
	var marker := weapon.get_node_or_null(^"RightHand" if right else ^"LeftHand") as Node3D
	if _held_by_handle(weapon) and model != null:
		# Blades and hammers: fists around the handle, the blade out past the index finger.
		hold = hold * model.transform.basis.orthonormalized() * Basis(Vector3.RIGHT, -PI * 0.5)
	elif marker != null:
		hold = hold * marker.transform.basis.orthonormalized()
	elif not right and _on_handguard(weapon):
		hold = hold * Basis(Vector3.BACK, deg_to_rad(HANDGUARD_ROLL))
	arm.target = to_global * Transform3D(hold, grip)


## Melee weapons and throwing knives: the model's own axis is the handle.
func _held_by_handle(weapon: Weapon) -> bool:
	return weapon.def.fire_type == WeaponDef.FireType.MELEE or weapon.def.fire_type == WeaponDef.FireType.THROWN


func _on_handguard(weapon: Weapon) -> bool:
	return weapon.get_node_or_null(^"LeftHand") == null and not weapon is DualPistolsWeapon \
		and absf(weapon.muzzle.position.z) > LONG_GUN_REACH


## Grip point in the weapon's own space.
func _grip(weapon: Weapon, right: bool) -> Vector3:
	var marker := weapon.get_node_or_null(^"RightHand" if right else ^"LeftHand") as Node3D
	if marker != null:
		return marker.position
	if weapon is DualPistolsWeapon:
		var muzzle := weapon.get_node_or_null(^"Muzzle" if right else ^"LeftMuzzle") as Node3D
		if muzzle != null:
			return muzzle.position + DUAL_GRIP
	if _held_by_handle(weapon):
		# Melee models: origin = the hand; a second hand further down the handle.
		var model := weapon.get_node_or_null(^"Model") as Node3D
		if model == null:
			return Vector3.ZERO
		return model.position if right else model.position + model.transform.basis * Vector3(0.0, 0.0, MELEE_SUPPORT_BACK)
	if right:
		return RIGHT_GRIP
	if _on_handguard(weapon):
		return Vector3(0.0, HANDGUARD_DROP, weapon.muzzle.position.z * HANDGUARD_SHARE)
	return SHORT_SUPPORT_GRIP

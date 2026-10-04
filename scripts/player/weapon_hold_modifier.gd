class_name WeaponHoldModifier
extends SkeletonModifier3D
## Runs after SpineAimModifier, purely visual. Places the held gun in front of the right
## shoulder, pointing where the player looks, then bends both arms (two-bone IK) so the
## right hand holds the grip and the left hand the fore-end (pistols: both hands on the
## grip). `influence` (SkeletonModifier3D) blends it out for clips that move the gun
## themselves (magazine reload, throw). `tilt` tips the gun up (the reload of guns the clip
## does not fit), `swing` drives a knife slash. SoldierRig reads `gun_transform` to place
## the weapon model.

## Skeleton space: faces +Z, the right side is -X. Offsets are from the right shoulder joint
## in the aim frame (x toward the body's middle, y up, z forward).
const RIFLE_GRIP: Vector3 = Vector3(0.07, -0.17, 0.26)
const PISTOL_GRIP: Vector3 = Vector3(0.17, -0.07, 0.43)
const RIFLE_SUPPORT_SHARE: float = 0.4 ## Fore-end this share of the gun's length ahead of the grip.
const RIFLE_SUPPORT_DROP: float = 0.04
const PISTOL_SUPPORT: Vector3 = Vector3(0.03, -0.035, 0.01) ## Left hand under and beside the right.
const SHORT_GUN: float = 0.45 ## Metres; shorter guns are held like pistols.
const TILT_LIFT: Vector3 = Vector3(0.02, 0.07, -0.08) ## Grip moves up and back at full tilt.
const WRIST_BACK: float = 0.05 ## The wrist joint sits this far behind the palm on the grip.
## Fingers point along the gun, tipped down this much (forward + down * x): the grip hand
## wraps the pistol grip, the support hand lies under the fore-end.
const GRIP_DROOP: float = 0.8
const SUPPORT_DROOP: float = 0.25
## Where the elbows point (skeleton space): down and a little out, not winged up.
const RIGHT_ELBOW: Vector3 = Vector3(-0.45, -1.0, -0.15)
const LEFT_ELBOW: Vector3 = Vector3(0.3, -1.0, 0.0)
## Knife slash, right hand from high outside to low inside (aim frame, from the shoulder).
const SWING_FROM: Vector3 = Vector3(-0.12, 0.18, 0.3)
const SWING_TO: Vector3 = Vector3(0.3, -0.25, 0.45)

var pitch: float = 0.0 ## Radians, positive looks up.
var gun_length: float = 0.9 ## Length of the held world model (0 = nothing in hand).
var tilt: float = 0.0 ## Radians the gun is tipped up (0..~0.7), for reloads.
var swing: float = -1.0 ## Knife slash progress 0..1; below 0 = none.
## Skeleton-space transform for the weapon model (its -Z forward), valid after an update.
var gun_transform: Transform3D = Transform3D.IDENTITY

var _right: PackedInt32Array = PackedInt32Array() ## Arm, ForeArm, Hand.
var _left: PackedInt32Array = PackedInt32Array()


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	if _right.is_empty():
		for part: String in ["Arm", "ForeArm", "Hand"]:
			_right.append(skeleton.find_bone("mixamorig_Right" + part))
			_left.append(skeleton.find_bone("mixamorig_Left" + part))
	var shoulder: Vector3 = skeleton.get_bone_global_pose(_right[0]).origin
	var aim := Basis(Vector3.LEFT, pitch) # Skeleton forward is +Z; looking up tips it toward +Y.
	var short: bool = gun_length < SHORT_GUN
	var grip_offset: Vector3 = PISTOL_GRIP if short else RIFLE_GRIP
	var tilt_share: float = clampf(tilt / 0.7, 0.0, 1.0)
	grip_offset += TILT_LIFT * tilt_share
	var gun_aim: Basis = aim * Basis(Vector3.LEFT, tilt)
	if swing >= 0.0:
		var eased: float = ease(clampf(swing, 0.0, 1.0), -2.0)
		grip_offset = SWING_FROM.lerp(SWING_TO, eased)
		gun_aim = aim * Basis(Vector3.RIGHT, lerpf(-0.6, 0.9, eased)) # Blade swept down through the slash.
	var grip: Vector3 = shoulder + aim * grip_offset
	var forward: Vector3 = gun_aim * Vector3.BACK # +Z.
	gun_transform = Transform3D(gun_aim * Basis(Vector3.UP, PI), grip)
	if gun_length <= 0.0:
		return
	var down: Vector3 = gun_aim * Vector3.DOWN
	_reach(skeleton, _right, grip - forward * WRIST_BACK, (forward + down * GRIP_DROOP).normalized(), RIGHT_ELBOW)
	if swing >= 0.0:
		return # The left hand keeps the clip's pose during a slash.
	var support: Vector3
	if short:
		support = grip + gun_aim * PISTOL_SUPPORT
	else:
		support = grip + forward * gun_length * RIFLE_SUPPORT_SHARE + gun_aim * Vector3.DOWN * RIFLE_SUPPORT_DROP
	_reach(skeleton, _left, support - forward * WRIST_BACK, (forward + down * SUPPORT_DROOP).normalized(), LEFT_ELBOW)


## Two-bone IK: turns the upper arm and forearm so the wrist lands on `target` with the
## elbow bent toward `pole`, then points the fingers along `fingers`.
func _reach(skeleton: Skeleton3D, chain: PackedInt32Array, target: Vector3, fingers: Vector3, pole: Vector3) -> void:
	var upper: Transform3D = skeleton.get_bone_global_pose(chain[0])
	var lower: Transform3D = skeleton.get_bone_global_pose(chain[1])
	var wrist: Vector3 = skeleton.get_bone_global_pose(chain[2]).origin
	var a: float = upper.origin.distance_to(lower.origin)
	var b: float = lower.origin.distance_to(wrist)
	var to_target: Vector3 = target - upper.origin
	var d: float = clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var u: Vector3 = to_target.normalized()
	var v: Vector3 = pole - u * pole.dot(u)
	if v.length_squared() < 1e-6:
		v = Vector3.DOWN - u * Vector3.DOWN.dot(u)
	v = v.normalized()
	var cos_a: float = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow: Vector3 = upper.origin + (u * cos_a + v * sqrt(1.0 - cos_a * cos_a)) * a
	var hand: Vector3 = upper.origin + u * d
	var turn_upper := Quaternion((lower.origin - upper.origin).normalized(), (elbow - upper.origin).normalized())
	var forearm_now: Vector3 = turn_upper * (wrist - lower.origin)
	var turn_lower := Quaternion(forearm_now.normalized(), (hand - elbow).normalized())
	upper.basis = Basis(turn_upper) * upper.basis
	lower.basis = Basis(turn_lower * turn_upper) * lower.basis
	lower.origin = elbow
	_set_global(skeleton, chain[0], upper)
	_set_global(skeleton, chain[1], lower)
	var palm: Transform3D = skeleton.get_bone_global_pose(chain[2])
	var along: Vector3 = palm.basis.y.normalized() # Mixamo bones point down their +Y.
	palm.basis = Basis(Quaternion(along, fingers)) * palm.basis
	_set_global(skeleton, chain[2], palm)


func _set_global(skeleton: Skeleton3D, bone: int, pose: Transform3D) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var local: Transform3D = pose
	if parent >= 0:
		local = skeleton.get_bone_global_pose(parent).affine_inverse() * pose
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())

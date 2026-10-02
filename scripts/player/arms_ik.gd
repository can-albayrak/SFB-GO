class_name ArmsIK
extends SkeletonModifier3D
## Two-bone IK for the first-person arms (child of their Skeleton3D, runs after the idle
## animation): each enabled arm bends at the elbow toward its pole so the hand's grip point
## lands on the target, and the hand takes the target's orientation (times the hand's own
## grip rotation, measured from the fist pose). Targets and poles are set every frame by
## FirstPersonArms, in global space.

class Arm:
	var upper: int = -1
	var fore: int = -1
	var hand: int = -1
	## Grip point (centre of the fist) in the hand bone's own space.
	var grip_local: Vector3 = Vector3.ZERO
	## Hand rotation relative to the target's basis.
	var hand_rotation: Basis = Basis.IDENTITY
	var enabled: bool = false
	var target: Transform3D = Transform3D.IDENTITY
	var pole: Vector3 = Vector3.DOWN ## Direction the elbow bends toward.

const MIN_REACH: float = 0.001

var arms: Array[Arm] = []


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	for arm: Arm in arms:
		if arm.enabled and arm.upper >= 0:
			_solve(skeleton, arm, to_skeleton * arm.target, (to_skeleton.basis * arm.pole).normalized())


func _solve(skeleton: Skeleton3D, arm: Arm, target: Transform3D, pole: Vector3) -> void:
	var upper: Transform3D = skeleton.get_bone_global_pose(arm.upper)
	var elbow_now: Vector3 = skeleton.get_bone_global_pose(arm.fore).origin
	var wrist_now: Vector3 = skeleton.get_bone_global_pose(arm.hand).origin
	var shoulder: Vector3 = upper.origin
	var a: float = shoulder.distance_to(elbow_now)
	var b: float = elbow_now.distance_to(wrist_now)
	var hand_basis: Basis = (target.basis.orthonormalized() * arm.hand_rotation).orthonormalized()
	var wrist: Vector3 = target.origin - hand_basis * arm.grip_local
	var to_wrist: Vector3 = wrist - shoulder
	var reach: float = clampf(to_wrist.length(), absf(a - b) + MIN_REACH, a + b - MIN_REACH)
	var dir: Vector3 = to_wrist.normalized()
	var cos_a: float = clampf((a * a + reach * reach - b * b) / (2.0 * a * reach), -1.0, 1.0)
	var side: Vector3 = pole - dir * dir.dot(pole)
	side = side.normalized() if side.length_squared() > 0.000001 else Vector3.DOWN
	var elbow: Vector3 = shoulder + dir * a * cos_a + side * a * sqrt(1.0 - cos_a * cos_a)

	skeleton.set_bone_global_pose(arm.upper, _aim(upper, elbow_now, elbow))
	var fore: Transform3D = skeleton.get_bone_global_pose(arm.fore)
	var wrist_after: Vector3 = skeleton.get_bone_global_pose(arm.hand).origin
	skeleton.set_bone_global_pose(arm.fore, _aim(fore, wrist_after, shoulder + dir * reach))
	var hand_origin: Vector3 = skeleton.get_bone_global_pose(arm.hand).origin
	skeleton.set_bone_global_pose(arm.hand, Transform3D(hand_basis, hand_origin))


## `pose` turned about its origin so the point `from` (a child joint) moves onto the line to `to`.
func _aim(pose: Transform3D, from: Vector3, to: Vector3) -> Transform3D:
	var old_dir: Vector3 = (from - pose.origin).normalized()
	var new_dir: Vector3 = (to - pose.origin).normalized()
	if old_dir.is_zero_approx() or new_dir.is_zero_approx() or old_dir.is_equal_approx(new_dir):
		return pose
	var turn := Quaternion(old_dir, new_dir)
	return Transform3D(Basis(turn) * pose.basis, pose.origin)

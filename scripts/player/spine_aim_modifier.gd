class_name SpineAimModifier
extends SkeletonModifier3D
## Runs after the animation, purely visual:
## - upright: turns the spine so the head sits over the feet. Hitboxes do not animate, so a
##   clip that leans (the rifle walk leans far forward) would put the drawn head outside
##   the head hitbox; this keeps "aim at the head you see" honest.
## - pitch: bends the spine toward the look pitch, so others see where a player aims.

const SPINE: String = "mixamorig_Spine"
const HEAD: String = "mixamorig_Head"
const BEND_BONES: Array[String] = ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]

var pitch: float = 0.0 ## Radians, positive looks up (like the camera).
var upright: bool = false

var _spine: int = -1
var _head: int = -1
var _bend: PackedInt32Array = PackedInt32Array()


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	if _spine < 0:
		_spine = skeleton.find_bone(SPINE)
		_head = skeleton.find_bone(HEAD)
		for bone_name: String in BEND_BONES:
			_bend.append(skeleton.find_bone(bone_name))
	if upright:
		_straighten(skeleton)
	if not is_zero_approx(pitch):
		_bend_spine(skeleton)


func _straighten(skeleton: Skeleton3D) -> void:
	var spine_pose: Transform3D = skeleton.get_bone_global_pose(_spine)
	var to_head: Vector3 = skeleton.get_bone_global_pose(_head).origin - spine_pose.origin
	var length: float = to_head.length()
	var off_centre := Vector2(spine_pose.origin.x, spine_pose.origin.z)
	if length < 0.01 or off_centre.length() >= length:
		return
	# Skeleton space: the player's origin (and the head hitbox) is on the Y axis.
	var target := Vector3(0.0, spine_pose.origin.y + sqrt(length * length - off_centre.length_squared()), 0.0)
	var turn := Quaternion(to_head / length, (target - spine_pose.origin).normalized())
	_rotate_global(skeleton, _spine, turn)


func _bend_spine(skeleton: Skeleton3D) -> void:
	# The skeleton faces +Z, so looking up tips the chest back around -X.
	var turn := Quaternion(Vector3.LEFT, pitch / _bend.size())
	for bone: int in _bend:
		_rotate_global(skeleton, bone, turn)


## Applies a skeleton-space rotation to a bone around its own joint.
func _rotate_global(skeleton: Skeleton3D, bone: int, turn: Quaternion) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_rotation: Quaternion = Quaternion.IDENTITY
	if parent >= 0:
		parent_rotation = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (parent_rotation.inverse() * turn * parent_rotation * local).normalized())

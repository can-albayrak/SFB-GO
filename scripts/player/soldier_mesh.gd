class_name SoldierMesh
extends RefCounted
## Low-poly placeholder soldier skinned to the Mixamo skeleton: every box follows one bone
## rigidly (PS2 style). Same look and colours as the old static soldier.glb, but it bends
## with the animations. Built once, shared by every player.

const SKIN: Color = Color(0.865, 0.7548, 0.6652)
const FATIGUE: Color = Color(0.6343, 0.65, 0.5564)
const VEST: Color = Color(0.3656, 0.3811, 0.3318)
const BOOTS: Color = Color(0.3492, 0.3133, 0.2717)
const BLACK: Color = Color(0.2478, 0.2478, 0.2478)
const BERET: Color = Color(0.6343, 0.2478, 0.2478)

## [bone, centre, size, colour] in the skeleton's rest space (T-pose, metres, facing +Z,
## the soldier's right side is -X). Right-side parts are mirrored to the left.
const SIDE_PARTS: Array = [
	["RightUpLeg", Vector3(-0.082, 0.75, -0.014), Vector3(0.17, 0.46, 0.19), FATIGUE],
	["RightLeg", Vector3(-0.082, 0.31, -0.03), Vector3(0.15, 0.46, 0.16), FATIGUE],
	["RightLeg", Vector3(-0.082, 0.5, 0.06), Vector3(0.17, 0.13, 0.05), VEST], # knee pad
	["RightFoot", Vector3(-0.082, 0.06, 0.04), Vector3(0.14, 0.12, 0.28), BOOTS],
	["RightArm", Vector3(-0.29, 1.44, -0.07), Vector3(0.29, 0.12, 0.13), FATIGUE],
	["RightArm", Vector3(-0.2, 1.5, -0.07), Vector3(0.15, 0.06, 0.16), VEST], # shoulder pad
	["RightForeArm", Vector3(-0.57, 1.44, -0.07), Vector3(0.29, 0.1, 0.1), FATIGUE],
	["RightHand", Vector3(-0.77, 1.435, -0.065), Vector3(0.13, 0.08, 0.1), BLACK], # glove
]
const CENTRE_PARTS: Array = [
	["Hips", Vector3(0.0, 0.95, 0.0), Vector3(0.38, 0.2, 0.23), FATIGUE],
	["Hips", Vector3(0.0, 1.03, 0.0), Vector3(0.4, 0.06, 0.25), BLACK], # belt
	["Spine", Vector3(0.0, 1.14, 0.0), Vector3(0.37, 0.18, 0.22), FATIGUE],
	["Spine1", Vector3(0.0, 1.24, -0.012), Vector3(0.4, 0.14, 0.25), FATIGUE],
	["Spine2", Vector3(0.0, 1.34, -0.025), Vector3(0.46, 0.3, 0.3), VEST], # plate carrier
	["Spine2", Vector3(0.0, 1.35, -0.19), Vector3(0.3, 0.28, 0.06), VEST], # back panel
	["Spine1", Vector3(-0.13, 1.22, 0.13), Vector3(0.1, 0.11, 0.05), VEST], # mag pouches
	["Spine1", Vector3(0.0, 1.22, 0.13), Vector3(0.1, 0.11, 0.05), VEST],
	["Spine1", Vector3(0.13, 1.22, 0.13), Vector3(0.1, 0.11, 0.05), VEST],
	["Neck", Vector3(0.0, 1.54, -0.035), Vector3(0.11, 0.12, 0.11), SKIN],
	["Head", Vector3(0.0, 1.7, 0.0), Vector3(0.22, 0.24, 0.24), SKIN],
	["Head", Vector3(0.0, 1.72, 0.125), Vector3(0.2, 0.045, 0.02), BLACK], # sunglasses
	["Head", Vector3(0.0, 1.835, -0.01), Vector3(0.27, 0.05, 0.27), BERET],
]
const BONE_PREFIX: String = "mixamorig_"

static var _mesh: ArrayMesh


static func create(skeleton: Skeleton3D) -> MeshInstance3D:
	if _mesh == null:
		_mesh = _build(skeleton)
	var instance := MeshInstance3D.new()
	instance.name = "Body"
	instance.mesh = _mesh
	instance.skin = skeleton.create_skin_from_rest_transforms()
	return instance


static func _build(skeleton: Skeleton3D) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in SIDE_PARTS:
		_add_box(tool, skeleton, part[0], part[1], part[2], part[3])
		var mirrored: Vector3 = part[1]
		mirrored.x = -mirrored.x
		_add_box(tool, skeleton, (part[0] as String).replace("Right", "Left"), mirrored, part[2], part[3])
	for part: Array in CENTRE_PARTS:
		_add_box(tool, skeleton, part[0], part[1], part[2], part[3])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	tool.set_material(material)
	return tool.commit()


static func _add_box(tool: SurfaceTool, skeleton: Skeleton3D, bone_name: String, centre: Vector3, size: Vector3, color: Color) -> void:
	var bone: int = skeleton.find_bone(BONE_PREFIX + bone_name)
	assert(bone >= 0, "Soldier mesh: no bone " + bone_name)
	var half: Vector3 = size * 0.5
	for axis: int in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			if side < 0.0:
				var swap: Vector3 = u
				u = v
				v = swap
			var face: Vector3 = centre + normal * half
			var corners: Array[Vector3] = [
				face + (-u - v) * half, face + (u - v) * half, face + (u + v) * half, face + (-u + v) * half,
			]
			for index: int in [0, 2, 1, 0, 3, 2]:
				tool.set_color(color)
				tool.set_normal(normal)
				tool.set_bones(PackedInt32Array([bone, 0, 0, 0]))
				tool.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				tool.add_vertex(corners[index])

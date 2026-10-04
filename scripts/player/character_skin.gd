class_name CharacterSkin
extends RefCounted
## Skins a static character model (CharacterModelDef) to the Mixamo skeleton at runtime,
## once per model: the skeleton is first bent into the model's own pose (arms down, legs
## apart), then every vertex follows its nearest bones (distance to the bone measured
## against how thick that body part is). Each separate piece of the mesh (PS2 models are
## built from loose parts: sleeves, jacket, legs) first picks whether it is body, arm or
## leg, and its vertices only follow bones of that kind, so a jacket hem next to a hanging
## hand never stretches after the arm. Good enough for low-poly PS2 models; no Blender.

const PREFIX: String = "mixamorig_"
## Bone short name -> [child joint that ends it, body part radius in metres].
const BONES: Dictionary = {
	"Hips": ["Spine", 0.15],
	"Spine": ["Spine1", 0.16],
	"Spine1": ["Spine2", 0.16],
	"Spine2": ["Neck", 0.17],
	"Neck": ["Head", 0.06],
	"Head": ["HeadTop_End", 0.11],
	"LeftShoulder": ["LeftArm", 0.07],
	"LeftArm": ["LeftForeArm", 0.06],
	"LeftForeArm": ["LeftHand", 0.05],
	"LeftHand": ["LeftHandMiddle4", 0.05],
	"LeftUpLeg": ["LeftLeg", 0.09],
	"LeftLeg": ["LeftFoot", 0.07],
	"LeftFoot": ["LeftToeBase", 0.06],
	"LeftToeBase": ["LeftToe_End", 0.05],
}
const ARM_PARTS: Array[String] = ["Arm", "ForeArm", "Hand"]
const LEG_PARTS: Array[String] = ["UpLeg", "Leg", "Foot", "ToeBase"]
## Body bones an arm or leg piece may still blend into where it meets the body.
const ARM_ROOTS: Array[String] = ["Shoulder", "Spine2"]
const LEG_ROOTS: Array[String] = ["Hips"]
enum Kind { BODY, ARM, LEG }
const WEIGHT_POWER: float = 4.0
const MIN_SECOND_WEIGHT: float = 0.08
const WELD_PRECISION: float = 10000.0 ## Vertices this close (1/x m) count as one when finding pieces.

static var _meshes: Dictionary = {} ## CharacterModelDef -> [ArrayMesh, Array[Transform3D] fitted pose]


static func create(def: CharacterModelDef, skeleton: Skeleton3D) -> MeshInstance3D:
	if not _meshes.has(def):
		_meshes[def] = _build(def, skeleton)
	var built: Array = _meshes[def]
	var instance := MeshInstance3D.new()
	instance.name = "Body"
	instance.mesh = built[0]
	var skin := Skin.new()
	var fitted: Array[Transform3D] = built[1]
	for bone: int in skeleton.get_bone_count():
		skin.add_bind(bone, fitted[bone].affine_inverse())
	instance.skin = skin
	return instance


static func _build(def: CharacterModelDef, skeleton: Skeleton3D) -> Array:
	var fitted: Array[Transform3D] = _fit_pose(def, skeleton)
	var source: Node3D = def.scene.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	var placement: Transform3D = _placement(def, source, meshes)

	var segments: Array = _segments(skeleton, fitted)
	var result := ArrayMesh.new()
	for mesh_instance: MeshInstance3D in meshes:
		var to_skeleton: Transform3D = placement * _transform_in(source, mesh_instance)
		for surface: int in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			bones.resize(vertices.size() * 4)
			weights.resize(vertices.size() * 4)
			for i: int in vertices.size():
				vertices[i] = to_skeleton * vertices[i]
				if i < normals.size():
					normals[i] = (to_skeleton.basis * normals[i]).normalized()
			var pieces: PackedInt32Array = _pieces(vertices, arrays[Mesh.ARRAY_INDEX])
			var piece_kinds: Dictionary = _piece_kinds(vertices, pieces, segments)
			for i: int in vertices.size():
				_weigh(vertices[i], segments, piece_kinds[pieces[i]], bones, weights, i * 4)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			if not normals.is_empty():
				arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null # Tangents would need turning too; the PS2 look needs none.
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material: Material = mesh_instance.get_active_material(surface)
			if material != null:
				result.surface_set_material(result.get_surface_count() - 1, material)
	source.free()
	return [result, fitted]


## Scale, turn and move the model so it stands on y = 0, centred, facing +Z, `height` tall.
static func _placement(def: CharacterModelDef, source: Node3D, meshes: Array[MeshInstance3D]) -> Transform3D:
	var turn := Transform3D(Basis(Vector3.UP, deg_to_rad(def.yaw_degrees)), Vector3.ZERO)
	var low := Vector3.INF
	var high := -Vector3.INF
	for mesh_instance: MeshInstance3D in meshes:
		var xf: Transform3D = turn * _transform_in(source, mesh_instance)
		for surface: int in mesh_instance.mesh.get_surface_count():
			for vertex: Vector3 in mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = xf * vertex
				low = low.min(p)
				high = high.max(p)
	var scale: float = def.height / (high.y - low.y)
	var centre := Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), -centre * scale) * turn


static func _transform_in(root: Node3D, node: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != root and parent is Node3D:
		xf = (parent as Node3D).transform * xf
		parent = parent.get_parent()
	return xf


## Global bone transforms of the rest pose bent toward def.fit_points (skeleton space).
static func _fit_pose(def: CharacterModelDef, skeleton: Skeleton3D) -> Array[Transform3D]:
	var targets: Dictionary = {}
	for short: String in def.fit_points:
		var point: Vector3 = def.fit_points[short]
		targets[skeleton.find_bone(PREFIX + short)] = point
		targets[skeleton.find_bone(PREFIX + short.replace("Left", "Right"))] = Vector3(-point.x, point.y, point.z)
	var poses: Array[Transform3D] = []
	poses.resize(skeleton.get_bone_count())
	for bone: int in skeleton.get_bone_count():
		var parent: int = skeleton.get_bone_parent(bone)
		var pose: Transform3D = skeleton.get_bone_rest(bone)
		if parent >= 0:
			pose = poses[parent] * pose
		if targets.has(bone):
			var child: int = _end_joint(skeleton, bone)
			var reach: Vector3 = (pose * skeleton.get_bone_rest(child).origin) - pose.origin
			var wanted: Vector3 = (targets[bone] as Vector3) - pose.origin
			var turn := Quaternion(reach.normalized(), wanted.normalized())
			pose.basis = Basis(turn) * pose.basis
		poses[bone] = pose
	return poses


## The joint that ends a bone (BONES table, else its first child).
static func _end_joint(skeleton: Skeleton3D, bone: int) -> int:
	var name: String = skeleton.get_bone_name(bone).trim_prefix(PREFIX)
	var key: String = name.replace("Right", "Left")
	if BONES.has(key):
		var side: String = "Right" if name.begins_with("Right") else "Left"
		return skeleton.find_bone(PREFIX + (BONES[key][0] as String).replace("Left", side))
	var children: PackedInt32Array = skeleton.get_bone_children(bone)
	return children[0] if not children.is_empty() else bone


## [bone, start, end, radius, kind, may root an arm, may root a leg] for every weighted bone.
static func _segments(skeleton: Skeleton3D, poses: Array[Transform3D]) -> Array:
	var segments: Array = []
	for short: String in BONES:
		var sides: Array[String] = [short]
		if short.begins_with("Left"):
			sides.append(short.replace("Left", "Right"))
		for name: String in sides:
			var bone: int = skeleton.find_bone(PREFIX + name)
			var info: Array = BONES[short]
			var end_bone: int = _end_joint(skeleton, bone)
			var kind: Kind = Kind.BODY
			var part: String = name.trim_prefix("Left").trim_prefix("Right")
			if part in ARM_PARTS:
				kind = Kind.ARM
			elif part in LEG_PARTS:
				kind = Kind.LEG
			segments.append([bone, poses[bone].origin, poses[end_bone].origin, info[1], kind, part in ARM_ROOTS, part in LEG_ROOTS])
	return segments


## Piece id per vertex: vertices joined by triangles (after welding equal positions).
static func _pieces(vertices: PackedVector3Array, indices: Variant) -> PackedInt32Array:
	var welded: Dictionary = {}
	var ids := PackedInt32Array()
	ids.resize(vertices.size())
	for i: int in vertices.size():
		var key: Vector3i = Vector3i((vertices[i] * WELD_PRECISION).round())
		if not welded.has(key):
			welded[key] = welded.size()
		ids[i] = welded[key]
	var parent := PackedInt32Array()
	parent.resize(welded.size())
	for i: int in parent.size():
		parent[i] = i
	var triangles: PackedInt32Array = indices if indices is PackedInt32Array else PackedInt32Array()
	if triangles.is_empty():
		triangles.resize(vertices.size())
		for i: int in vertices.size():
			triangles[i] = i
	for t: int in range(0, triangles.size() - 2, 3):
		var a: int = _root(parent, ids[triangles[t]])
		parent[a] = _root(parent, ids[triangles[t + 1]])
		parent[_root(parent, ids[triangles[t + 1]])] = _root(parent, ids[triangles[t + 2]])
	for i: int in vertices.size():
		ids[i] = _root(parent, ids[i])
	return ids


static func _root(parent: PackedInt32Array, at: int) -> int:
	while parent[at] != at:
		parent[at] = parent[parent[at]]
		at = parent[at]
	return at


## Piece id -> Kind: what its middle point is closest to.
static func _piece_kinds(vertices: PackedVector3Array, pieces: PackedInt32Array, segments: Array) -> Dictionary:
	var sums: Dictionary = {}
	var counts: Dictionary = {}
	for i: int in vertices.size():
		sums[pieces[i]] = (sums.get(pieces[i], Vector3.ZERO) as Vector3) + vertices[i]
		counts[pieces[i]] = (counts.get(pieces[i], 0) as int) + 1
	var kinds: Dictionary = {}
	for piece: int in sums:
		var centre: Vector3 = (sums[piece] as Vector3) / float(counts[piece])
		var best: float = INF
		for segment: Array in segments:
			var score: float = _score(centre, segment)
			if score < best:
				best = score
				kinds[piece] = segment[4]
	return kinds


static func _score(p: Vector3, segment: Array) -> float:
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(p, segment[1], segment[2])
	return p.distance_to(closest) / (segment[3] as float)


static func _weigh(p: Vector3, segments: Array, kind: Kind, bones: PackedInt32Array, weights: PackedFloat32Array, at: int) -> void:
	var best: Array = [[-1, INF], [-1, INF]]
	for segment: Array in segments:
		var allowed: bool = segment[4] == kind
		if kind == Kind.ARM and segment[5]:
			allowed = true
		elif kind == Kind.LEG and segment[6]:
			allowed = true
		if not allowed:
			continue
		var score: float = _score(p, segment)
		if score < best[0][1]:
			best[1] = best[0]
			best[0] = [segment[0], score]
		elif score < best[1][1]:
			best[1] = [segment[0], score]
	var w0: float = 1.0 / pow(maxf(best[0][1], 0.01), WEIGHT_POWER)
	var w1: float = 1.0 / pow(maxf(best[1][1], 0.01), WEIGHT_POWER) if best[1][0] >= 0 else 0.0
	var total: float = w0 + w1
	w0 /= total
	w1 /= total
	if w1 < MIN_SECOND_WEIGHT:
		w0 = 1.0
		w1 = 0.0
	bones[at] = best[0][0]
	bones[at + 1] = maxi(best[1][0], 0)
	weights[at] = w0
	weights[at + 1] = w1

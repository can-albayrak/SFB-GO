class_name FirstPersonArms
extends Node3D
## Owner only: the first-person hands holding the weapon in view (hvarley's "Rigged Low Poly FPS
## Hands", assets/models/characters/fp_hands). A child of the WeaponHolder, so it shares the view
## model's space. The model is two forearms already posed round a rifle: the right fist on the
## pistol grip, the left hand under the handguard. Each forearm is placed on its own so that its
## grip point lands on the shown weapon's grip and its pose turns with the weapon (recoil, melee
## swings, throws and swaps included); the fingers never change, so the grip always looks held.
## Grips: a "RightHand" / "LeftHand" Marker3D in the weapon scene wins: its position is the centre
## of the hand's hold, its rotation turns the hand (identity = the model's own rifle hold: right
## round a pistol grip, left under a handguard). Without markers they are guessed from the muzzle.
## Melee weapons and throwing knives: the right fist holds the model's handle (model -Z = blade).
## Dual pistols: the left gun is held by a mirrored copy of the right hand.
## WeaponDef.view_hands says which hands are used; an unused hand is hidden.

const HANDS_SCENE: PackedScene = preload("res://assets/models/characters/fp_hands/fp_hands.glb")
const RIGHT_ARMATURE: String = "Armature_002"
const LEFT_ARMATURE: String = "Armature_001"
const MODEL_GUN_NODES: Array[String] = ["Cube_0_033", "Cube_0_113"] ## The model's own placeholder rifle.
## Centre of each hand's hold in the model (turned to face -Z, metres): read off side and top
## views with a scale grid.
const RIGHT_HOLD: Vector3 = Vector3(0.0, -0.005, -0.215)
const LEFT_HOLD: Vector3 = Vector3(0.0, 0.1, -0.515)

## Saul Goodman's arms: the forearm (weighted to the first bone) is drawn as his dark suit
## sleeve, a white shirt cuff at the wrist, the hand keeps the model's skin.
const SLEEVE_BONE_PREFIX: String = "Bone_0" ## Bone_01 / Bone_020: the forearm bone of each arm.
const SUIT_COLOR: Color = Color(0.11, 0.12, 0.17)
const CUFF_COLOR: Color = Color(0.85, 0.86, 0.88)
const SLEEVE_SHADER: String = """
shader_type spatial;
render_mode diffuse_lambert_wrap, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec3 suit_color : source_color;
uniform vec3 cuff_color : source_color;
uniform float self_light = 0.5;
void fragment() {
	vec3 skin = texture(albedo_texture, UV).rgb;
	float sleeve = smoothstep(0.45, 0.6, COLOR.r);
	float cuff = smoothstep(0.35, 0.5, COLOR.r) * (1.0 - sleeve);
	ALBEDO = mix(mix(skin, cuff_color, cuff), suit_color * (0.75 + 0.5 * skin.r), sleeve);
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(self_light);
}
"""

## Light reaching the hands' shadow side (wrapped diffuse + this much backlight), so a forearm
## turned away from the sun is not a black shape.
const SELF_LIGHT: float = 0.5

## Blades: the fist is turned about the handle so the forearm points this way (holder space:
## back, down and to the right, out of the lower right corner) whatever angle the blade is at.
const BLADE_FOREARM: Vector3 = Vector3(0.45, -0.55, 0.7)
## The right forearm's direction from the hold point toward the elbow, in hold space (measured).
const RIGHT_FOREARM: Vector3 = Vector3(0.37, -0.32, 0.87)
const BLADE_TURN_STEPS: int = 72

const LONG_GUN_REACH: float = 0.25 ## |muzzle z| above this: support hand on the handguard.
const RIGHT_GRIP: Vector3 = Vector3(0.0, -0.05, 0.05)
const DUAL_GRIP: Vector3 = Vector3(0.0, -0.067, 0.155) ## From each pistol's muzzle.
const HANDGUARD_SHARE: float = 0.45 ## Support hand this far toward the muzzle.
const MELEE_SUPPORT_BACK: float = 0.16 ## Two-handed melee: second fist this far down the handle (model units).

var _player: Player
var _right: Node3D
var _left: Node3D
var _left_pistol: Node3D ## Mirrored right hand for the left gun of the dual pistols.
## Each hand's armature in hold space: the transform that puts its hold point at the origin
## with the model's rifle pointing along -Z.
var _right_from_hold: Transform3D
var _left_from_hold: Transform3D
var _mirror_from_hold: Transform3D
## Blade turn (radians about the handle) per weapon, found once at its rest pose.
var _blade_turns: Dictionary[Weapon, float] = {}


static func create(player: Player) -> FirstPersonArms:
	var arms := FirstPersonArms.new()
	arms._player = player
	arms.name = "FirstPersonArms"
	return arms


func _ready() -> void:
	var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) # The model's rifle points +Z.
	var model := HANDS_SCENE.instantiate() as Node3D
	add_child(model)
	_right = _take_armature(model, RIGHT_ARMATURE)
	_left = _take_armature(model, LEFT_ARMATURE)
	_right_from_hold = Transform3D(Basis.IDENTITY, -RIGHT_HOLD) * turn * _right.transform
	_left_from_hold = Transform3D(Basis.IDENTITY, -LEFT_HOLD) * turn * _left.transform
	model.queue_free()
	var mirror_model := HANDS_SCENE.instantiate() as Node3D
	add_child(mirror_model)
	_left_pistol = _take_armature(mirror_model, RIGHT_ARMATURE)
	mirror_model.queue_free()
	_mirror_from_hold = Transform3D(Basis.FLIP_X, Vector3.ZERO) * _right_from_hold
	for hand: Node3D in [_right, _left, _left_pistol]:
		for node: Node in hand.find_children("*", "MeshInstance3D", true, false):
			_light_up(node as MeshInstance3D)


func _light_up(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sleeve_binds: Dictionary = _sleeve_binds(mesh)
	var dressed := ArrayMesh.new()
	for surface: int in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var original := mesh.get_active_material(surface) as StandardMaterial3D
		if arrays[Mesh.ARRAY_BONES] != null and not sleeve_binds.is_empty():
			arrays[Mesh.ARRAY_COLOR] = _sleeve_colors(arrays, sleeve_binds)
		dressed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if original == null:
			continue
		var shader := Shader.new()
		shader.code = SLEEVE_SHADER
		var lit := ShaderMaterial.new()
		lit.shader = shader
		lit.set_shader_parameter(&"albedo_texture", original.albedo_texture)
		lit.set_shader_parameter(&"suit_color", SUIT_COLOR if arrays[Mesh.ARRAY_COLOR] != null else Color.WHITE)
		lit.set_shader_parameter(&"cuff_color", CUFF_COLOR)
		lit.set_shader_parameter(&"self_light", SELF_LIGHT) # Light wraps round into the shadow side.
		dressed.surface_set_material(surface, lit)
	mesh.mesh = dressed
	for surface: int in mesh.get_surface_override_material_count():
		mesh.set_surface_override_material(surface, null)


## Skin bind indices of the forearm bone (the sleeve).
func _sleeve_binds(mesh: MeshInstance3D) -> Dictionary:
	var binds: Dictionary = {}
	var skin: Skin = mesh.skin
	var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
	if skin == null:
		return binds
	for bind: int in skin.get_bind_count():
		var bone_name: String = String(skin.get_bind_name(bind))
		if bone_name.is_empty() and skeleton != null and skin.get_bind_bone(bind) >= 0:
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(bind))
		if bone_name.begins_with(SLEEVE_BONE_PREFIX):
			binds[bind] = true
	return binds


## Vertex colour red = how much the vertex follows the forearm (1 = sleeve, 0 = hand).
func _sleeve_colors(arrays: Array, sleeve_binds: Dictionary) -> PackedColorArray:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per_vertex: int = bones.size() / maxi(count, 1)
	var colors := PackedColorArray()
	colors.resize(count)
	for i: int in count:
		var share: float = 0.0
		for k: int in per_vertex:
			if sleeve_binds.has(bones[i * per_vertex + k]):
				share += weights[i * per_vertex + k]
		colors[i] = Color(share, 0.0, 0.0, 1.0)
	return colors


## Moves one forearm out of the imported model into this node, keeping where it was.
func _take_armature(model: Node3D, armature_name: String) -> Node3D:
	var armature := model.find_child(armature_name, true, false) as Node3D
	var placed: Transform3D = model.global_transform.affine_inverse() * armature.global_transform
	armature.get_parent().remove_child(armature)
	add_child(armature)
	armature.transform = placed
	return armature


func _process(_delta: float) -> void:
	var weapon: Weapon = _shown_weapon()
	var hands: WeaponDef.ViewHands = weapon.def.view_hands if weapon != null else WeaponDef.ViewHands.NONE
	var dual: bool = weapon is DualPistolsWeapon
	_right.visible = hands != WeaponDef.ViewHands.NONE
	_left.visible = hands == WeaponDef.ViewHands.BOTH and not dual
	_left_pistol.visible = hands == WeaponDef.ViewHands.BOTH and dual
	if not _right.visible:
		return
	_right.transform = _hold(weapon, true) * _right_from_hold
	if _left.visible:
		_left.transform = _hold(weapon, false) * _left_from_hold
	if _left_pistol.visible:
		_left_pistol.transform = _hold(weapon, false) * _mirror_from_hold


func _shown_weapon() -> Weapon:
	if not is_instance_valid(_player) or not _player.is_alive:
		return null
	if _player.melee_weapon != null and _player.melee_weapon.visible:
		return _player.melee_weapon
	var weapon: Weapon = _player.current_weapon
	return weapon if weapon != null and weapon.visible else null


## Where one hand's hold point sits and how it is turned, in this node's (the holder's) space.
func _hold(weapon: Weapon, right: bool) -> Transform3D:
	var grip: Vector3 = weapon.transform * _grip(weapon, right)
	var hold: Basis = weapon.transform.basis.orthonormalized()
	var model := weapon.get_node_or_null(^"Model") as Node3D
	var marker := weapon.get_node_or_null(^"RightHand" if right else ^"LeftHand") as Node3D
	if _held_by_handle(weapon) and model != null:
		# Blades and hammers: the fist round the handle, the blade out past the thumb and index.
		hold = hold * model.transform.basis.orthonormalized() * Basis(Vector3.RIGHT, -PI * 0.5)
		if not _blade_turns.has(weapon):
			_blade_turns[weapon] = _best_blade_turn(hold)
		hold = hold * Basis(Vector3.UP, _blade_turns[weapon])
	elif marker != null:
		hold = hold * marker.transform.basis.orthonormalized()
	return Transform3D(hold, grip)


## Turn about the handle (the hold's Y) that points the forearm closest to BLADE_FOREARM.
func _best_blade_turn(hold: Basis) -> float:
	var wanted: Vector3 = BLADE_FOREARM.normalized()
	var best: float = 0.0
	var best_dot: float = -INF
	for i: int in BLADE_TURN_STEPS:
		var turn: float = TAU * i / BLADE_TURN_STEPS
		var dot: float = (hold * Basis(Vector3.UP, turn) * RIGHT_FOREARM.normalized()).dot(wanted)
		if dot > best_dot:
			best_dot = dot
			best = turn
	return best


## Melee weapons and throwing knives: the model's own axis is the handle.
func _held_by_handle(weapon: Weapon) -> bool:
	return weapon.def.fire_type == WeaponDef.FireType.MELEE or weapon.def.fire_type == WeaponDef.FireType.THROWN


## Hold point in the weapon's own space.
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
	if right or absf(weapon.muzzle.position.z) <= LONG_GUN_REACH:
		return RIGHT_GRIP
	return Vector3(0.0, 0.0, weapon.muzzle.position.z * HANDGUARD_SHARE)

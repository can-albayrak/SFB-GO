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

## Light reaching the hands' shadow side (wrapped diffuse + this much backlight), so a forearm
## turned away from the sun is not a black shape.
const SELF_LIGHT: float = 0.5

## Fist turned about a blade's handle (degrees), so the forearm comes up from below the view.
const BLADE_TURN: float = -90.0

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
	for surface: int in mesh.get_surface_override_material_count():
		var material := mesh.get_active_material(surface) as StandardMaterial3D
		if material == null:
			continue
		var lit := material.duplicate() as StandardMaterial3D
		lit.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP # Light wraps round into the shadow side.
		lit.backlight_enabled = true
		lit.backlight = Color(SELF_LIGHT, SELF_LIGHT, SELF_LIGHT)
		mesh.set_surface_override_material(surface, lit)


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
		hold = hold * model.transform.basis.orthonormalized() * Basis(Vector3.RIGHT, -PI * 0.5) 			* Basis(Vector3.UP, deg_to_rad(BLADE_TURN))
	elif marker != null:
		hold = hold * marker.transform.basis.orthonormalized()
	return Transform3D(hold, grip)


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

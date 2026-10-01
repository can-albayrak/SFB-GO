class_name FirstPersonArms
extends Node3D
## Owner only: gloved hands and sleeves holding the weapon in view (placeholder boxes until
## stage 8 models). A child of the WeaponHolder, so it shares the view model's space; every
## frame the hands snap to the shown weapon (recoil, melee swings and swaps included) and the
## forearms run from off-screen elbows to the wrists.
## Grips: a "RightHand" / "LeftHand" Marker3D in the weapon scene wins; otherwise they are
## guessed from the muzzle (long gun: support hand on the handguard; short gun: both on the grip).
## WeaponDef.view_hands says which hands are used at all.

const GLOVE_SIZE: Vector3 = Vector3(0.075, 0.07, 0.11)
const SLEEVE_WIDTH: float = 0.085
const WRIST_BACK: float = 0.05 ## Forearm starts this far behind the glove centre.
const RIGHT_ELBOW: Vector3 = Vector3(0.1, -0.32, 0.3) ## From the right wrist.
const LEFT_ELBOW: Vector3 = Vector3(-0.12, -0.32, 0.26) ## From the left wrist.
const LONG_GUN_REACH: float = 0.25 ## |muzzle z| above this: support hand on the handguard.
const RIGHT_GRIP: Vector3 = Vector3(0.0, -0.07, 0.06)
const SHORT_SUPPORT_GRIP: Vector3 = Vector3(-0.04, -0.085, 0.07)
const DUAL_GRIP: Vector3 = Vector3(0.0, -0.085, 0.13) ## From each pistol's muzzle.
const HANDGUARD_SHARE: float = 0.55 ## Support hand this far toward the muzzle.
const HANDGUARD_DROP: float = -0.035

const SLEEVE_COLOR: Color = Color(0.36, 0.38, 0.27)
const GLOVE_COLOR: Color = Color(0.06, 0.06, 0.06)

var _player: Player
var _gloves: Array[MeshInstance3D] = []
var _sleeves: Array[MeshInstance3D] = []


static func create(player: Player) -> FirstPersonArms:
	var arms := FirstPersonArms.new()
	arms._player = player
	arms.name = "FirstPersonArms"
	return arms


func _ready() -> void:
	var sleeve_material := _material(SLEEVE_COLOR)
	var glove_material := _material(GLOVE_COLOR)
	for i: int in 2:
		var glove := _box(GLOVE_SIZE, glove_material)
		add_child(glove)
		_gloves.append(glove)
		var sleeve := _box(Vector3(SLEEVE_WIDTH, SLEEVE_WIDTH, 1.0), sleeve_material)
		add_child(sleeve)
		_sleeves.append(sleeve)


func _process(_delta: float) -> void:
	var weapon: Weapon = _shown_weapon()
	var hands: WeaponDef.ViewHands = weapon.def.view_hands if weapon != null else WeaponDef.ViewHands.NONE
	_set_arm(0, weapon, hands != WeaponDef.ViewHands.NONE, true)
	_set_arm(1, weapon, hands == WeaponDef.ViewHands.BOTH, false)


func _shown_weapon() -> Weapon:
	if not is_instance_valid(_player) or not _player.is_alive:
		return null
	if _player.melee_weapon != null and _player.melee_weapon.visible:
		return _player.melee_weapon
	var weapon: Weapon = _player.current_weapon
	return weapon if weapon != null and weapon.visible else null


## Arm 0 = right, 1 = left.
func _set_arm(index: int, weapon: Weapon, shown: bool, right: bool) -> void:
	_gloves[index].visible = shown
	_sleeves[index].visible = shown
	if not shown:
		return
	var grip: Vector3 = weapon.transform * _grip(weapon, right)
	var hand_basis: Basis = weapon.transform.basis.orthonormalized()
	_gloves[index].transform = Transform3D(hand_basis, grip)
	var wrist: Vector3 = grip + hand_basis.z * WRIST_BACK
	var elbow: Vector3 = wrist + (RIGHT_ELBOW if right else LEFT_ELBOW)
	var span: Vector3 = wrist - elbow
	var look: Basis = Basis.looking_at(span.normalized(), Vector3.UP)
	_sleeves[index].transform = Transform3D(look * Basis.from_scale(Vector3(1.0, 1.0, span.length())), (wrist + elbow) * 0.5)


## Grip point in the weapon's own space.
func _grip(weapon: Weapon, right: bool) -> Vector3:
	var marker := weapon.get_node_or_null(^"RightHand" if right else ^"LeftHand") as Node3D
	if marker != null:
		return marker.position
	if weapon is DualPistolsWeapon:
		var muzzle := weapon.get_node_or_null(^"Muzzle" if right else ^"LeftMuzzle") as Node3D
		if muzzle != null:
			return muzzle.position + DUAL_GRIP
	if right:
		return RIGHT_GRIP
	var muzzle_z: float = weapon.muzzle.position.z
	if absf(muzzle_z) > LONG_GUN_REACH:
		return Vector3(0.0, HANDGUARD_DROP, muzzle_z * HANDGUARD_SHARE)
	return SHORT_SUPPORT_GRIP


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

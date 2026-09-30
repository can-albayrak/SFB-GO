class_name Player
extends CharacterBody3D
## Player root: owns state and wires the components together.
## Stage 1 is single-player; health changes will move to the host in stage 2.

signal health_changed(health: int, max_health: int)
signal weapon_changed(weapon: Weapon)

const FALL_RESPAWN_Y: float = -30.0

@export var class_def: ClassDef

## Vertical look angle in radians. Yaw is the body's own rotation.y.
var look_pitch: float = 0.0
var health: int = 0
var weapons: Array[Weapon] = []
var current_weapon: Weapon = null

var _spawn_transform: Transform3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var hitboxes: Node3D = $Hitboxes
@onready var movement: Movement = $Movement
@onready var player_input: PlayerInput = $PlayerInput


func _ready() -> void:
	_spawn_transform = global_transform
	health = class_def.max_health
	# Camera is top-level and placed every frame, so mouse look never waits for a physics tick.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = Settings.get_vertical_fov()
	camera.current = true
	_create_weapons()
	equip(0)
	Events.local_player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	var cmd: PlayerCommand = player_input.gather()
	if cmd.weapon_slot >= 0:
		equip(cmd.weapon_slot)

	movement.base_speed = class_def.move_speed * current_weapon.def.move_speed_mult
	movement.physics_step(delta, cmd)
	current_weapon.tick(delta, cmd)

	if global_position.y < FALL_RESPAWN_Y:
		respawn()


func _process(_delta: float) -> void:
	var eye: Vector3 = head.get_global_transform_interpolated().origin
	camera.global_transform = Transform3D(get_aim_basis(), eye)


func equip(slot: int) -> void:
	if slot < 0 or slot >= weapons.size() or weapons[slot] == current_weapon:
		return
	if current_weapon != null:
		current_weapon.holster()
	current_weapon = weapons[slot]
	current_weapon.draw()
	weapon_changed.emit(current_weapon)


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	look_pitch = 0.0
	movement.reset()
	health = class_def.max_health
	health_changed.emit(health, class_def.max_health)
	reset_physics_interpolation()


## Eye position at the current physics tick (not interpolated). Shots start here.
func get_aim_origin() -> Vector3:
	return head.global_position


## Look direction including weapon recoil.
func get_aim_basis() -> Basis:
	var recoil: Vector2 = current_weapon.recoil_offset if current_weapon != null else Vector2.ZERO
	return Basis.from_euler(Vector3(
		look_pitch + deg_to_rad(recoil.y),
		rotation.y - deg_to_rad(recoil.x),
		0.0))


## Own body and hitboxes, so our rays never hit ourselves.
func get_hit_exclusions() -> Array[RID]:
	var rids: Array[RID] = [get_rid()]
	for child: Node in hitboxes.get_children():
		if child is CollisionObject3D:
			rids.append((child as CollisionObject3D).get_rid())
	return rids


func _create_weapons() -> void:
	# Stage 4 adds loadout choice; for now the class's first primary + its secondary.
	var defs: Array[WeaponDef] = [class_def.primary_weapons[0], class_def.secondary_weapon]
	for def: WeaponDef in defs:
		var weapon: Weapon = def.scene.instantiate()
		weapon.setup(def, self)
		weapon.visible = false
		weapon_holder.add_child(weapon)
		weapons.append(weapon)

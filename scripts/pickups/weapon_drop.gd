class_name WeaponDrop
extends Node3D
## An airdrop weapon on the ground (its carrier died) with the rounds it had left. Visual only;
## the AirdropManager decides who walks over it and when it disappears.

const FLOAT_HEIGHT: float = 0.6
const SPIN_SPEED: float = 1.2
const LIGHT_COLOR: Color = Color(1.0, 0.4, 0.3)

var drop_id: int = 0
var weapon_index: int = -1
var ammo: int = 0
var _model: Node3D
var _time: float = 0.0


static func create(id: int, index: int, rounds: int, point: Vector3) -> WeaponDrop:
	var drop := WeaponDrop.new()
	drop.drop_id = id
	drop.name = "Drop%d" % id
	drop.weapon_index = index
	drop.ammo = rounds
	drop.position = point
	return drop


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var def: WeaponDef = AirdropWeapons.get_def(weapon_index)
	if def != null and def.world_model != null:
		_model = def.world_model.instantiate() as Node3D
		_model.scale = Vector3.ONE * def.world_model_scale
		_model.position.y = FLOAT_HEIGHT
		add_child(_model)
	var light := OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = FLOAT_HEIGHT
	add_child(light)
	var label := Label3D.new()
	label.text = "%s  %d" % [def.display_name.to_upper() if def != null else "?", ammo]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.005
	label.position.y = FLOAT_HEIGHT + 0.5
	add_child(label)


func _process(delta: float) -> void:
	_time += delta
	if _model != null:
		_model.rotation.y = _time * SPIN_SPEED

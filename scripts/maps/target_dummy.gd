class_name TargetDummy
extends Node3D
## Test range target. Shows floating damage numbers, "dies" at zero health and resets.

const RESET_DELAY: float = 2.0
const NUMBER_RISE: float = 0.7
const NUMBER_TIME: float = 0.9
const ALIVE_COLOR: Color = Color(0.85, 0.55, 0.2)
const DEAD_COLOR: Color = Color(0.55, 0.08, 0.08)
const HEAD_NUMBER_COLOR: Color = Color(1.0, 0.25, 0.2)
const BODY_NUMBER_COLOR: Color = Color(1.0, 1.0, 1.0)
const LEG_NUMBER_COLOR: Color = Color(0.7, 0.7, 0.7)

## Test value only: lets one range hold 70 / 100 / 175 HP targets to feel class TTK.
@export var max_health: int = 100

var health: float = 0.0

var _material := StandardMaterial3D.new()

@onready var info_label: Label3D = $InfoLabel


func _ready() -> void:
	for mesh: MeshInstance3D in [$BodyMesh, $HeadMesh]:
		mesh.material_override = _material
	_reset()


func take_hit(amount: float, zone: Hitbox.Zone, _attacker_id: int) -> bool:
	if health <= 0.0:
		return false
	health -= amount
	_spawn_number(amount, zone)
	if health > 0.0:
		_update_label()
		return false
	_material.albedo_color = DEAD_COLOR
	info_label.text = "DEAD"
	get_tree().create_timer(RESET_DELAY).timeout.connect(_reset)
	return true


func _reset() -> void:
	health = max_health
	_material.albedo_color = ALIVE_COLOR
	_update_label()


func _update_label() -> void:
	info_label.text = "%d / %d HP" % [ceili(health), max_health]


func _spawn_number(amount: float, zone: Hitbox.Zone) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 12
	label.pixel_size = 0.004
	match zone:
		Hitbox.Zone.HEAD:
			label.modulate = HEAD_NUMBER_COLOR
		Hitbox.Zone.LEG:
			label.modulate = LEG_NUMBER_COLOR
		_:
			label.modulate = BODY_NUMBER_COLOR
	add_child(label)
	label.position = Vector3(randf_range(-0.25, 0.25), 1.9, 0.0)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + NUMBER_RISE, NUMBER_TIME)
	tween.tween_property(label, "modulate:a", 0.0, NUMBER_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

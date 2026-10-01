class_name TargetDummy
extends Node3D
## Test range target (only in test_range.tscn). Health lives on the host; every peer sees the
## health label. Damage numbers are the shooter's own (DamageNumber, via Player.confirm_hit).

const GROUP: StringName = &"target_dummies"
const RESET_DELAY: float = 2.0
const ALIVE_COLOR: Color = Color(0.85, 0.55, 0.2)
const DEAD_COLOR: Color = Color(0.55, 0.08, 0.08)

## Test value only: lets one range hold 70 / 100 / 175 HP targets to feel class TTK.
@export var max_health: int = 100

var health: float = 0.0
## Host: damage taken by the last take_hit (same contract as Player.last_damage_dealt).
var last_damage_dealt: float = 0.0

var _material := StandardMaterial3D.new()

@onready var info_label: Label3D = $InfoLabel


func _ready() -> void:
	add_to_group(GROUP)
	for mesh: MeshInstance3D in [$BodyMesh, $HeadMesh]:
		mesh.material_override = _material
	_show_reset()


## Host only: tells a late joiner the current health.
func sync_to_peer(peer_id: int) -> void:
	_show_state.rpc_id(peer_id, health)


## Host only. Returns true if this hit killed.
func take_hit(amount: float, zone: Hitbox.Zone, _attacker_id: int, _weapon_name: String, _is_melee: bool = false) -> bool:
	assert(multiplayer.is_server(), "take_hit is host-only")
	last_damage_dealt = 0.0
	if health <= 0.0:
		return false
	last_damage_dealt = amount
	health -= amount
	var killed: bool = health <= 0.0
	Net.broadcast(self, &"_show_hit", [amount, zone, health])
	if killed:
		get_tree().create_timer(RESET_DELAY).timeout.connect(_server_reset)
	return killed


func _server_reset() -> void:
	Net.broadcast(self, &"_show_reset")


@rpc("any_peer", "call_local", "reliable")
func _show_hit(_amount: float, _zone: Hitbox.Zone, new_health: float) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	health = new_health
	if health > 0.0:
		_update_label()
	else:
		_material.albedo_color = DEAD_COLOR
		info_label.text = "DEAD"


@rpc("any_peer", "call_local", "reliable")
func _show_reset() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	health = max_health
	_material.albedo_color = ALIVE_COLOR
	_update_label()


@rpc("any_peer", "call_local", "reliable")
func _show_state(new_health: float) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	health = new_health
	if health > 0.0:
		_material.albedo_color = ALIVE_COLOR
		_update_label()
	else:
		_material.albedo_color = DEAD_COLOR
		info_label.text = "DEAD"


func _update_label() -> void:
	info_label.text = "%d / %d HP" % [ceili(health), max_health]


class_name Pickup
extends Node3D
## A fixed pickup spot on the map (GDD "Pickup'lar"): Health, Speed or Double Jump.
## The host decides who takes it (one at a time, first in tree order wins a tie) and when it
## comes back; every peer draws the floating icon, or the countdown hologram while it is gone.
## Lives under the map, so its RPC path is the same on every peer.

const GROUP: StringName = &"pickups"
const TAKE_RADIUS: float = 1.0 ## Horizontal metres from the spot.
const TAKE_HEIGHT: float = 1.8 ## A player's feet up to this far above the spot.
const FLOAT_HEIGHT: float = 0.9
const BOB_HEIGHT: float = 0.08
const BOB_SPEED: float = 2.0
const SPIN_SPEED: float = 1.6
const ICON_SIZE: float = 0.42
const LIGHT_ENERGY: float = 1.6
const LIGHT_RANGE: float = 3.0
const BASE_RADIUS: float = 0.55

@export var def: PickupDef

var available: bool = true
var _respawn_left: float = 0.0
var _icon: Node3D
var _light: OmniLight3D
var _countdown: Label3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_build_visual()
	_show(true)
	Events.match_started.connect(_on_match_started)


func _process(delta: float) -> void:
	_time += delta
	if not available:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		_countdown.text = str(ceili(_respawn_left))
		return
	_icon.position.y = FLOAT_HEIGHT + sin(_time * BOB_SPEED) * BOB_HEIGHT
	_icon.rotation.y = _time * SPIN_SPEED


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or Match.state != Match.State.PLAYING:
		return
	if not available:
		if _respawn_left <= 0.0:
			Net.broadcast(self, &"_set_state", [true, 0.0])
		return
	var game: Game = Game.find(get_tree())
	if game == null:
		return
	for node: Node in game.players_root.get_children():
		var player := node as Player
		if player == null or not player.is_alive or not _in_reach(player) or not _wants(player):
			continue
		player.status.server_take_pickup(def)
		Net.broadcast(self, &"_set_state", [false, def.respawn_time])
		return


## Host: a late joiner gets the current state.
func sync_to_peer(peer_id: int) -> void:
	_set_state.rpc_id(peer_id, available, _respawn_left)


## Host test helper: the pickup is back now.
func server_reset() -> void:
	Net.broadcast(self, &"_set_state", [true, 0.0])


## Host: a new match starts with every pickup in place (like crates and drops).
func _on_match_started() -> void:
	if multiplayer.is_server() and not available:
		server_reset()


func _in_reach(player: Player) -> bool:
	var offset: Vector3 = player.global_position - global_position
	return offset.y > -0.5 and offset.y < TAKE_HEIGHT and Vector2(offset.x, offset.z).length() <= TAKE_RADIUS


## Health is left for someone hurt; boosts are always taken.
func _wants(player: Player) -> bool:
	return def.kind != PickupDef.Kind.HEALTH or player.health < player.class_def.max_health


func _show(on: bool) -> void:
	_icon.visible = on
	_light.visible = on
	_countdown.visible = not on


func _build_visual() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = def.color
	_icon = Node3D.new()
	add_child(_icon)
	for part: Array in _icon_parts():
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mesh.material = glow
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = part[1]
		instance.rotation_degrees = part[2]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_icon.add_child(instance)

	# A flat ring on the floor marks the spot even while it is gone.
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = BASE_RADIUS
	ring_mesh.bottom_radius = BASE_RADIUS
	ring_mesh.height = 0.02
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(def.color, 0.35)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mesh.material = ring_material
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.position.y = 0.01
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	_light = OmniLight3D.new()
	_light.light_color = def.color
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.position.y = FLOAT_HEIGHT
	add_child(_light)

	_countdown = Label3D.new()
	_countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_countdown.modulate = Color(def.color, 0.8)
	_countdown.outline_size = 8
	_countdown.font_size = 72
	_countdown.pixel_size = 0.005
	_countdown.position.y = FLOAT_HEIGHT
	add_child(_countdown)


## Icon boxes: [size, position, rotation degrees]. Health = cross, Speed = arrow, Double Jump = two chevrons.
func _icon_parts() -> Array[Array]:
	var s: float = ICON_SIZE
	match def.kind:
		PickupDef.Kind.HEALTH:
			return [[Vector3(s, s * 0.3, s * 0.3), Vector3.ZERO, Vector3.ZERO],
				[Vector3(s * 0.3, s, s * 0.3), Vector3.ZERO, Vector3.ZERO]]
		PickupDef.Kind.SPEED:
			return [[Vector3(s * 0.22, s * 0.7, s * 0.22), Vector3(-s * 0.1, s * 0.12, 0.0), Vector3(0.0, 0.0, -25.0)],
				[Vector3(s * 0.22, s * 0.7, s * 0.22), Vector3(s * 0.1, -s * 0.12, 0.0), Vector3(0.0, 0.0, -25.0)],
				[Vector3(s * 0.5, s * 0.16, s * 0.22), Vector3(0.0, 0.0, 0.0), Vector3.ZERO]]
		_:
			var parts: Array[Array] = []
			for y: float in [-s * 0.18, s * 0.18]:
				parts.append([Vector3(s * 0.5, s * 0.14, s * 0.2), Vector3(-s * 0.17, y, 0.0), Vector3(0.0, 0.0, 35.0)])
				parts.append([Vector3(s * 0.5, s * 0.14, s * 0.2), Vector3(s * 0.17, y, 0.0), Vector3(0.0, 0.0, -35.0)])
			return parts


@rpc("any_peer", "call_local", "reliable")
func _set_state(is_available: bool, respawn_left: float) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	available = is_available
	_respawn_left = respawn_left
	_show(is_available)

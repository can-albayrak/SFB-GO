extends Node3D
## Match scene root (/root/Game on every peer). Loads the map, spawns players
## (host decides who and where), handles respawns and disconnects.
## A client asks for its player once its own copy of this scene is ready, so
## the host never replicates nodes to a peer that is still loading.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
## Movement relays start this long after a peer joins, so its spawn packets arrive first.
const STATE_RELAY_DELAY: float = 0.5

var _spawn_points: Array[Marker3D] = []

@onready var players_root: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner


func _ready() -> void:
	var map: Node3D = load(Net.map_path).instantiate()
	map.name = "Map" # Same path on every peer; map nodes (dummies) send RPCs.
	add_child(map)
	move_child(map, 0)
	for child: Node in map.get_node("SpawnPoints").get_children():
		if child is Marker3D:
			_spawn_points.append(child as Marker3D)
	assert(not _spawn_points.is_empty(), "Map has no SpawnPoints")

	spawner.spawn_function = _create_player
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_add_ingame_peer(1)
	else:
		_request_spawn.rpc_id(1)


func _create_player(data: Variant) -> Node:
	var info: Dictionary = data
	var peer_id: int = info["id"]
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.setup_authority(peer_id)
	player.position = info["position"]
	player.rotation.y = info["yaw"]
	return player


func _add_ingame_peer(peer_id: int) -> void:
	Net.ingame_peers.append(peer_id)
	# Existing players become visible (and are spawned) on the new peer.
	for player: Player in _get_players():
		player.get_node("StateSync").set_visibility_for(peer_id, true)
	var spawn: Marker3D = _pick_spawn_point()
	var new_player: Player = spawner.spawn({
		"id": peer_id,
		"position": spawn.global_position,
		"yaw": spawn.global_rotation.y,
	})
	for id: int in Net.ingame_peers:
		new_player.get_node("StateSync").set_visibility_for(id, true)
	new_player.died.connect(_on_player_died.bind(new_player))

	for dummy: Node in get_tree().get_nodes_in_group(TargetDummy.GROUP):
		(dummy as TargetDummy).sync_to_peer(peer_id)
	get_tree().create_timer(STATE_RELAY_DELAY).timeout.connect(_enable_state_relay.bind(peer_id))


func _enable_state_relay(peer_id: int) -> void:
	if peer_id in Net.ingame_peers and peer_id not in Net.state_peers:
		Net.state_peers.append(peer_id)


# Stage 3 replaces this with "farthest from enemies".
func _pick_spawn_point() -> Marker3D:
	return _spawn_points.pick_random()


func _get_players() -> Array[Player]:
	var result: Array[Player] = []
	for child: Node in players_root.get_children():
		if child is Player:
			result.append(child as Player)
	return result


func _on_player_died(_killer_id: int, player: Player) -> void:
	get_tree().create_timer(Match.rules.respawn_delay).timeout.connect(_respawn.bind(player))


func _respawn(player: Player) -> void:
	if not is_instance_valid(player):
		return
	var spawn: Marker3D = _pick_spawn_point()
	player.server_respawn(spawn.global_position, spawn.global_rotation.y)


func _on_peer_disconnected(peer_id: int) -> void:
	var player: Node = players_root.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn() -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id in Net.ingame_peers:
		return
	_add_ingame_peer(peer_id)

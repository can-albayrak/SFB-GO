extends Node3D
## Match scene root (/root/Game on every peer). Loads the map, spawns players
## (host decides who and where), registers kills with Match, handles respawns,
## match restarts and disconnects.
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
	spawner.spawned.connect(_on_player_node_added.unbind(1))
	Events.scores_changed.connect(_update_leader)
	Events.match_started.connect(_on_match_started)

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		Match.server_begin()
		_add_ingame_peer(1)
	else:
		_request_spawn.rpc_id(1)


func _exit_tree() -> void:
	Match.end_session()


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
	Match.server_add_player(peer_id)
	# Existing players become visible (and are spawned) on the new peer.
	for player: Player in _get_players():
		player.get_node("StateSync").set_visibility_for(peer_id, true)
	var spawn: Marker3D = _pick_spawn_point(peer_id)
	var new_player: Player = spawner.spawn({
		"id": peer_id,
		"position": spawn.global_position,
		"yaw": spawn.global_rotation.y,
	})
	for id: int in Net.ingame_peers:
		new_player.get_node("StateSync").set_visibility_for(id, true)
	new_player.died.connect(_on_player_died.bind(new_player))
	_update_leader()

	for dummy: Node in get_tree().get_nodes_in_group(TargetDummy.GROUP):
		(dummy as TargetDummy).sync_to_peer(peer_id)
	get_tree().create_timer(STATE_RELAY_DELAY).timeout.connect(_enable_state_relay.bind(peer_id))


func _enable_state_relay(peer_id: int) -> void:
	if peer_id in Net.ingame_peers and peer_id not in Net.state_peers:
		Net.state_peers.append(peer_id)


## GDD: spawn at the point farthest from living enemies.
func _pick_spawn_point(for_peer_id: int) -> Marker3D:
	var enemies: Array[Player] = []
	for player: Player in _get_players():
		if player.is_alive and player.get_multiplayer_authority() != for_peer_id:
			enemies.append(player)
	if enemies.is_empty():
		return _spawn_points.pick_random()

	var best: Marker3D = _spawn_points[0]
	var best_distance: float = -1.0
	for point: Marker3D in _spawn_points:
		var nearest: float = INF
		for enemy: Player in enemies:
			nearest = minf(nearest, point.global_position.distance_squared_to(enemy.global_position))
		if nearest > best_distance:
			best_distance = nearest
			best = point
	return best


func _get_players() -> Array[Player]:
	var result: Array[Player] = []
	for child: Node in players_root.get_children():
		if child is Player:
			result.append(child as Player)
	return result


func _on_player_node_added() -> void:
	_update_leader()


## Every peer: crown on the sole leader.
func _update_leader() -> void:
	var leader: int = Match.get_leader()
	for player: Player in _get_players():
		player.set_leader(player.get_multiplayer_authority() == leader and not player.is_local)


func _on_player_died(killer_id: int, weapon_name: String, headshot: bool, player: Player) -> void:
	var distance: float = 0.0
	var killer := players_root.get_node_or_null(str(killer_id)) as Player
	if killer != null:
		distance = killer.global_position.distance_to(player.global_position)
	Match.server_register_kill(killer_id, player.get_multiplayer_authority(), weapon_name, headshot, distance)
	get_tree().create_timer(Match.rules.respawn_delay).timeout.connect(_respawn.bind(player))


func _respawn(player: Player) -> void:
	if not is_instance_valid(player) or player.is_alive:
		return
	var spawn: Marker3D = _pick_spawn_point(player.get_multiplayer_authority())
	player.server_respawn(spawn.global_position, spawn.global_rotation.y)


## Every peer; only the host acts: everyone respawns fresh for the new match.
func _on_match_started() -> void:
	if not multiplayer.is_server():
		return
	for player: Player in _get_players():
		var spawn: Marker3D = _pick_spawn_point(player.get_multiplayer_authority())
		player.server_respawn(spawn.global_position, spawn.global_rotation.y)


func _on_peer_disconnected(peer_id: int) -> void:
	Match.server_remove_player(peer_id)
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

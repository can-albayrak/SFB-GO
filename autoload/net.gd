extends Node
## Connection handling: host/join, lobby, peer registry, player names, disconnects.
## Host is always peer 1 (listen server). Transport: ENet (IP + port) or Steam (SteamLink hands
## in a SteamMultiplayerPeer through host_with_peer / join_with_peer). The offline test range uses
## OfflineMultiplayerPeer, where we are also peer 1 and is_server() is true,
## so the same host-authoritative code runs unchanged.
##
## Lobby (GDD): Host Game opens the lobby; peers that register while it is open load the
## lobby too. The host picks kill target / minutes / map and starts: it loads the match,
## then sends the usual _welcome to every lobby peer (the same path as a late join).

signal players_changed
## Every peer: ready states or the host's lobby settings changed.
signal lobby_changed

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 10
const MAX_NAME_LENGTH: int = 16
const MAIN_MENU_PATH: String = "res://scenes/main.tscn"
const GAME_PATH: String = "res://scenes/game.tscn"
const LOBBY_PATH: String = "res://scenes/lobby.tscn"
const DEFAULT_MAP_PATH: String = "res://scenes/maps/test_range.tscn"
## Maps the host can pick in the lobby (the first is the default).
const MAP_LIST: MapList = preload("res://data/maps/map_list.tres")
const GAME_WAIT_FRAMES: int = 600 ## Host: give up sending lobby peers in if the match never loads.
## Host, non-ENet peers (Steam): seconds between round-trip pings (lag compensation).
const PING_INTERVAL: float = 1.0
const PING_SMOOTHING: float = 0.3 ## Weight of a new round-trip sample.

var player_names: Dictionary[int, String] = {}
var map_path: String = DEFAULT_MAP_PATH
## Host only: peers whose game scene is loaded (host included). Gameplay RPCs go only to these.
var ingame_peers: Array[int] = []
## Host only: ingame peers that also receive movement relays. Added shortly after joining,
## because unreliable state packets can overtake the reliable spawn packets.
var state_peers: Array[int] = []
## Shown by the main menu after returning (e.g. "Host left the game").
var last_message: String = ""
## True while the lobby is open (host: new peers go to the lobby; client: we are in it).
var in_lobby: bool = false
## Lobby "ready" flags by peer id (host-owned, mirrored to everyone).
var ready_peers: Dictionary[int, bool] = {}
## Client: a late joiner picks a loadout before entering (false for command-line joins).
var ask_loadout_on_join: bool = true
## Client: set by _welcome; Game shows the loadout menu before asking to spawn.
var pick_on_join: bool = false
## Lobby settings as the host last set them (shown to everyone in the lobby).
var lobby_kill_target: int = 0
var lobby_minutes: float = 0.0
var lobby_map_index: int = 0

var _local_name: String = ""
var _join_address: String = ""
## Bumped on every session change, so a pending lobby start from an old session gives up.
var _session_serial: int = 0
## Host: measured round trips in seconds by peer, for transports without ENet statistics.
var _rtt: Dictionary[int, float] = {}
var _ping_left: float = 0.0


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_offline(player_name: String) -> void:
	_reset_state()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	player_names[1] = _clean_name(player_name, 1)
	get_tree().change_scene_to_file(GAME_PATH)


## `use_lobby` false = straight into the match (command-line --host, headless tests).
func host_game(player_name: String, port: int = DEFAULT_PORT, use_lobby: bool = true) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	print("[Net] Hosting on port %d" % port)
	host_with_peer(peer, player_name, use_lobby)
	return OK


## Hosts on a peer that is already listening (ENet above, or SteamLink's Steam peer).
func host_with_peer(peer: MultiplayerPeer, player_name: String, use_lobby: bool = true) -> void:
	_reset_state()
	multiplayer.multiplayer_peer = peer
	player_names[1] = _clean_name(player_name, 1)
	in_lobby = use_lobby
	if use_lobby:
		lobby_kill_target = Match.DEFAULT_RULES.kill_target
		lobby_minutes = Match.DEFAULT_RULES.time_limit / 60.0
		get_tree().change_scene_to_file(LOBBY_PATH)
	else:
		get_tree().change_scene_to_file(GAME_PATH)


func join_game(player_name: String, address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	join_with_peer(peer, player_name)
	_join_address = address # Remembered as "last host" once connected.
	print("[Net] Connecting to %s:%d" % [address, port])
	return OK


## Joins through a peer that is already connecting (ENet above, or SteamLink's Steam peer).
func join_with_peer(peer: MultiplayerPeer, player_name: String) -> void:
	_reset_state()
	multiplayer.multiplayer_peer = peer
	_local_name = player_name


func leave(message: String = "") -> void:
	multiplayer.multiplayer_peer.close()
	SteamLink.leave_lobby()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset_state()
	last_message = message
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


## Host, lobby: start the match with these rules. Lobby peers follow once our match is loaded.
func server_start_match(kill_target: int, minutes: float, map_index: int) -> void:
	assert(multiplayer.is_server(), "server_start_match is host-only")
	if not in_lobby:
		return
	in_lobby = false
	var serial: int = _session_serial
	# Only these get welcomed below; anyone registering from now on takes the late-join path.
	var lobby_peers: Array[int] = []
	for peer_id: int in player_names:
		if peer_id != 1:
			lobby_peers.append(peer_id)
	Match.configure(kill_target, minutes)
	map_path = MAP_LIST.get_map(map_index).scene_path
	get_tree().change_scene_to_file(GAME_PATH)
	for i: int in GAME_WAIT_FRAMES:
		if Game.find(get_tree()) != null:
			break
		await get_tree().process_frame
	if serial != _session_serial or Game.find(get_tree()) == null:
		return # Left / re-hosted (or the match failed to load) while waiting.
	for peer_id: int in lobby_peers:
		if player_names.has(peer_id) and peer_id not in ingame_peers:
			_welcome.rpc_id(peer_id, map_path)


## Host, lobby: new rules picked in the lobby UI; everyone in the lobby sees them.
func server_set_lobby_settings(kill_target: int, minutes: float, map_index: int) -> void:
	assert(multiplayer.is_server(), "server_set_lobby_settings is host-only")
	lobby_kill_target = kill_target
	lobby_minutes = minutes
	lobby_map_index = map_index
	_broadcast_lobby()


## Client, lobby: toggle our "ready" flag (shown to everyone; the host decides when to start).
func request_lobby_ready(is_ready: bool) -> void:
	_request_ready.rpc_id(1, is_ready)


## Host: round trip to `peer_id` in seconds (lag compensation rewinds by it). ENet keeps its own
## statistic; other transports (Steam) use our pings.
func get_rtt(peer_id: int) -> float:
	if peer_id == 1:
		return 0.0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return _rtt.get(peer_id, 0.0)
	var packet_peer: ENetPacketPeer = enet.get_peer(peer_id)
	if packet_peer == null:
		return 0.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 1000.0


func get_player_name(peer_id: int) -> String:
	return player_names.get(peer_id, "Player %d" % peer_id)


## Host only: sends an RPC on `node` to every peer that has the game loaded (host included,
## so the method needs call_local).
func broadcast(node: Node, method: StringName, args: Array = []) -> void:
	assert(multiplayer.is_server(), "broadcast is host-only")
	for peer_id: int in ingame_peers:
		node.callv(&"rpc_id", [peer_id, method] + args)


func _reset_state() -> void:
	player_names.clear()
	ingame_peers.clear()
	state_peers.clear()
	map_path = DEFAULT_MAP_PATH
	last_message = ""
	in_lobby = false
	pick_on_join = false
	_session_serial += 1
	ready_peers.clear()
	lobby_kill_target = 0
	lobby_minutes = 0.0
	lobby_map_index = 0
	_join_address = ""
	_rtt.clear()
	_ping_left = 0.0


func _clean_name(raw: String, peer_id: int) -> String:
	var cleaned: String = raw.strip_edges().left(MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else "Player %d" % peer_id


func _process(delta: float) -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer is ENetMultiplayerPeer or peer is OfflineMultiplayerPeer or not multiplayer.is_server():
		return
	_ping_left -= delta
	if _ping_left > 0.0:
		return
	_ping_left = PING_INTERVAL
	for peer_id: int in player_names:
		if peer_id != 1:
			_ping.rpc_id(peer_id, Time.get_ticks_usec())


func _on_connected_to_server() -> void:
	print("[Net] Connected as peer %d" % multiplayer.get_unique_id())
	# Remembered only once it worked, so a typo never replaces a good address.
	if not _join_address.is_empty():
		Settings.last_host = _join_address
		Settings.save_settings()
	_request_register.rpc_id(1, _local_name)


func _on_connection_failed() -> void:
	leave("Could not connect to host")


func _on_server_disconnected() -> void:
	leave("Host left the game")


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Net] %s left" % get_player_name(peer_id))
	player_names.erase(peer_id)
	ingame_peers.erase(peer_id)
	state_peers.erase(peer_id)
	ready_peers.erase(peer_id)
	_rtt.erase(peer_id)
	_sync_names.rpc(player_names)
	if in_lobby:
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _request_register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	player_names[peer_id] = _clean_name(player_name, peer_id)
	print("[Net] %s joined (peer %d)" % [player_names[peer_id], peer_id])
	if in_lobby:
		ready_peers[peer_id] = false
		_welcome_lobby.rpc_id(peer_id)
	else:
		_welcome_when_game_ready(peer_id) # Match running (or loading right after Start): late join.
	_sync_names.rpc(player_names)
	if in_lobby:
		_broadcast_lobby()


## Host: a late joiner is sent in once our match scene exists (it may still be loading just
## after Start), so its spawn request never reaches a host without a Game.
func _welcome_when_game_ready(peer_id: int) -> void:
	var serial: int = _session_serial
	for i: int in GAME_WAIT_FRAMES:
		if Game.find(get_tree()) != null:
			break
		await get_tree().process_frame
	if serial != _session_serial or not player_names.has(peer_id) or Game.find(get_tree()) == null:
		return
	_welcome.rpc_id(peer_id, map_path)


@rpc("authority", "call_remote", "reliable")
func _welcome(host_map_path: String) -> void:
	pick_on_join = ask_loadout_on_join and not in_lobby # Lobby peers already picked there.
	in_lobby = false
	map_path = host_map_path
	get_tree().change_scene_to_file(GAME_PATH)


@rpc("authority", "call_remote", "reliable")
func _welcome_lobby() -> void:
	in_lobby = true
	get_tree().change_scene_to_file(LOBBY_PATH)


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(is_ready: bool) -> void:
	if not multiplayer.is_server() or not in_lobby:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not player_names.has(peer_id):
		return
	ready_peers[peer_id] = is_ready
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	_on_lobby_synced.rpc(ready_peers, lobby_kill_target, lobby_minutes, lobby_map_index)


@rpc("authority", "call_local", "reliable")
func _on_lobby_synced(new_ready: Dictionary, kill_target: int, minutes: float, map_index: int) -> void:
	ready_peers.assign(new_ready)
	lobby_kill_target = kill_target
	lobby_minutes = minutes
	lobby_map_index = map_index
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _sync_names(names: Dictionary) -> void:
	player_names.assign(names)
	players_changed.emit()


## Host -> client: echo this back (round-trip measurement for non-ENet transports).
@rpc("authority", "call_remote", "unreliable")
func _ping(sent_usec: int) -> void:
	_pong.rpc_id(1, sent_usec)


@rpc("any_peer", "call_remote", "unreliable")
func _pong(sent_usec: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not player_names.has(peer_id):
		return
	var sample: float = (Time.get_ticks_usec() - sent_usec) / 1_000_000.0
	_rtt[peer_id] = lerpf(_rtt[peer_id], sample, PING_SMOOTHING) if _rtt.has(peer_id) else sample

extends Node
## Connection handling: host/join, peer registry, player names, disconnects.
## Host is always peer 1 (ENet listen server). The offline test range uses
## OfflineMultiplayerPeer, where we are also peer 1 and is_server() is true,
## so the same host-authoritative code runs unchanged.

signal players_changed

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 10
const MAX_NAME_LENGTH: int = 16
const MAIN_MENU_PATH: String = "res://scenes/main.tscn"
const GAME_PATH: String = "res://scenes/game.tscn"
const DEFAULT_MAP_PATH: String = "res://scenes/maps/test_range.tscn"

var player_names: Dictionary[int, String] = {}
var map_path: String = DEFAULT_MAP_PATH
## Host only: peers whose game scene is loaded (host included). Gameplay RPCs go only to these.
var ingame_peers: Array[int] = []
## Host only: ingame peers that also receive movement relays. Added shortly after joining,
## because unreliable state packets can overtake the reliable spawn packets.
var state_peers: Array[int] = []
## Shown by the main menu after returning (e.g. "Host left the game").
var last_message: String = ""

var _local_name: String = ""


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


func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	_reset_state()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	player_names[1] = _clean_name(player_name, 1)
	print("[Net] Hosting on port %d" % port)
	get_tree().change_scene_to_file(GAME_PATH)
	return OK


func join_game(player_name: String, address: String, port: int = DEFAULT_PORT) -> Error:
	_reset_state()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	print("[Net] Connecting to %s:%d" % [address, port])
	return OK


func leave(message: String = "") -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset_state()
	last_message = message
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


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


func _clean_name(raw: String, peer_id: int) -> String:
	var cleaned: String = raw.strip_edges().left(MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else "Player %d" % peer_id


func _on_connected_to_server() -> void:
	print("[Net] Connected as peer %d" % multiplayer.get_unique_id())
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
	_sync_names.rpc(player_names)


@rpc("any_peer", "call_remote", "reliable")
func _request_register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	player_names[peer_id] = _clean_name(player_name, peer_id)
	print("[Net] %s joined (peer %d)" % [player_names[peer_id], peer_id])
	_welcome.rpc_id(peer_id, map_path)
	_sync_names.rpc(player_names)


@rpc("authority", "call_remote", "reliable")
func _welcome(host_map_path: String) -> void:
	map_path = host_map_path
	get_tree().change_scene_to_file(GAME_PATH)


@rpc("authority", "call_local", "reliable")
func _sync_names(names: Dictionary) -> void:
	player_names.assign(names)
	players_changed.emit()

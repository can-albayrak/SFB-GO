extends Node
## Steam lobbies and peer-to-peer sessions through GodotSteam, on App ID 480 (Spacewar, Valve's
## shared test app) for the friends build. No port forwarding or IP typing: Steam relays.
##
## Only builds made with the GodotSteam export templates have Steam (tools/steam/build_steam.py).
## In the plain Godot editor the "Steam" singleton does not exist: `available` stays false and
## the menu says so. The Steam API is reached through Engine.get_singleton() and call(), so this
## script also compiles where GodotSteam is missing. Never create a SteamMultiplayerPeer before
## Steam is initialised (GodotSteam crashes).
##
## Host: host_lobby() -> public lobby tagged GAME_KEY = GAME_TAG -> lobby_created ->
##   SteamMultiplayerPeer.create_host -> Net.host_with_peer (same lobby / match code as ENet).
## Client: find_lobbies() -> lobbies_found; join_lobby(id), an accepted invite or "Join Game"
##   in the Steam friends list (join_requested) -> lobby_joined ->
##   SteamMultiplayerPeer.create_client(lobby owner) -> Net.join_with_peer.
## Net.leave() calls leave_lobby().

## Every lobby search finished: [{id: int, host: String, players: int, max: int}].
signal lobbies_found(lobbies: Array[Dictionary])
## Something the main menu should show ("Creating Steam lobby...", errors). `failed`: the
## host / join attempt is over, the menu buttons work again.
signal status_changed(text: String, failed: bool)

const APP_ID: int = 480
## Lobby data key and value that mark our lobbies (App 480 is shared by every Steamworks test).
const GAME_KEY: String = "sfb_go"
const GAME_TAG: String = "1"
const HOST_KEY: String = "host"
const SEARCHING_TEXT: String = "Looking for Steam games..."
const VIRTUAL_PORT: int = 0
# GodotSteam constants (Steam.LOBBY_TYPE_PUBLIC etc.); plain numbers so this compiles without it.
const LOBBY_TYPE_PUBLIC: int = 2
const LOBBY_DISTANCE_FILTER_WORLDWIDE: int = 3
const LOBBY_COMPARISON_EQUAL: int = 0
const RESULT_OK: int = 1
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS: int = 1
const STEAM_API_INIT_RESULT_OK: int = 0
const ENTER_ERRORS: Dictionary[int, String] = {
	2: "That game no longer exists", 3: "Not allowed to join", 4: "That game is full",
	6: "Banned from that game", 7: "Limited Steam account", 10: "A player blocked you",
	11: "You blocked a player", 15: "Too many join attempts, wait a bit",
}

## GodotSteam is in this build and Steam is running and signed in.
var available: bool = false
## GodotSteam is in this build (false in the plain editor).
var has_steam_build: bool = false
## Why Steam is unavailable (shown by the menu).
var unavailable_reason: String = ""
## Steam lobby we are in (0 = none).
var lobby_id: int = 0

var _steam: Object = null
var _player_name: String = ""
var _hosting: bool = false


func _ready() -> void:
	has_steam_build = Engine.has_singleton(&"Steam")
	if not has_steam_build:
		unavailable_reason = "Steam needs the Steam build (SFB-GO.exe)"
		return
	_steam = Engine.get_singleton(&"Steam")
	# embed_callbacks = true: GodotSteam runs the Steam callbacks every frame by itself.
	var result: Dictionary = _steam.call(&"steamInitEx", APP_ID, true)
	if int(result.get("status", -1)) != STEAM_API_INIT_RESULT_OK:
		unavailable_reason = "Steam is not running (start Steam, then the game)"
		print("[Steam] Init failed: %s" % result.get("verbal", ""))
		return
	available = true
	_steam.connect(&"lobby_created", _on_lobby_created)
	_steam.connect(&"lobby_joined", _on_lobby_joined)
	_steam.connect(&"lobby_match_list", _on_lobby_match_list)
	_steam.connect(&"join_requested", _on_join_requested)
	print("[Steam] Signed in as %s (app %d)" % [get_persona_name(), APP_ID])


## Our Steam display name ("" without Steam).
func get_persona_name() -> String:
	return str(_steam.call(&"getPersonaName")) if available else ""


## Creates a Steam lobby, then hosts the game on it (lobby screen, like Host Game).
func host_lobby(player_name: String) -> bool:
	if not available:
		return false
	leave_lobby()
	_player_name = player_name
	_hosting = true
	_steam.call(&"createLobby", LOBBY_TYPE_PUBLIC, Net.MAX_PLAYERS)
	status_changed.emit("Creating Steam lobby...", false)
	return true


## Asks Steam for open SFB:GO lobbies; the answer comes as lobbies_found.
## `announce` false: no "Looking..." status (the menu's own search when it opens).
func find_lobbies(announce: bool = true) -> void:
	if not available:
		return
	_steam.call(&"addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_FILTER_WORLDWIDE)
	_steam.call(&"addRequestLobbyListStringFilter", GAME_KEY, GAME_TAG, LOBBY_COMPARISON_EQUAL)
	_steam.call(&"requestLobbyList")
	if announce:
		status_changed.emit(SEARCHING_TEXT, false)


func join_lobby(id: int, player_name: String) -> void:
	if not available:
		return
	leave_lobby()
	_player_name = player_name
	_hosting = false
	_steam.call(&"joinLobby", id)
	status_changed.emit("Joining Steam game...", false)


## Host, in a Steam lobby: Steam's invite dialog (friends get a "Join" button).
func invite_friends() -> void:
	if available and lobby_id != 0:
		_steam.call(&"activateGameOverlayInviteDialog", lobby_id)


func leave_lobby() -> void:
	if available and lobby_id != 0:
		_steam.call(&"leaveLobby", lobby_id)
	lobby_id = 0


func _new_peer() -> MultiplayerPeer:
	return ClassDB.instantiate(&"SteamMultiplayerPeer") as MultiplayerPeer


func _on_lobby_created(result: int, id: int) -> void:
	if not _hosting:
		return
	if result != RESULT_OK:
		status_changed.emit("Could not create a Steam lobby (code %d)" % result, true)
		return
	lobby_id = id
	_steam.call(&"setLobbyData", id, GAME_KEY, GAME_TAG)
	_steam.call(&"setLobbyData", id, HOST_KEY, _player_name)
	_steam.call(&"setLobbyJoinable", id, true)
	var peer: MultiplayerPeer = _new_peer()
	var err: int = peer.call(&"create_host", VIRTUAL_PORT)
	if err != OK:
		leave_lobby()
		status_changed.emit("Could not host on Steam (error %d)" % err, true)
		return
	print("[Steam] Hosting lobby %d" % id)
	Net.host_with_peer(peer, _player_name)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _hosting:
		return # Our own lobby: the creator gets this callback too.
	if response != CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		status_changed.emit(ENTER_ERRORS.get(response, "Could not join (code %d)" % response), true)
		return
	lobby_id = id
	var owner_id: int = _steam.call(&"getLobbyOwner", id)
	if owner_id == int(_steam.call(&"getSteamID")):
		return
	var peer: MultiplayerPeer = _new_peer()
	var err: int = peer.call(&"create_client", owner_id, VIRTUAL_PORT)
	if err != OK:
		leave_lobby()
		status_changed.emit("Could not connect over Steam (error %d)" % err, true)
		return
	print("[Steam] Joined lobby %d, connecting to its host" % id)
	Net.join_with_peer(peer, _player_name)


func _on_lobby_match_list(found: Array) -> void:
	var lobbies: Array[Dictionary] = []
	for id: int in found:
		lobbies.append({
			"id": id,
			"host": str(_steam.call(&"getLobbyData", id, HOST_KEY)),
			"players": int(_steam.call(&"getNumLobbyMembers", id)),
			"max": int(_steam.call(&"getLobbyMemberLimit", id)),
		})
	lobbies_found.emit(lobbies)


## A friend's invite accepted, or "Join Game" on a friend in the Steam friends list.
func _on_join_requested(id: int, _friend_id: int) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) or Game.find(get_tree()) != null:
		Net.leave() # In a match or lobby (or the Test Range): back to the menu first.
	join_lobby(id, get_player_name())


## Name to play under: the one typed in the menu, else the Steam name.
func get_player_name() -> String:
	var typed: String = Settings.player_name.strip_edges()
	return typed if not typed.is_empty() else get_persona_name()

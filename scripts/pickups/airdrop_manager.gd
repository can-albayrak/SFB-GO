class_name AirdropManager
extends Node3D
## Airdrops (GDD "Airdrop"), Game/Airdrops on every peer.
## Host: when (Match.rules: first delay, then a random interval) and where (a free marker under
## the map's AirdropPoints), who opens a crate (hold E next to a landed crate for
## open_time seconds; damage, death or walking away cancels), which random airdrop weapon they
## get, and who picks up a weapon dropped by a dead carrier. Everyone else draws crates and
## drops from the host's messages. Late joiners get them in sync_to_peer.
## Owner side (tick_local): holding E next to a crate asks the host to start/stop opening and
## drives the HUD progress bar.

const GROUP: StringName = &"airdrops"
const POINTS_NODE: String = "AirdropPoints"
const OPEN_DISTANCE: float = 2.2 ## Metres from the crate centre (owner side).
const OPEN_DISTANCE_SLACK: float = 1.0 ## Host allows this much more (position lag).
const DROP_PICKUP_RADIUS: float = 1.2

## Owner: 0..1 progress of the crate being opened (HUD), -1 when not opening.
var local_progress: float = -1.0

var _points: Array[Marker3D] = []
var _crates: Dictionary[int, AirdropCrate] = {}
var _drops: Dictionary[int, WeaponDrop] = {}
# Host.
var _next_drop_left: float = 0.0
var _next_id: int = 1
var _openers: Dictionary[int, Dictionary] = {} ## crate id -> {peer id: host time started}
var _drop_left: Dictionary[int, float] = {} ## drop id -> seconds until it disappears
# Owner.
var _local_crate: int = -1
var _local_started: float = 0.0
var _needs_release: bool = false


static func find(tree: SceneTree) -> AirdropManager:
	return tree.get_first_node_in_group(GROUP) as AirdropManager


func _ready() -> void:
	add_to_group(GROUP)
	var map: Node = get_parent().get_node_or_null("Map")
	var points: Node = map.get_node_or_null(POINTS_NODE) if map != null else null
	if points != null:
		for child: Node in points.get_children():
			if child is Marker3D:
				_points.append(child as Marker3D)
	_next_drop_left = Match.rules.airdrop_first_delay
	Events.match_started.connect(_on_match_started)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not Match.active or Match.state != Match.State.PLAYING:
		return
	if not _points.is_empty() and Match.rules.airdrop_interval_min > 0.0:
		_next_drop_left -= delta
		if _next_drop_left <= 0.0:
			_next_drop_left = randf_range(Match.rules.airdrop_interval_min, Match.rules.airdrop_interval_max)
			server_drop()
	_update_openers()
	_update_drops(delta)


# --- Host ------------------------------------------------------------------------

## Host: drops a crate on a free point now (unless the map is at its cap). Returns its id or -1.
func server_drop() -> int:
	assert(multiplayer.is_server(), "server_drop is host-only")
	var cap: int = Match.rules.airdrop_max_active
	if cap > 0 and get_active_count() >= cap:
		return -1
	var free: Array[Marker3D] = []
	for point: Marker3D in _points:
		if not _crate_at(point.global_position):
			free.append(point)
	if free.is_empty():
		return -1
	var id: int = _next_id
	_next_id += 1
	var fall: float = Match.rules.airdrop_fall_time
	Net.broadcast(self, &"_spawn_crate", [id, free.pick_random().global_position, fall, fall, true])
	return id


## Crates + weapons on the ground + carried airdrop weapons (the Test Range cap counts these).
func get_active_count() -> int:
	var count: int = _crates.size() + _drops.size()
	var game: Game = Game.find(get_tree())
	if game != null:
		for node: Node in game.players_root.get_children():
			if node is Player and (node as Player).special_weapon >= 0:
				count += 1
	return count


## Host: a carrier died; the weapon stays where they fell with the rounds they had.
func server_drop_weapon(index: int, ammo: int, point: Vector3) -> void:
	assert(multiplayer.is_server(), "server_drop_weapon is host-only")
	if ammo <= 0 or AirdropWeapons.get_def(index) == null:
		return
	var id: int = _next_id
	_next_id += 1
	_drop_left[id] = Match.rules.weapon_drop_lifetime
	Net.broadcast(self, &"_spawn_drop", [id, index, ammo, point])


## Host: a late joiner gets every crate and dropped weapon as they are now.
func sync_to_peer(peer_id: int) -> void:
	for id: int in _crates:
		var crate: AirdropCrate = _crates[id]
		_spawn_crate.rpc_id(peer_id, id, crate.landing_point, crate._fall_left, crate.fall_time, false)
	for id: int in _drops:
		var drop: WeaponDrop = _drops[id]
		_spawn_drop.rpc_id(peer_id, id, drop.weapon_index, drop.ammo, drop.position)


## Host test helper: lands every crate now.
func server_land_all() -> void:
	for crate: AirdropCrate in _crates.values():
		crate._fall_left = 0.0
		crate._update_fall()


func _update_openers() -> void:
	var now: float = _now()
	for id: int in _openers.keys():
		var crate: AirdropCrate = _crates.get(id)
		if crate == null:
			_openers.erase(id)
			continue
		var openers: Dictionary = _openers[id]
		for peer_id: int in openers.keys():
			var player: Player = _player(peer_id)
			var started: float = openers[peer_id]
			if player == null or not _can_open(player, crate, OPEN_DISTANCE + OPEN_DISTANCE_SLACK) \
					or player.last_hurt_time > started:
				openers.erase(peer_id)
				if player != null:
					_open_cancelled.rpc_id(peer_id)
				continue
			if now - started >= Match.rules.airdrop_open_time:
				_grant_crate(id, player)
				return # The crate is gone; the rest wait for the next tick.


func _grant_crate(id: int, player: Player) -> void:
	_openers.erase(id)
	var index: int = randi() % AirdropWeapons.count()
	player.give_special_weapon(index, AirdropWeapons.get_def(index).magazine_size)
	Net.broadcast(self, &"_remove_crate", [id, player.get_multiplayer_authority(), index])


func _update_drops(delta: float) -> void:
	var game: Game = Game.find(get_tree())
	for id: int in _drops.keys():
		_drop_left[id] = _drop_left.get(id, 0.0) - delta
		if _drop_left[id] <= 0.0:
			Net.broadcast(self, &"_remove_drop", [id])
			continue
		if game == null:
			continue
		var drop: WeaponDrop = _drops[id]
		for node: Node in game.players_root.get_children():
			var player := node as Player
			if player == null or not player.is_alive or player.special_weapon >= 0:
				continue
			var offset: Vector3 = player.global_position - drop.position
			if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() <= DROP_PICKUP_RADIUS:
				player.give_special_weapon(drop.weapon_index, drop.ammo)
				Net.broadcast(self, &"_remove_drop", [id])
				break


func _can_open(player: Player, crate: AirdropCrate, distance: float) -> bool:
	return player.is_alive and player.special_weapon < 0 and crate.is_landed() \
		and player.global_position.distance_to(crate.landing_point) <= distance


func _crate_at(point: Vector3) -> bool:
	for crate: AirdropCrate in _crates.values():
		if crate.landing_point.distance_to(point) < 0.5:
			return true
	return false


func _player(peer_id: int) -> Player:
	var game: Game = Game.find(get_tree())
	return game.players_root.get_node_or_null(str(peer_id)) as Player if game != null else null


func _on_match_started() -> void:
	if not multiplayer.is_server():
		return
	_next_drop_left = Match.rules.airdrop_first_delay
	_openers.clear()
	for id: int in _crates.keys():
		Net.broadcast(self, &"_remove_crate", [id, 0, -1])
	for id: int in _drops.keys():
		Net.broadcast(self, &"_remove_drop", [id])


# --- Owner -----------------------------------------------------------------------

## Owner, every physics tick: holding E (`interact`) next to a landed crate opens it.
func tick_local(player: Player, interact: bool) -> void:
	if not interact:
		_needs_release = false
	var crate: AirdropCrate = null
	if interact and not _needs_release and player.is_alive and player.special_weapon < 0:
		crate = _nearest_crate(player)
	var id: int = crate.crate_id if crate != null else -1
	if id != _local_crate:
		if _local_crate >= 0:
			_request_cancel.rpc_id(1, _local_crate)
		_local_crate = id
		_local_started = _now()
		if id >= 0:
			_request_open.rpc_id(1, id)
	local_progress = clampf((_now() - _local_started) / maxf(Match.rules.airdrop_open_time, 0.01), 0.0, 1.0) if id >= 0 else -1.0


func _nearest_crate(player: Player) -> AirdropCrate:
	var best: AirdropCrate = null
	var best_distance: float = OPEN_DISTANCE
	for crate: AirdropCrate in _crates.values():
		var distance: float = player.global_position.distance_to(crate.landing_point)
		if crate.is_landed() and distance <= best_distance:
			best = crate
			best_distance = distance
	return best


func _end_local_open() -> void:
	_local_crate = -1
	local_progress = -1.0
	_needs_release = true # Let go of E before trying again.


# --- RPCs ------------------------------------------------------------------------

func _sender_is_host() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	return (sender if sender != 0 else multiplayer.get_unique_id()) == 1


func _sender_id() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


@rpc("any_peer", "call_local", "reliable")
func _spawn_crate(id: int, point: Vector3, seconds_left: float, total_fall: float, announce: bool) -> void:
	if not _sender_is_host() or _crates.has(id):
		return
	var crate := AirdropCrate.create(id, point, seconds_left, total_fall)
	_crates[id] = crate
	add_child(crate)
	if announce:
		Events.airdrop_incoming.emit(point)


@rpc("any_peer", "call_local", "reliable")
func _remove_crate(id: int, opener_id: int, weapon_index: int) -> void:
	if not _sender_is_host():
		return
	var crate: AirdropCrate = _crates.get(id)
	_crates.erase(id)
	if crate != null:
		crate.queue_free()
	if id == _local_crate:
		_end_local_open()
	var def: WeaponDef = AirdropWeapons.get_def(weapon_index)
	if def != null:
		Events.airdrop_opened.emit(opener_id, def.display_name)


@rpc("any_peer", "call_local", "reliable")
func _spawn_drop(id: int, index: int, ammo: int, point: Vector3) -> void:
	if not _sender_is_host() or _drops.has(id):
		return
	var drop := WeaponDrop.create(id, index, ammo, point)
	_drops[id] = drop
	add_child(drop)


@rpc("any_peer", "call_local", "reliable")
func _remove_drop(id: int) -> void:
	if not _sender_is_host():
		return
	var drop: WeaponDrop = _drops.get(id)
	_drops.erase(id)
	_drop_left.erase(id)
	if drop != null:
		drop.queue_free()


## Owner -> host: started holding E at this crate.
@rpc("any_peer", "call_local", "reliable")
func _request_open(id: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = _sender_id()
	var player: Player = _player(peer_id)
	var crate: AirdropCrate = _crates.get(id)
	if player == null or crate == null or not _can_open(player, crate, OPEN_DISTANCE + OPEN_DISTANCE_SLACK):
		_open_cancelled.rpc_id(peer_id)
		return
	if not _openers.has(id):
		_openers[id] = {}
	(_openers[id] as Dictionary)[peer_id] = _now()


## Owner -> host: let go of E or walked away.
@rpc("any_peer", "call_local", "reliable")
func _request_cancel(id: int) -> void:
	if not multiplayer.is_server() or not _openers.has(id):
		return
	(_openers[id] as Dictionary).erase(_sender_id())


## Host -> owner: opening stopped (hurt, moved away, already taken).
@rpc("any_peer", "call_local", "reliable")
func _open_cancelled() -> void:
	if not _sender_is_host():
		return
	_end_local_open()


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0

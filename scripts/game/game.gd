class_name Game
extends Node3D
## Match scene root (/root/Game on every peer). Loads the map, spawns players
## (host decides who, where and with which validated loadout), registers kills with
## Match, handles respawns, match restarts, grenades/explosions and disconnects.
## A client asks for its player once its own copy of this scene is ready, so
## the host never replicates nodes to a peer that is still loading.

const GROUP: StringName = &"game"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
## Movement relays start this long after a peer joins, so its spawn packets arrive first.
const STATE_RELAY_DELAY: float = 0.5
const EXPLOSION_CENTER_OFFSET: float = 0.15 ## LOS rays start slightly above the floor contact.
const TARGET_CENTER_HEIGHT: float = 1.0 ## Body centre used for explosion distance and LOS.
const WORLD_MASK: int = 1
## Flash: blind strength by how directly the victim looks at it (dot of view and direction).
const FLASH_MIN_FACING_FACTOR: float = 0.25
const FLASH_DISTANCE_FALLOFF: float = 0.6 ## At max radius the flash keeps (1 - this) strength.

var _spawn_points: Array[Marker3D] = []

@onready var players_root: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectiles_root: Node3D = $Projectiles
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner


static func find(tree: SceneTree) -> Game:
	return tree.get_first_node_in_group(GROUP) as Game


func _ready() -> void:
	add_to_group(GROUP)
	var map: Node3D = load(Net.map_path).instantiate()
	map.name = "Map" # Same path on every peer; map nodes (dummies) send RPCs.
	add_child(map)
	move_child(map, 0)
	for child: Node in map.get_node("SpawnPoints").get_children():
		if child is Marker3D:
			_spawn_points.append(child as Marker3D)
	assert(not _spawn_points.is_empty(), "Map has no SpawnPoints")

	var airdrops := AirdropManager.new()
	airdrops.name = "Airdrops" # Same path on every peer (RPCs).
	add_child(airdrops)

	spawner.spawn_function = _create_player
	spawner.spawned.connect(_on_player_node_added.unbind(1))
	projectile_spawner.spawn_function = _create_grenade
	Events.scores_changed.connect(_update_leader)
	Events.match_started.connect(_on_match_started)

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		Match.server_begin()
		_add_ingame_peer(1, Loadout.from_settings())
	else:
		if Net.pick_on_join:
			_pick_loadout_then_spawn()
		else:
			_request_spawn.rpc_id(1, Loadout.from_settings())


## Late joiner (GDD): choose class and weapons first, then ask the host for a player.
func _pick_loadout_then_spawn() -> void:
	Net.pick_on_join = false
	var menu := $HUD/LoadoutMenu as LoadoutMenu
	menu.confirmed.connect(_on_join_loadout_picked, CONNECT_ONE_SHOT)
	menu.open(Loadout.from_settings())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_join_loadout_picked(code: PackedInt32Array) -> void:
	Loadout.save_to_settings(code)
	_request_spawn.rpc_id(1, code)


func _exit_tree() -> void:
	Match.end_session()


func _create_player(data: Variant) -> Node:
	var info: Dictionary = data
	var peer_id: int = info["id"]
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.setup_authority(peer_id)
	player.loadout = info["loadout"]
	player.position = info["position"]
	player.rotation.y = info["yaw"]
	return player


func _add_ingame_peer(peer_id: int, loadout: PackedInt32Array) -> void:
	Net.ingame_peers.append(peer_id)
	Match.server_add_player(peer_id)
	# Existing players and grenades become visible (and are spawned) on the new peer.
	for player: Player in _get_players():
		player.get_node("StateSync").set_visibility_for(peer_id, true)
	for grenade: Node in projectiles_root.get_children():
		grenade.get_node("Sync").set_visibility_for(peer_id, true)
	var spawn: Marker3D = _pick_spawn_point(peer_id)
	var new_player: Player = spawner.spawn({
		"id": peer_id,
		"loadout": loadout if Loadout.is_valid(loadout) else Loadout.default_code(),
		"position": spawn.global_position,
		"yaw": spawn.global_rotation.y,
	})
	for id: int in Net.ingame_peers:
		new_player.get_node("StateSync").set_visibility_for(id, true)
	new_player.died.connect(_on_player_died.bind(new_player))
	_update_leader()

	for dummy: Node in get_tree().get_nodes_in_group(TargetDummy.GROUP):
		(dummy as TargetDummy).sync_to_peer(peer_id)
	for pickup: Node in get_tree().get_nodes_in_group(Pickup.GROUP):
		(pickup as Pickup).sync_to_peer(peer_id)
	var airdrops: AirdropManager = AirdropManager.find(get_tree())
	if airdrops != null and peer_id != 1:
		airdrops.sync_to_peer(peer_id)
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


func _on_player_died(killer_id: int, weapon_name: String, headshot: bool, is_melee: bool, player: Player) -> void:
	var distance: float = 0.0
	var killer := players_root.get_node_or_null(str(killer_id)) as Player
	if killer != null:
		distance = killer.global_position.distance_to(player.global_position)
	# GDD kill reward: some health now, ammo for the weapon in hand (never for self-kills).
	if killer != null and killer != player and Match.state == Match.State.PLAYING:
		killer.status.server_kill_reward(Match.rules.kill_heal, Match.rules.kill_ammo)
	Match.server_register_kill(killer_id, player.get_multiplayer_authority(), weapon_name, headshot, distance, is_melee)
	get_tree().create_timer(Match.rules.respawn_delay).timeout.connect(_respawn.bind(player, player.get_life()))


## `life` is the life that died; a restart in between makes this timer stale.
func _respawn(player: Player, life: int) -> void:
	if not is_instance_valid(player) or player.is_alive or player.get_life() != life:
		return
	var spawn: Marker3D = _pick_spawn_point(player.get_multiplayer_authority())
	player.server_respawn(spawn.global_position, spawn.global_rotation.y)


## Offline test range only: respawn right now (the host is us, so no request is needed).
func test_respawn(player: Player) -> void:
	if not multiplayer.is_server() or not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var spawn: Marker3D = _pick_spawn_point(player.get_multiplayer_authority())
	player.server_respawn(spawn.global_position, spawn.global_rotation.y)


## Every peer; only the host acts: everyone respawns fresh for the new match.
func _on_match_started() -> void:
	if not multiplayer.is_server():
		return
	for grenade: Node in projectiles_root.get_children():
		grenade.queue_free() # A grenade from the end screen must not blow up the new match.
	for player: Player in _get_players():
		var spawn: Marker3D = _pick_spawn_point(player.get_multiplayer_authority())
		player.server_respawn(spawn.global_position, spawn.global_rotation.y)


func _on_peer_disconnected(peer_id: int) -> void:
	Match.server_remove_player(peer_id)
	for grenade: Node in projectiles_root.get_children():
		if (grenade is Grenade and (grenade as Grenade).thrower_id == peer_id) \
				or (grenade is ThrownKnife and (grenade as ThrownKnife).thrower_id == peer_id):
			grenade.queue_free()
	var player := players_root.get_node_or_null(str(peer_id)) as Player
	if player != null:
		# Leaving with an airdrop weapon drops it like dying does, so it stays in the match.
		var airdrops: AirdropManager = AirdropManager.find(get_tree())
		if player.is_alive and player.special_weapon >= 0 and airdrops != null:
			airdrops.server_drop_weapon(player.special_weapon, player.special_ammo, player.global_position)
		player.queue_free()


# --- Grenades --------------------------------------------------------------

func server_spawn_grenade(grenade_def: GrenadeDef, thrower_id: int, point: Vector3, velocity: Vector3) -> Grenade:
	assert(multiplayer.is_server(), "server_spawn_grenade is host-only")
	if grenade_def.max_per_thrower > 0:
		_limit_grenades(grenade_def, thrower_id, grenade_def.max_per_thrower - 1)
	var grenade: Node = projectile_spawner.spawn({
		"def": grenade_def.resource_path,
		"thrower": thrower_id,
		"position": point,
		"velocity": velocity,
	})
	for id: int in Net.ingame_peers:
		grenade.get_node("Sync").set_visibility_for(id, true)
	return grenade as Grenade


func server_spawn_knife(knife_def: WeaponDef, thrower_id: int, point: Vector3, velocity: Vector3) -> void:
	assert(multiplayer.is_server(), "server_spawn_knife is host-only")
	var knife: Node = projectile_spawner.spawn({
		"knife_def": knife_def.resource_path,
		"thrower": thrower_id,
		"position": point,
		"velocity": velocity,
	})
	for id: int in Net.ingame_peers:
		knife.get_node("Sync").set_visibility_for(id, true)


## Host: removes the oldest of this thrower's live grenades of this kind until `keep` remain.
func _limit_grenades(grenade_def: GrenadeDef, thrower_id: int, keep: int) -> void:
	var own: Array[Grenade] = []
	for node: Node in projectiles_root.get_children():
		var grenade := node as Grenade
		if grenade == null or grenade.is_queued_for_deletion():
			continue
		if grenade.thrower_id == thrower_id and grenade.def.resource_path == grenade_def.resource_path:
			own.append(grenade)
	while own.size() > keep:
		own.pop_front().queue_free() # Children are in spawn order: the oldest goes first.


## Host: a thrown knife that hit a player comes back after its timer.
func server_return_knife(thrower_id: int) -> void:
	var thrower := players_root.get_node_or_null(str(thrower_id)) as Player
	if thrower != null:
		thrower.status.server_return_throwable()


func _create_grenade(data: Variant) -> Node:
	var info: Dictionary = data
	if info.has("knife_def"):
		var knife_def: WeaponDef = load(info["knife_def"])
		var knife: ThrownKnife = knife_def.projectile.instantiate()
		knife.position = info["position"]
		knife.setup(knife_def, info["thrower"], info["velocity"])
		return knife
	var grenade_def: GrenadeDef = load(info["def"])
	var grenade: Grenade = grenade_def.projectile.instantiate()
	grenade.position = info["position"]
	grenade.setup(grenade_def, info["thrower"], info["velocity"])
	return grenade


## Host: applies a grenade's effect, then every peer draws the explosion.
func server_explode(grenade_def: GrenadeDef, thrower_id: int, point: Vector3) -> void:
	assert(multiplayer.is_server(), "server_explode is host-only")
	match grenade_def.kind:
		GrenadeDef.Kind.FRAG:
			_apply_frag(grenade_def, thrower_id, point)
		GrenadeDef.Kind.FLASH:
			_apply_flash(grenade_def, point)
	Net.broadcast(self, &"_explosion_fx", [grenade_def.resource_path, point])


func _apply_frag(grenade_def: GrenadeDef, thrower_id: int, point: Vector3) -> void:
	var origin: Vector3 = point + Vector3.UP * EXPLOSION_CENTER_OFFSET
	var thrower := players_root.get_node_or_null(str(thrower_id)) as Player
	var receivers: Array[Node3D] = []
	for player: Player in _get_players():
		receivers.append(player)
	for dummy: Node in get_tree().get_nodes_in_group(TargetDummy.GROUP):
		receivers.append(dummy as Node3D)

	for receiver: Node3D in receivers:
		var center: Vector3 = receiver.global_position + Vector3.UP * TARGET_CENTER_HEIGHT
		var distance: float = origin.distance_to(center)
		if distance > grenade_def.radius or not _has_line_of_sight(origin, center):
			continue
		if receiver.has_method(&"can_take_damage") and not receiver.call(&"can_take_damage"):
			continue
		var amount: float = grenade_def.damage * (1.0 - distance / grenade_def.radius)
		if receiver == thrower:
			amount *= grenade_def.self_damage_mult
		if grenade_def.knockback > 0.0 and receiver is Player:
			# Rocket blast pushes, the shooter included (rocket jump). Movement is the owner's.
			var push: Vector3 = (center - origin).normalized() * grenade_def.knockback * (1.0 - distance / grenade_def.radius)
			(receiver as Player).status.server_knockback(push)
		var killed: bool = receiver.call(&"take_hit", amount, Hitbox.Zone.BODY, thrower_id, grenade_def.display_name, false)
		var dealt: float = receiver.get(&"last_damage_dealt")
		if thrower != null and receiver != thrower and (dealt > 0.0 or killed):
			thrower.confirm_hit.rpc_id(thrower_id, Hitbox.Zone.BODY, killed, dealt, center)


func _apply_flash(grenade_def: GrenadeDef, point: Vector3) -> void:
	var origin: Vector3 = point + Vector3.UP * EXPLOSION_CENTER_OFFSET
	for player: Player in _get_players():
		if not player.is_alive:
			continue
		var eye: Vector3 = player.get_aim_origin()
		var distance: float = origin.distance_to(eye)
		if distance > grenade_def.radius or not _has_line_of_sight(origin, eye):
			continue
		var facing: float = player.get_look_forward().dot((origin - eye).normalized())
		var facing_factor: float = remap(clampf(facing, -1.0, 1.0), -1.0, 1.0, FLASH_MIN_FACING_FACTOR, 1.0)
		var distance_factor: float = 1.0 - FLASH_DISTANCE_FALLOFF * (distance / grenade_def.radius)
		player.flash.rpc_id(player.get_multiplayer_authority(), grenade_def.flash_duration * facing_factor * distance_factor)


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Host: blood where a player was hit, drawn on every peer (cosmetic).
func server_show_blood(point: Vector3, direction: Vector3) -> void:
	assert(multiplayer.is_server(), "server_show_blood is host-only")
	Net.broadcast(self, &"_blood_fx", [point, direction])


@rpc("any_peer", "call_local", "unreliable")
func _blood_fx(point: Vector3, direction: Vector3) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	ImpactEffects.spawn_blood(players_root, point, direction)


@rpc("any_peer", "call_local", "reliable")
func _explosion_fx(def_path: String, point: Vector3) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	var grenade_def := load(def_path) as GrenadeDef
	if grenade_def == null:
		return
	ShotEffects.spawn_explosion(self, point, grenade_def.kind == GrenadeDef.Kind.FLASH)
	Sfx.explosion(self, point, grenade_def.explosion_sound)


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(loadout: PackedInt32Array) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id in Net.ingame_peers:
		return
	_add_ingame_peer(peer_id, loadout)

extends Node
## Two-process network test over real ENet on localhost. Start the host first:
##   godot --headless --path . res://tests/net_test.tscn -- --role=host
##   godot --headless --path . res://tests/net_test.tscn -- --role=client
## Add --late to both: the host skips the lobby and the client joins the running match
## through the join loadout menu. Without it the client joins the lobby, readies up and the
## host starts the match.
## Covers: lobby / late join, spawning on both sides, loadout swap in the window and at the
## next spawn, held weapon, Shield, host damage, kill + kill reward + respawn, scope glint,
## a lag-compensated client shot that kills the host's player, and stage 6 state: a pickup
## boost, an airdrop weapon and a crate reaching the client.
## Each side prints PASS / FAIL lines and quits with exit code 1 when anything failed.
## Script errors in game code are not caught here: read Godot's output too.
## Both sides share user://, so the settings file is put back as it was at the end.

const CONNECT_TIMEOUT: float = 20.0
const STEP_TIMEOUT: float = 8.0
const TOTAL_TIMEOUT: float = 150.0
const MATCH_KILLS: int = 25
const TEST_DAMAGE: int = 30
const KILL_DAMAGE: float = 1000.0
const HOST_HEALTH_BEFORE_KILL: int = 50
const SHOT_DISTANCE: float = 6.0 ## The host's player stands this far from the client's.
const BODY_HEIGHT: float = 1.1 ## Body hitbox centre above the feet.
const SPOT_DIRECTIONS: int = 8
const WORLD_MASK: int = 1
const SCOPE_HOLD: float = 0.5 ## Client keeps the scope up this long after the host has it.
const SHOT_SETTLE: float = 0.6 ## Client waits this long once the host's player is in place.
const SPEED_PICKUP: PickupDef = preload("res://data/pickups/speed.tres")

var _passes: int = 0
var _failures: int = 0
var _role: String = ""
var _late: bool = false
var _peer: int = 0 ## Host: the client's peer id.
var _had_settings: bool = false
var _settings_backup: PackedByteArray = PackedByteArray()
var _died_by_host: bool = false ## Client: our death was announced, killed by the host.
var _kill_confirmed: bool = false ## Client: the host confirmed our shot killed.
var _finished: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg == "--late":
			_late = true
	get_tree().create_timer(TOTAL_TIMEOUT).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	# Net changes scenes; as a plain child of root we survive them.
	get_tree().current_scene = null
	_backup_settings()
	# Deterministic start whatever the user saved (in memory only, never written).
	Settings.loadout_class = &"wolf"
	Settings.loadout_primary = 0
	Settings.loadout_ability = 0
	match _role:
		"host":
			await _run_host()
		"client":
			await _run_client()
		_:
			_check(false, "--role=host or --role=client given")
	_finish()


# --- Host --------------------------------------------------------------------

func _run_host() -> void:
	if _late:
		Match.configure(MATCH_KILLS, 0.0)
		_check(Net.host_game("NetHost", Net.DEFAULT_PORT, false) == OK, "host started (no lobby)")
		_check(await _wait_until(func() -> bool: return _other_peer() != 0, CONNECT_TIMEOUT), "client registered")
		_peer = _other_peer()
	else:
		_check(Net.host_game("NetHost") == OK, "host started (lobby)")
		_check(await _wait_until(func() -> bool: return _other_peer() != 0, CONNECT_TIMEOUT), "client registered in the lobby")
		_peer = _other_peer()
		Net.server_set_lobby_settings(MATCH_KILLS, 0.0, 0)
		_check(await _wait_until(func() -> bool: return Net.ready_peers.get(_peer, false)), "client's ready flag reached the host")
		Net.server_start_match(MATCH_KILLS, 0.0, 0)
	if _peer == 0:
		return

	_check(await _wait_until(func() -> bool: return _find_player(_peer) != null, CONNECT_TIMEOUT), "client's player spawned on the host")
	var me: Player = _find_player(1)
	var them: Player = _find_player(_peer)
	if me == null or them == null:
		_check(false, "both players exist on the host")
		return
	_check(Match.rules.kill_target == MATCH_KILLS, "match uses the host's kill target")

	var bear_label: String = "client spawned with the loadout picked on join" if _late else "client's loadout request applied at once (swap window)"
	_check(await _wait_until(func() -> bool: return them.class_def.id == &"bear"), bear_label)
	_check(them.health == them.class_def.max_health, "client has Bear's health on the host (%d)" % them.health)
	_check(await _wait_until(func() -> bool: return them.held_slot == 1), "client's weapon switch reached the host (held_slot)")

	_check(await _wait_until(func() -> bool: return them.shield_up), "client's Shield raised on the host")
	_check(them.effects._shield_visual.visible, "host draws the client's shield panel")
	_check(await _wait_until(func() -> bool: return not them.shield_up), "Shield drops after its duration")

	_check(await _wait_until(func() -> bool: return them.can_take_damage()), "client can take damage")
	them.take_hit(TEST_DAMAGE, Hitbox.Zone.BODY, 1, "NetTest")
	_check(them.health == them.class_def.max_health - TEST_DAMAGE, "host damage applied (%d)" % them.health)

	_check(await _wait_until(func() -> bool: return them._pending_loadout.size() == 3), "client's next-spawn loadout stored on the host")
	me.health = HOST_HEALTH_BEFORE_KILL
	_check(them.take_hit(KILL_DAMAGE, Hitbox.Zone.HEAD, 1, "NetTest"), "host kills the client")
	_check(Match.get_kills(1) == 1, "kill registered for the host")
	_check(me.health == HOST_HEALTH_BEFORE_KILL + Match.rules.kill_heal, "kill reward heals the killer (%d)" % me.health)

	var respawned: bool = await _wait_until(func() -> bool: return them.is_alive, Match.rules.respawn_delay + STEP_TIMEOUT)
	_check(respawned and them.class_def.id == &"hawk", "client respawned with its next-spawn loadout (Hawk)")
	_check(them.health == them.class_def.max_health, "client respawned with full health (%d)" % them.health)

	_check(await _wait_until(func() -> bool: return them.scope_glint), "client's scope glint reached the host")
	_check(them.effects._glint.visible, "host draws the client's scope glint")
	_check(await _wait_until(func() -> bool: return not them.scope_glint), "glint goes off with the scope")

	var spot: Vector3 = _clear_spot_near(them)
	_check(spot.is_finite(), "found an open spot next to the client")
	if not spot.is_finite():
		return
	me.global_position = spot
	me.velocity = Vector3.ZERO
	me.reset_physics_interpolation()
	var shot: bool = await _wait_until(func() -> bool: return not me.is_alive, STEP_TIMEOUT * 2.0)
	_check(shot, "client's lag-compensated shot killed the host's player")
	_check(Match.get_kills(_peer) == 1, "kill registered for the client")

	# Stage 6: boost, airdrop weapon and a crate, all decided here and replicated.
	them.status.server_take_pickup(SPEED_PICKUP)
	_check(them.powerups != 0, "client's speed boost glow set on the host")
	them.give_special_weapon(_airdrop_index(&"rocket_launcher"), 6)
	var airdrops: AirdropManager = AirdropManager.find(get_tree())
	_check(airdrops != null and airdrops.server_drop() >= 0, "host drops a crate")
	_check(await _wait_until(func() -> bool: return them.held_slot == Player.SPECIAL_SLOT), "client took the airdrop weapon in hand")

	_check(await _wait_until(func() -> bool: return _find_player(_peer) == null, STEP_TIMEOUT * 2.0), "client's player removed after it left")


## A standing spot SHOT_DISTANCE from `target` with floor under it and a clear view from its eye.
func _clear_spot_near(target: Player) -> Vector3:
	var space: PhysicsDirectSpaceState3D = target.get_world_3d().direct_space_state
	var eye: Vector3 = target.get_aim_origin()
	for i: int in SPOT_DIRECTIONS:
		var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / SPOT_DIRECTIONS)
		var spot: Vector3 = target.global_position + dir * SHOT_DISTANCE
		var open: bool = _ray_clear(space, eye, spot + Vector3.UP * BODY_HEIGHT) \
			and _ray_clear(space, eye, spot + Vector3.UP * 0.3)
		var floored: bool = not _ray_clear(space, spot + Vector3.UP * 0.5, spot + Vector3.DOWN * 0.5)
		if open and floored:
			return spot + Vector3.UP * 0.05
	return Vector3.INF


func _ray_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)).is_empty()


# --- Client ------------------------------------------------------------------

func _run_client() -> void:
	Net.ask_loadout_on_join = _late
	_check(Net.join_game("NetClient", "127.0.0.1") == OK, "client started")
	var bear: PackedInt32Array = _code(&"bear", &"sledgehammer", &"shield")
	var hawk: PackedInt32Array = _code(&"hawk", &"heavy_rifle", &"grapple")

	if _late:
		_check(await _wait_until(func() -> bool: return Game.find(get_tree()) != null, CONNECT_TIMEOUT), "joined the running match")
		var game: Game = Game.find(get_tree())
		if game == null:
			return
		var menu := game.get_node("HUD/LoadoutMenu") as LoadoutMenu
		_check(await _wait_until(func() -> bool: return menu.visible), "join loadout menu shown before spawning")
		_check(_find_player(multiplayer.get_unique_id()) == null, "no player before the loadout is picked")
		menu.open(bear)
		var deploy: Button = _find_button(menu, "DEPLOY")
		_check(deploy != null, "loadout menu has DEPLOY")
		if deploy == null:
			return
		deploy.pressed.emit()
	else:
		_check(await _wait_until(func() -> bool: return Net.in_lobby, CONNECT_TIMEOUT), "joined the host's lobby")
		_check(await _wait_until(func() -> bool: return Net.lobby_kill_target == MATCH_KILLS), "lobby settings reached the client")
		Net.request_lobby_ready(true)
		_check(await _wait_until(func() -> bool: return Game.find(get_tree()) != null, CONNECT_TIMEOUT), "followed the host into the match")

	var my_id: int = multiplayer.get_unique_id()
	_check(await _wait_until(func() -> bool: return _find_player(my_id) != null and _find_player(1) != null, CONNECT_TIMEOUT),
		"own player and the host's player spawned")
	var me: Player = _find_player(my_id)
	var host_player: Player = _find_player(1)
	if me == null or host_player == null:
		return
	Events.player_died.connect(_on_player_died)
	Events.hit_confirmed.connect(_on_hit_confirmed)

	if not _late:
		me.request_loadout(bear) # Inside the swap window: applies at once.
	_check(await _wait_until(func() -> bool: return me.class_def.id == &"bear"), "Bear loadout came back from the host")

	me.equip(1)
	_check(await _wait_until(func() -> bool: return me.held_slot == 1), "held_slot came back from the host")

	_check(me.ability != null and me.ability.try_use(me.get_aim_origin(), -me.get_aim_basis().z), "Shield usable on the owner")
	me.requests.send_ability(me.get_aim_origin(), -me.get_aim_basis().z)
	_check(await _wait_until(func() -> bool: return me.shield_up), "own shield_up replicated back")
	_check(not me.effects._shield_visual.visible, "owner does not draw its own shield panel")
	_check(await _wait_until(func() -> bool: return not me.shield_up), "own shield drops")

	var hurt_health: int = me.class_def.max_health - TEST_DAMAGE
	_check(await _wait_until(func() -> bool: return me.health == hurt_health), "host damage replicated (%d)" % me.health)

	me.request_loadout(hawk) # Outside the swap window: waits for the next spawn.
	_check(await _wait_until(func() -> bool: return not me.is_alive), "own death replicated")
	_check(await _wait_until(func() -> bool: return _died_by_host), "death announced with the host as killer")
	_check(await _wait_until(func() -> bool: return Match.get_kills(1) == 1), "host's kill counted on the client")
	var respawned: bool = await _wait_until(func() -> bool: return me.is_alive and me.class_def.id == &"hawk", Match.rules.respawn_delay + STEP_TIMEOUT)
	_check(respawned, "respawned as Hawk")
	_check(me.health == me.class_def.max_health, "respawned with full health (%d)" % me.health)

	# No real input in headless: hold the scope by hand while physics (which re-reports it) is off.
	me.set_physics_process(false)
	me.effects.report_scoped(true)
	_check(await _wait_until(func() -> bool: return me.scope_glint), "own scope_glint replicated back")
	await _seconds(SCOPE_HOLD)
	me.effects.report_scoped(false)
	me.set_physics_process(true)
	_check(await _wait_until(func() -> bool: return not me.scope_glint), "scope_glint cleared")

	var in_place: bool = await _wait_until(
		func() -> bool: return host_player.global_position.distance_to(me.global_position) < SHOT_DISTANCE + 1.0)
	_check(in_place, "host's player came next to us")
	await _seconds(SHOT_SETTLE)
	var origin: Vector3 = me.get_aim_origin()
	var target: Vector3 = host_player.global_position + Vector3.UP * BODY_HEIGHT
	me.requests.send_fire(origin, (target - origin).normalized(), 0)
	_check(await _wait_until(func() -> bool: return _kill_confirmed), "host confirmed our Heavy Rifle kill")
	_check(await _wait_until(func() -> bool: return Match.get_kills(my_id) == 1), "our kill counted on the client")

	_check(await _wait_until(func() -> bool: return me.status.get_speed_mult() > 1.0 and me.powerups != 0),
		"speed boost reached the owner")
	_check(await _wait_until(func() -> bool: return me.weapons.size() == 3 and me.special_ammo == 6),
		"airdrop weapon replicated with its rounds")
	_check(await _wait_until(func() -> bool: return me.current_weapon == me.weapons[me.weapons.size() - 1]),
		"airdrop weapon in hand")
	_check(await _wait_until(func() -> bool:
		var airdrops: AirdropManager = AirdropManager.find(get_tree())
		return airdrops != null and not airdrops._crates.is_empty()), "crate appeared on the client")
	await _seconds(0.5) # Let the host see held_slot before we leave.


func _on_player_died(victim: Player, killer_id: int, _weapon_name: String, _killer_health: int) -> void:
	if victim.is_local and killer_id == 1:
		_died_by_host = true


func _on_hit_confirmed(_zone: Hitbox.Zone, killed: bool, _amount: float) -> void:
	if killed:
		_kill_confirmed = true


func _code(class_id: StringName, primary_id: StringName, ability_id: StringName) -> PackedInt32Array:
	var classes: Array[ClassDef] = Loadout.roster().classes
	for ci: int in classes.size():
		if classes[ci].id != class_id:
			continue
		var primary: int = 0
		for wi: int in classes[ci].primary_weapons.size():
			if classes[ci].primary_weapons[wi].id == primary_id:
				primary = wi
		var ability: int = 0
		for ai: int in classes[ci].abilities.size():
			if classes[ci].abilities[ai].id == ability_id:
				ability = ai
		return Loadout.make(ci, primary, ability)
	return Loadout.default_code()


func _airdrop_index(id: StringName) -> int:
	var weapons: Array[WeaponDef] = AirdropWeapons.roster().weapons
	for i: int in weapons.size():
		if weapons[i].id == id:
			return i
	return -1


func _find_button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


# --- Helpers -----------------------------------------------------------------

func _other_peer() -> int:
	for peer_id: int in Net.player_names:
		if peer_id != 1:
			return peer_id
	return 0


func _find_player(peer_id: int) -> Player:
	var game: Game = Game.find(get_tree())
	if game == null or game.players_root == null:
		return null
	return game.players_root.get_node_or_null(str(peer_id)) as Player


func _wait_until(condition: Callable, timeout: float = STEP_TIMEOUT) -> bool:
	var deadline: float = _now() + timeout
	while not condition.call():
		if _now() > deadline:
			return false
		await get_tree().physics_frame
	return true


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _backup_settings() -> void:
	_had_settings = FileAccess.file_exists(Settings.PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(Settings.PATH)


func _restore_settings() -> void:
	if _had_settings:
		var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_settings_backup)
	elif FileAccess.file_exists(Settings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("NET TEST (%s%s): %d passed, %d failed" % [_role, ", late join" if _late else "", _passes, _failures])
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		Net.leave() # The Leave Game path: closes the connection, back to the main menu.
	_restore_settings()
	get_tree().quit(1 if _failures > 0 else 0)


func _on_timeout() -> void:
	_check(false, "finished within %d s" % roundi(TOTAL_TIMEOUT))
	_finish()

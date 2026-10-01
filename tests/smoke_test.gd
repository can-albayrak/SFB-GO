extends Node
## Headless smoke test, no second player needed:
##   godot --headless --path . res://tests/smoke_test.tscn
## Opens an offline match on the test range (same code path as Test Range), then for every
## class: loadouts apply, every primary / secondary / quick melee damages a dummy, every
## ability runs on the host; plus kill reward, held weapon sync and the menu panels.
## Prints PASS / FAIL lines and quits with exit code 1 when anything failed.
## Script errors in game code are not caught here: read Godot's output too.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const LOBBY_SCENE: PackedScene = preload("res://scenes/lobby.tscn")
const HITSCAN_DISTANCE: float = 4.0
const MELEE_DISTANCE: float = 1.2
const LAUNCH_DISTANCE: float = 6.0
const DUMMY_HEALTH: float = 100000.0
const BODY_HEIGHT: float = 1.1 ## Dummy body hitbox centre above its feet.
const PROJECTILE_WAIT: float = 1.5 ## Seconds for launcher rounds and thrown knives to land.
const MINE_SETTLE_WAIT: float = 2.5
const TIMEOUT: float = 240.0

var _passes: int = 0
var _failures: int = 0
var _game: Game
var _player: Player
var _dummy: TargetDummy
var _away: Vector3 = Vector3.FORWARD ## Flat direction from the dummy toward open ground.


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.player_names[1] = "Tester"
	Net.map_path = Net.DEFAULT_MAP_PATH
	Match.configure(0, 0.0)
	_game = GAME_SCENE.instantiate() as Game
	add_child(_game)
	await _frames(5)

	_player = _game.players_root.get_node_or_null("1") as Player
	_check(_player != null, "local player spawned")
	var dummies: Array[Node] = get_tree().get_nodes_in_group(TargetDummy.GROUP)
	_check(not dummies.is_empty(), "test range has dummies")
	if _player == null or dummies.is_empty():
		_finish()
		return
	_dummy = dummies[0] as TargetDummy
	var spawn := _game.get_node("Map/SpawnPoints").get_child(0) as Marker3D
	var flat: Vector3 = spawn.global_position - _dummy.global_position
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		_away = flat.normalized()

	await _test_loadouts()
	await _test_weapons()
	await _test_abilities()
	await _test_kill_reward()
	await _test_quick_switch()
	await _test_swap_rules()
	await _test_pickups()
	await _test_airdrop()
	await _test_airdrop_weapons()
	await _test_held_weapon()
	await _test_respawn()
	await _test_ui()
	_finish()


# --- Tests -------------------------------------------------------------------

func _test_loadouts() -> void:
	var roster: ClassRoster = Loadout.roster()
	for ci: int in roster.classes.size():
		var class_def: ClassDef = roster.classes[ci]
		for wi: int in class_def.primary_weapons.size():
			for ai: int in maxi(class_def.abilities.size(), 1):
				var code: PackedInt32Array = Loadout.make(ci, wi, ai)
				await _set_loadout(code)
				var ok: bool = _player.class_def == class_def and _player.weapons.size() == 2 \
					and _player.weapons[0].def == class_def.primary_weapons[wi] \
					and (class_def.abilities.is_empty() or _player.ability != null)
				_check(ok, "loadout %s" % Loadout.describe(code))


func _test_weapons() -> void:
	var roster: ClassRoster = Loadout.roster()
	for ci: int in roster.classes.size():
		var class_def: ClassDef = roster.classes[ci]
		for wi: int in class_def.primary_weapons.size():
			await _set_loadout(Loadout.make(ci, wi, 0))
			await _fire_slot(0, "%s %s" % [class_def.display_name, class_def.primary_weapons[wi].display_name])
		await _set_loadout(Loadout.make(ci, 0, 0))
		await _fire_slot(1, "%s secondary %s" % [class_def.display_name, class_def.secondary_weapon.display_name])
		if _player.melee_weapon != null:
			await _quick_melee("%s quick melee %s" % [class_def.display_name, _player.melee_weapon.def.display_name])


func _test_abilities() -> void:
	var roster: ClassRoster = Loadout.roster()
	for ci: int in roster.classes.size():
		var class_def: ClassDef = roster.classes[ci]
		for ai: int in class_def.abilities.size():
			await _set_loadout(Loadout.make(ci, 0, ai))
			var ability: Ability = _player.ability
			var label: String = "%s ability %s" % [class_def.display_name, class_def.abilities[ai].display_name]
			if ability == null:
				_check(false, label + " exists")
				continue
			await _place(HITSCAN_DISTANCE)
			var origin: Vector3 = _player.get_aim_origin()
			var dir: Vector3 = (_dummy_target() - origin).normalized()
			var projectiles_before: int = _game.projectiles_root.get_child_count()
			ability.host_ready_at = -INF
			_check(ability.server_try_use(origin, dir), label + " accepted by the host")
			await _frames(2)
			if ability.def is GrenadeDef:
				_check(_game.projectiles_root.get_child_count() > projectiles_before, label + " spawns its projectile")
				if (ability.def as GrenadeDef).trigger_radius > 0.0:
					await _check_mine_settles(label)
			elif ability is ShieldAbility:
				_check(_player.shield_up, label + " raises the shield")
			elif ability is AdrenalineAbility:
				_check(_player.status.get_host_speed_mult() > 1.0, label + " boosts on the host")
			elif ability is DashAbility:
				ability.cooldown_left = 0.0
				ability.try_use(origin, dir)
				_check(_player.movement.is_dashing(), label + " starts a dash on the owner")
			_clear_projectiles()
			_player.status.reset_host()
			_player.status.reset_local()


func _test_kill_reward() -> void:
	await _set_loadout(Loadout.make(0, 0, 0))
	_player.health = 50
	_player.current_weapon.ammo = 5
	_player.status.server_kill_reward(20, 15)
	await _frames(2)
	_check(_player.health == 70, "kill reward heals 20 (health %d)" % _player.health)
	_check(_player.current_weapon.ammo == 20, "kill reward adds 15 rounds (ammo %d)" % _player.current_weapon.ammo)
	_player.health = _player.class_def.max_health


## Hawk: Heavy Rifle, then the pistol at once. Each slot has its own host fire budget.
func _test_quick_switch() -> void:
	await _set_loadout(_code_for(&"hawk"))
	await _place(HITSCAN_DISTANCE)
	_player.requests.reset_fire_budgets()
	for slot: int in 2:
		_dummy.health = DUMMY_HEALTH
		var origin: Vector3 = _player.get_aim_origin()
		_player.requests._request_fire(origin, (_dummy_target() - origin).normalized(), slot, _player.weapons[slot].def.id)
		await _frames(1)
		_check(_dummy.health < DUMMY_HEALTH, "quick switch: slot %d shot accepted right after the other" % slot)


## Inside the swap window: hurt players never refill by swapping, and a swap drops the Shield.
func _test_swap_rules() -> void:
	var bear: PackedInt32Array = _code_for(&"bear")
	await _set_loadout(bear)
	_player._spawned_at = Time.get_ticks_usec() / 1_000_000.0
	_player._hurt_since_spawn = false
	_player.is_protected = false
	_player.health = _player.class_def.max_health
	_player.ability.host_ready_at = -INF
	_player.ability.server_try_use(_player.get_aim_origin(), Vector3.FORWARD)
	_player.server_choose_loadout(_code_for(&"cheetah"))
	await _frames(1)
	_check(not _player.shield_up, "loadout swap drops the Shield")
	_player.server_choose_loadout(bear)
	await _frames(1)
	_check(_player.health == _player.class_def.max_health, "unhurt swap gives full health (%d)" % _player.health)
	_player.take_hit(55.0, Hitbox.Zone.BODY, 0, "Test")
	_player.server_choose_loadout(_code_for(&"cheetah"))
	_player.server_choose_loadout(bear)
	await _frames(1)
	_check(_player.health < _player.class_def.max_health, "hurt swap does not refill (%d)" % _player.health)
	_player.status.reset_host()
	_player.health = _player.class_def.max_health


## Each pickup kind on the test range: taken by walking onto it, effect applied, then gone.
func _test_pickups() -> void:
	await _set_loadout(Loadout.make(0, 0, 0))
	_player.is_protected = false
	for node: Node in get_tree().get_nodes_in_group(Pickup.GROUP):
		var pickup := node as Pickup
		pickup.server_reset()
		var label: String = "pickup %s" % pickup.def.display_name
		_player.health = 30
		_player.global_position = pickup.global_position + Vector3.UP * 0.05
		_player.velocity = Vector3.ZERO
		await _frames(3)
		_check(not pickup.available, label + " taken")
		match pickup.def.kind:
			PickupDef.Kind.HEALTH:
				_check(_player.health == 30 + pickup.def.heal, label + " heals (%d)" % _player.health)
			PickupDef.Kind.SPEED:
				_check(_player.status.get_host_speed_mult() > 1.0 and _player.status.get_speed_mult() > 1.0,
					label + " speeds up on host and owner")
				_check(_player.powerups & (1 << PickupDef.Kind.SPEED) != 0, label + " glow replicated state")
			PickupDef.Kind.DOUBLE_JUMP:
				_check(_player.status.has_double_jump(), label + " gives a double jump")
		_player.global_position = _dummy.global_position + _away * 10.0 # Off the spot first.
		await _frames(2)
		pickup.server_reset()
		await _frames(2)
		_check(pickup.available, label + " back after its timer")
	_player.status.reset_host()
	_player.status.reset_local()
	_player.health = _player.class_def.max_health


## A crate drops, lands and opens after holding E for the open time; the opener gets a weapon.
func _test_airdrop() -> void:
	var airdrops: AirdropManager = AirdropManager.find(get_tree())
	_check(airdrops != null, "airdrop manager exists")
	if airdrops == null:
		return
	await _set_loadout(Loadout.make(0, 0, 0))
	var id: int = airdrops.server_drop()
	_check(id >= 0, "airdrop crate dropped on a point")
	await _frames(1)
	var crate: AirdropCrate = airdrops._crates.get(id)
	if crate == null:
		_check(false, "airdrop crate exists")
		return
	airdrops.server_land_all()
	_player.global_position = crate.landing_point + Vector3(1.0, 0.05, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(2)
	# The player's own tick would report "E not held" (no input in headless): hold it here instead.
	_player.set_physics_process(false)
	var waited: float = 0.0
	while _player.special_weapon < 0 and waited < Match.rules.airdrop_open_time + 1.5:
		airdrops.tick_local(_player, true)
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	airdrops.tick_local(_player, false)
	_player.set_physics_process(true)
	_check(_player.special_weapon >= 0 and _player.weapons.size() == 3, "holding E opens the crate and gives an airdrop weapon")
	_check(_player.current_weapon == _player.weapons[Player.SPECIAL_SLOT], "airdrop weapon taken in hand")
	_check(not airdrops._crates.has(id), "opened crate is removed")
	_player.special_weapon = -1


func _test_airdrop_weapons() -> void:
	await _set_loadout(Loadout.make(0, 0, 0))
	_player.is_protected = false
	var railgun: int = _airdrop_index(&"railgun")
	var minigun: int = _airdrop_index(&"minigun")
	var rocket: int = _airdrop_index(&"rocket_launcher")

	# Railgun through the backstop wall: shooter north of it, the 55 m dummy south of it.
	_player.give_special_weapon(railgun, 8)
	await _frames(2)
	var far_dummy: TargetDummy = _dummy_nearest(Vector3(0.0, 0.0, -35.0))
	_player.global_position = Vector3(0.0, 0.05, -46.0)
	_player.velocity = Vector3.ZERO
	await _frames(2)
	far_dummy.health = DUMMY_HEALTH
	_player.requests.reset_fire_budgets()
	var origin: Vector3 = _player.get_aim_origin()
	var target: Vector3 = far_dummy.global_position + Vector3.UP * BODY_HEIGHT
	_player.requests._request_fire(origin, (target - origin).normalized(), Player.SPECIAL_SLOT, &"railgun")
	await _frames(1)
	_check(far_dummy.health < DUMMY_HEALTH, "railgun hits through a wall (%.0f)" % (DUMMY_HEALTH - far_dummy.health))
	_check(_player.special_ammo == 7, "host counts airdrop rounds (%d)" % _player.special_ammo)
	_player.special_ammo = 1
	_player.requests.reset_fire_budgets()
	_player.requests._request_fire(origin, (target - origin).normalized(), Player.SPECIAL_SLOT, &"railgun")
	await _frames(1)
	_check(_player.special_weapon == -1 and _player.weapons.size() == 2, "empty airdrop weapon disappears")

	# Minigun spins up before firing.
	_player.give_special_weapon(minigun, 200)
	await _frames(2)
	var gun: Weapon = _player.weapons[Player.SPECIAL_SLOT]
	gun._cooldown = 0.0
	var cmd := PlayerCommand.new()
	cmd.fire = true
	cmd.fire_pressed = true
	gun.tick(0.1, cmd)
	_check(gun.ammo == 200, "minigun does not fire before spinning up")
	for i: int in 10:
		gun.tick(0.1, cmd)
	_check(gun.ammo < 200, "minigun fires once spun up (%d)" % gun.ammo)
	_player.special_weapon = -1

	# Rocket at your own feet pushes you up (rocket jump).
	_player.give_special_weapon(rocket, 6)
	await _place(HITSCAN_DISTANCE)
	_player.health = _player.class_def.max_health
	_player.requests.reset_fire_budgets()
	origin = _player.get_aim_origin()
	var feet: Vector3 = _player.global_position + _away * 1.0
	_player.requests._request_fire(origin, (feet - origin).normalized(), Player.SPECIAL_SLOT, &"rocket_launcher")
	var pushed: bool = false
	for i: int in 30:
		await get_tree().physics_frame
		if _player.velocity.y > 1.0:
			pushed = true
			break
	_check(pushed, "rocket blast pushes the shooter (rocket jump)")
	_check(_player.health < _player.class_def.max_health, "rocket hurts the shooter a little (%d)" % _player.health)
	_clear_projectiles()

	# Dying drops the weapon with its rounds; walking over it picks it up.
	var airdrops: AirdropManager = AirdropManager.find(get_tree())
	_player.give_special_weapon(rocket, 4)
	await _frames(1)
	var drops_before: int = airdrops._drops.size()
	_player.server_fall_death()
	await _frames(1)
	_check(airdrops._drops.size() == drops_before + 1 and _player.special_weapon == -1, "carrier's death drops the weapon")
	_game.test_respawn(_player)
	await _frames(2)
	var drop: WeaponDrop = airdrops._drops.values().back()
	_player.global_position = drop.position + Vector3.UP * 0.05
	_player.velocity = Vector3.ZERO
	await _frames(3)
	_check(_player.special_weapon == rocket and _player.special_ammo == 4, "walking over a dropped weapon picks it up with its rounds")
	_player.special_weapon = -1
	_player.health = _player.class_def.max_health


func _airdrop_index(id: StringName) -> int:
	var weapons: Array[WeaponDef] = AirdropWeapons.roster().weapons
	for i: int in weapons.size():
		if weapons[i].id == id:
			return i
	return -1


func _dummy_nearest(point: Vector3) -> TargetDummy:
	var best: TargetDummy = null
	for node: Node in get_tree().get_nodes_in_group(TargetDummy.GROUP):
		var dummy := node as TargetDummy
		if best == null or dummy.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = dummy
	return best


func _code_for(class_id: StringName) -> PackedInt32Array:
	var classes: Array[ClassDef] = Loadout.roster().classes
	for i: int in classes.size():
		if classes[i].id == class_id:
			return Loadout.make(i, 0, 0)
	return Loadout.default_code()


func _test_held_weapon() -> void:
	_player.held_slot = 1
	await _frames(1)
	var held: Node = _player.hand.get_child(_player.hand.get_child_count() - 1)
	_check(_player.hand.get_child_count() >= 2 and not (held is Marker3D), "held weapon model shown in the hand")
	_player.held_slot = 0


func _test_respawn() -> void:
	_game.test_respawn(_player)
	await _frames(3)
	_check(_player.is_alive and _player.health == _player.class_def.max_health, "test respawn restores the player")


func _test_ui() -> void:
	var panel := SettingsPanel.new()
	add_child(panel)
	panel.open()
	await _frames(1)
	_check(panel.visible, "settings panel opens")
	panel.visible = false # Not close(): that would rewrite the user's settings file.
	panel.queue_free()
	var lobby: Node = LOBBY_SCENE.instantiate()
	add_child(lobby)
	await _frames(2)
	_check(lobby.get_child_count() > 0, "lobby builds its UI")
	lobby.queue_free()


# --- Helpers -----------------------------------------------------------------

func _fire_slot(slot: int, label: String) -> void:
	var def: WeaponDef = _player.weapons[slot].def
	var distance: float = HITSCAN_DISTANCE
	if def.fire_type == WeaponDef.FireType.MELEE:
		distance = MELEE_DISTANCE
	elif def.fire_type == WeaponDef.FireType.PROJECTILE:
		distance = LAUNCH_DISTANCE
	await _place(distance)
	_dummy.health = DUMMY_HEALTH
	_player.requests.reset_fire_budgets()
	var origin: Vector3 = _player.get_aim_origin()
	_player.requests._request_fire(origin, (_dummy_target() - origin).normalized(), slot, def.id)
	var instant: bool = def.fire_type == WeaponDef.FireType.HITSCAN or def.fire_type == WeaponDef.FireType.MELEE
	if instant:
		await _frames(1)
	else:
		await get_tree().create_timer(PROJECTILE_WAIT).timeout
	var dealt: float = DUMMY_HEALTH - _dummy.health
	_check(dealt > 0.0, "%s damages the dummy (%.0f)" % [label, dealt])
	if def.fire_type == WeaponDef.FireType.HITSCAN and def.pellet_pattern.is_empty() and dealt > 0.0:
		_check(_is_zone_damage(def, dealt), "%s deals %.0f (zone damage of %.0f)" % [label, dealt, def.damage])
	_clear_projectiles()


func _quick_melee(label: String) -> void:
	await _place(MELEE_DISTANCE)
	_dummy.health = DUMMY_HEALTH
	_player.requests._next_melee_time = -INF
	var origin: Vector3 = _player.get_aim_origin()
	_player.requests._request_melee(origin, (_dummy_target() - origin).normalized())
	await _frames(1)
	var dealt: float = DUMMY_HEALTH - _dummy.health
	_check(dealt > 0.0 and _is_zone_damage(_player.melee_weapon.def, dealt), "%s deals %.0f" % [label, dealt])


func _check_mine_settles(label: String) -> void:
	await get_tree().create_timer(MINE_SETTLE_WAIT).timeout
	var settled: bool = false
	for node: Node in _game.projectiles_root.get_children():
		var mine := node as Grenade
		if mine != null and mine.def.trigger_radius > 0.0 and mine._stuck:
			settled = true
	_check(settled, label + " settles on the ground")


func _is_zone_damage(def: WeaponDef, dealt: float) -> bool:
	for zone: Hitbox.Zone in [Hitbox.Zone.HEAD, Hitbox.Zone.BODY, Hitbox.Zone.LEG]:
		if absf(dealt - roundf(def.damage * def.zone_multiplier(zone))) <= 1.0:
			return true
	return false


func _set_loadout(code: PackedInt32Array) -> void:
	_player.loadout = code
	await _frames(2)


## Stands the player `distance` metres from the dummy on the open side.
func _place(distance: float) -> void:
	_player.global_position = _dummy.global_position + _away * distance + Vector3.UP * 0.05
	_player.velocity = Vector3.ZERO
	await _frames(2)


func _dummy_target() -> Vector3:
	return _dummy.global_position + Vector3.UP * BODY_HEIGHT


func _clear_projectiles() -> void:
	for node: Node in _game.projectiles_root.get_children():
		node.queue_free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)


func _finish() -> void:
	print("SMOKE TEST: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _on_timeout() -> void:
	_check(false, "finished within %d s" % roundi(TIMEOUT))
	_finish()

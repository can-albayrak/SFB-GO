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
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
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
	await _test_smoke_break()
	await _test_new_class_abilities()
	await _test_kill_reward()
	await _test_quick_switch()
	await _test_scope_and_spread()
	await _test_knife_speed()
	await _test_spray()
	await _test_backstab()
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
				var ok: bool = _player.class_def == class_def and _player.weapons.size() == 3 \
					and _player.weapons[0].def == class_def.primary_weapons[wi] \
					and _player.weapons[Player.KNIFE_SLOT].def == class_def.knife \
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
		await _fire_slot(Player.KNIFE_SLOT, "%s knife (slot 3)" % class_def.display_name)
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
				_check(_player.status.get_host_speed_mult() > 1.0 or _player.status.get_host_fire_rate_mult() > 1.0,
					label + " boosts on the host")
			elif ability is DashAbility:
				ability.cooldown_left = 0.0
				ability.try_use(origin, dir)
				_check(_player.movement.is_dashing(), label + " starts a dash on the owner")
			_clear_projectiles()
			_player.status.reset_host()
			_player.status.reset_local()


## Hound Sonar, Ghost Cloak, Trickster Swap Dart, Phantom Mark / Recall, against a second
## (fake, remote-owned) player standing in front.
func _test_new_class_abilities() -> void:
	await _place(HITSCAN_DISTANCE)
	var fake: Player = PLAYER_SCENE.instantiate()
	fake.name = "77"
	fake.setup_authority(77)
	_game.players_root.add_child(fake)
	var forward: Vector3 = -_away
	forward.y = 0.0
	forward = forward.normalized()
	fake.global_position = _player.global_position + forward * 6.0
	await _frames(3)

	await _set_loadout(_code_for(&"hound"))
	_player.ability.host_ready_at = -INF
	_check(_player.ability.server_try_use(_player.get_aim_origin(), forward), "Hound Sonar accepted")
	await _frames(2)
	var body := fake.rig.get_node("Body/Skeleton3D/Body") as GeometryInstance3D
	_check(body.material_overlay != null, "Hound Sonar shows the other player through walls")

	await _set_loadout(_code_for(&"ghost"))
	_player.ability.host_ready_at = -INF
	_player.ability.server_try_use(_player.get_aim_origin(), forward)
	_check(_player.cloaked, "Ghost Cloak cloaks on the host")
	await _fire_slot(0, "Ghost MP5SD while cloaked")
	_check(not _player.cloaked, "Ghost firing ends the cloak")

	await _set_loadout(_code_for(&"trickster"))
	fake.loadout = _code_for(&"hound") # Scout.
	fake.give_special_weapon(0, 5)
	await _frames(2)
	var my_primary: WeaponDef = _player.weapons[0].def
	var their_primary: WeaponDef = fake.weapons[0].def
	var my_pistol: WeaponDef = _player.weapons[1].def
	fake.global_position = _player.global_position + forward * 6.0
	await _frames(2)
	var mine: Vector3 = _player.global_position
	var theirs: Vector3 = fake.global_position
	var aim_from: Vector3 = _player.get_aim_origin()
	var aim_dir: Vector3 = (theirs + Vector3.UP * BODY_HEIGHT - aim_from).normalized()
	_player.ability.host_ready_at = -INF
	_check(_player.ability.server_try_use(aim_from, aim_dir), "Trickster Swap Dart accepted")
	await _frames(20)
	_check(_player.global_position.distance_to(theirs) < 0.5 and fake.global_position.distance_to(mine) < 0.5,
		"Trickster Swap Dart swaps places with the player it hits")
	_check(_player.weapons[0].def == their_primary and fake.weapons[0].def == my_primary,
		"Swap Dart trades primaries (%s <-> %s)" % [my_primary.display_name, their_primary.display_name])
	_check(_player.weapons[1].def == my_pistol, "Swap Dart keeps the pistol")
	_check(_player.special_weapon == 0 and _player.special_ammo == 5 and fake.special_weapon == -1,
		"Swap Dart takes the target's airdrop weapon")
	_player.special_weapon = -1

	await _test_gambler(fake)

	await _set_loadout(_code_for(&"phantom"))
	var ability: Ability = _player.ability
	ability.host_ready_at = -INF
	var mark: Vector3 = _player.global_position
	_check(ability.server_try_use(mark, forward), "Phantom Mark accepted")
	await _frames(2)
	_check(_player.get_parent().get_node_or_null("PhantomMark") != null, "Phantom Mark is shown")
	_player.global_position = mark + forward * 4.0
	await _frames(2)
	_check(ability.server_try_use(_player.get_aim_origin(), forward), "Phantom Recall accepted inside the window")
	await _frames(2)
	_check(_player.global_position.distance_to(mark) < 0.5, "Phantom Recall teleports back to the mark")
	_check(_player.get_parent().get_node_or_null("PhantomMark") == null, "Phantom Recall removes the mark")
	_check(not ability.server_try_use(_player.get_aim_origin(), forward), "Phantom is on cooldown after recalling")

	fake.queue_free()
	await _set_loadout(Loadout.default_code())
	await _frames(2)


## Gambler's dice: every face does what it says (host + owner parts).
func _test_gambler(fake: Player) -> void:
	await _set_loadout(_code_for(&"gambler"))
	var dice := _player.ability as DiceAbility
	_check(dice != null and dice.def.dice_faces.size() == 6, "Gambler has a six-sided die")
	if dice == null:
		return
	var moods: Array[int] = []
	for face: DiceFaceDef in dice.def.dice_faces:
		moods.append(face.mood)
	_check(moods.count(DiceFaceDef.Mood.GOOD) == 3 and moods.count(DiceFaceDef.Mood.NEUTRAL) == 1
		and moods.count(DiceFaceDef.Mood.BAD) == 1 and moods.count(DiceFaceDef.Mood.VERY_BAD) == 1,
		"die: 3 good, 1 neutral, 1 bad, 1 very bad")
	for index: int in dice.def.dice_faces.size():
		var face: DiceFaceDef = dice.def.dice_faces[index]
		_player.health = 50
		_player.status.reset_host()
		_player.status.reset_local()
		dice.server_apply_face(index)
		await _frames(2)
		_check(dice.get_hud_window().size() == 4 and dice.get_hud_window()[2] == face.title, "%s shows on the HUD" % face.title)
		match face.kind:
			DiceFaceDef.Kind.DAMAGE:
				_check(is_equal_approx(_player.status.get_host_damage_mult(), face.damage_mult), "%s: damage x%.1f" % [face.title, face.damage_mult])
				fake.is_protected = false
				fake.health = 100
				fake.take_hit(20.0, Hitbox.Zone.BODY, _player.get_multiplayer_authority(), "Test")
				_check(fake.health == 100 - roundi(20.0 * face.damage_mult), "%s: a 20 hit deals %d" % [face.title, 100 - fake.health])
			DiceFaceDef.Kind.HOT_HAND:
				_check(_player.status.has_free_ammo() and _player.status.get_host_fire_rate_mult() > 1.0, "%s: free ammo, faster fire" % face.title)
			DiceFaceDef.Kind.LUCKY:
				_check(_player.health == _player.class_def.max_health and _player.status.get_speed_mult() > 1.0, "%s: full health, faster" % face.title)
			DiceFaceDef.Kind.REVEAL:
				var body := fake.rig.get_node("Body/Skeleton3D/Body") as GeometryInstance3D
				_check(body.material_overlay != null, "%s: the Gambler sees the others through walls" % face.title)
			DiceFaceDef.Kind.HEALTH:
				_check(_player.health == face.set_health, "%s: health drops to %d" % [face.title, face.set_health])
	_player.status.reset_host()
	_player.status.reset_local()
	_player.health = _player.class_def.max_health


## Cowboy's Smoke Break: health comes back over time (host) and reloads run faster (owner).
func _test_smoke_break() -> void:
	await _set_loadout(_code_for(&"cowboy"))
	var ability: Ability = _player.ability
	_check(ability != null and ability.def.heal_per_second > 0.0, "Cowboy has Smoke Break")
	if ability == null:
		return
	_player.health = 40
	ability.host_ready_at = -INF
	ability.cooldown_left = 0.0
	var origin: Vector3 = _player.get_aim_origin()
	var dir: Vector3 = -_player.get_aim_basis().z
	ability.try_use(origin, dir)
	ability.server_try_use(origin, dir)
	await _frames(Engine.physics_ticks_per_second) # One second.
	var healed: int = _player.health - 40
	_check(healed >= 4 and healed <= 6, "Smoke Break heals ~%d HP per second (healed %d)" % [roundi(ability.def.heal_per_second), healed])
	_check(_player.status.get_reload_speed_mult() > 1.0, "Smoke Break speeds up reloads on the owner")
	_player.status.reset_host()
	_player.status.reset_local()
	_check(_player.status.get_reload_speed_mult() == 1.0, "reload boost ends with the buff")
	_player.health = _player.class_def.max_health


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


## Hawk's rifles: no crosshair from the hip, a wide cone until the scope is fully up, zoom
## easing in over scope_in_time; any gun gets the slide cone while sliding.
func _test_scope_and_spread() -> void:
	await _set_loadout(_code_for(&"hawk"))
	_player.equip(0)
	await _frames(2)
	var rifle := _player.current_weapon as HitscanWeapon
	var def: WeaponDef = rifle.def
	_check(not def.hip_crosshair and def.scope_in_time > 0.0, "%s: no hip crosshair, zoom takes time" % def.display_name)
	_check(is_equal_approx(rifle.get_spread_cone(), def.unscoped_spread), "%s from the hip: %.1f degree cone" % [def.display_name, rifle.get_spread_cone()])
	_player.is_scoped = true # Read synchronously: the player's next tick sets it back from input.
	_player.scope_blend = 0.0
	var mid_zoom_cone: float = rifle.get_spread_cone()
	var start_zoom: float = _player.get_zoom()
	_player.scope_blend = 1.0
	_check(is_equal_approx(mid_zoom_cone, def.unscoped_spread) and is_zero_approx(rifle.get_spread_cone()),
		"scope just raised is still wide, fully up is exact")
	_check(is_equal_approx(start_zoom, 1.0) and is_equal_approx(_player.get_zoom(), def.scope_zoom), "zoom eases from 1x to %.1fx" % def.scope_zoom)
	_player.is_scoped = false
	_player.scope_blend = 0.0
	_player.movement.is_sliding = true
	var slide_cone: float = rifle.get_spread_cone() - def.unscoped_spread
	_player.movement.is_sliding = false
	_check(is_equal_approx(slide_cone, _player.class_def.movement.slide_spread) and slide_cone > 0.0,
		"sliding adds a %.1f degree cone" % slide_cone)

	# Bolt action: a shot drops the scope (right mouse has to be released and pressed again).
	_check(def.unscope_on_fire, "%s drops the scope after every shot" % def.display_name)
	_player.is_scoped = true
	_player.scope_blend = 1.0
	_player.drop_scope()
	_check(not _player.is_scoped and is_zero_approx(_player.scope_blend), "drop_scope closes the scope")

	# Hit marker: a predicted plain hit shows once, an upgrade (headshot, kill) shows again.
	var markers: Array[int] = [0]
	var count_marker: Callable = func(_zone: Hitbox.Zone, _killed: bool, _amount: float) -> void:
		markers[0] += 1
	Events.hit_confirmed.connect(count_marker)
	HitFeedback.predict(Hitbox.Zone.BODY)
	HitFeedback.on_confirmed(_player, Hitbox.Zone.BODY, false, 20.0)
	_check(markers[0] == 1, "a predicted body hit shows its marker once")
	HitFeedback.predict(Hitbox.Zone.BODY)
	HitFeedback.on_confirmed(_player, Hitbox.Zone.HEAD, false, 40.0)
	_check(markers[0] == 3, "a body hit the host confirms as a headshot shows the upgrade")
	HitFeedback.on_confirmed(_player, Hitbox.Zone.BODY, true, 20.0)
	_check(markers[0] == 4, "a hit nobody predicted shows on confirmation")
	Events.hit_confirmed.disconnect(count_marker)


## Knife out (slot 3): faster than with a gun in hand (WeaponDef.move_speed_mult).
func _test_knife_speed() -> void:
	await _set_loadout(_code_for(&"wolf"))
	_player.equip(0)
	await _frames(2)
	var gun_speed: float = _player.movement.base_speed
	_player.equip(Player.KNIFE_SLOT)
	await _frames(2)
	var knife_speed: float = _player.movement.base_speed
	_player.equip(0)
	_check(knife_speed > gun_speed, "knife out runs faster (%.2f vs %.2f m/s)" % [knife_speed, gun_speed])


## Held knife (slot 3): normal damage from the front, backstab_damage from behind (CS rule);
## the V quick swing never backstabs.
func _test_backstab() -> void:
	await _set_loadout(_code_for(&"wolf"))
	var knife: WeaponDef = _player.weapons[Player.KNIFE_SLOT].def
	_check(knife.backstab_damage > 0.0, "knife has a backstab")
	var front: float = await _knife_hit_from(_away)
	_check(is_equal_approx(front, knife.damage), "knife from the front deals %.0f (damage %.0f)" % [front, knife.damage])
	var behind: float = await _knife_hit_from(-_away)
	_check(is_equal_approx(behind, knife.backstab_damage), "knife from behind deals %.0f (backstab)" % behind)
	var side: Vector3 = _away.cross(Vector3.UP).normalized()
	var flank: float = await _knife_hit_from(side)
	_check(is_equal_approx(flank, knife.damage), "knife from the side deals %.0f (no backstab)" % flank)
	var heavy_front: float = await _knife_hit_from(_away, true)
	_check(is_equal_approx(heavy_front, knife.heavy_damage), "right click stab from the front deals %.0f" % heavy_front)
	var heavy_behind: float = await _knife_hit_from(-_away, true)
	_check(is_equal_approx(heavy_behind, knife.heavy_backstab_damage), "right click stab from behind deals %.0f (kill)" % heavy_behind)
	_player.global_position = _dummy.global_position - _away * MELEE_DISTANCE + Vector3.UP * 0.05
	await _frames(2)
	_dummy.health = DUMMY_HEALTH
	_player.requests._next_melee_time = -INF
	var origin: Vector3 = _player.get_aim_origin()
	_player.requests._request_melee(origin, (_dummy_target() - origin).normalized())
	await _frames(1)
	_check(is_equal_approx(DUMMY_HEALTH - _dummy.health, knife.damage), "V quick swing from behind is no backstab")
	# Players face where they look: the flat look direction is the backstab facing.
	_player.rotation.y = 0.7
	var look: Vector3 = _player.get_look_forward()
	look.y = 0.0
	_check(_player.get_facing().dot(look.normalized()) > 0.999, "player facing follows the yaw")


## A long spray (CS style) climbs, then sways: it stays under recoil_max_up and does not drift
## sideways for good, for every automatic gun.
func _test_spray() -> void:
	for class_def: ClassDef in Loadout.roster().classes:
		for gun_def: WeaponDef in class_def.primary_weapons:
			if not gun_def.automatic or gun_def.recoil_pattern.is_empty():
				continue
			var gun: Weapon = (gun_def.scene.instantiate() as Weapon)
			gun.def = gun_def
			var offset := Vector2.ZERO
			var widest: float = 0.0
			for shot: int in 300:
				offset += gun_def.recoil_pattern[gun.recoil_index(shot)]
				offset.y = minf(offset.y, gun_def.recoil_max_up)
				widest = maxf(widest, absf(offset.x))
			gun.free()
			_check(offset.y <= gun_def.recoil_max_up and widest < 4.0,
				"%s: 300-shot spray stays bounded (up %.1f, widest %.1f)" % [gun_def.display_name, offset.y, widest])


## Held knife swing (or right click stab) from `direction` (flat, from the dummy) at melee
## range; returns the damage.
func _knife_hit_from(direction: Vector3, heavy: bool = false) -> float:
	_player.global_position = _dummy.global_position + direction * MELEE_DISTANCE + Vector3.UP * 0.05
	_player.velocity = Vector3.ZERO
	await _frames(2)
	_dummy.health = DUMMY_HEALTH
	_player.requests.reset_fire_budgets()
	var origin: Vector3 = _player.get_aim_origin()
	var dir: Vector3 = (_dummy_target() - origin).normalized()
	if heavy:
		_player.requests._request_stab(origin, dir, Player.KNIFE_SLOT, &"knife")
	else:
		_player.requests._request_fire(origin, dir, Player.KNIFE_SLOT, &"knife")
	await _frames(1)
	return DUMMY_HEALTH - _dummy.health


## Inside the swap window: hurt players never refill by swapping, and a swap ends a boost.
func _test_swap_rules() -> void:
	var cheetah: PackedInt32Array = _code_for(&"cheetah")
	await _set_loadout(cheetah)
	_player._spawned_at = Time.get_ticks_usec() / 1_000_000.0
	_player._hurt_since_spawn = false
	_player.is_protected = false
	_player.health = _player.class_def.max_health
	_player.ability.host_ready_at = -INF
	_player.ability.server_try_use(_player.get_aim_origin(), Vector3.FORWARD)
	_player.server_choose_loadout(_code_for(&"volcano"))
	await _frames(1)
	_check(is_equal_approx(_player.status.get_host_speed_mult(), 1.0), "loadout swap ends the Adrenaline boost")
	_player.server_choose_loadout(cheetah)
	await _frames(1)
	_check(_player.health == _player.class_def.max_health, "unhurt swap gives full health (%d)" % _player.health)
	_player.take_hit(55.0, Hitbox.Zone.BODY, 0, "Test")
	_player.server_choose_loadout(_code_for(&"volcano"))
	_player.server_choose_loadout(cheetah)
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
	_check(_player.special_weapon >= 0 and _player.weapons.size() == 4, "holding E opens the crate and gives an airdrop weapon")
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
	_check(_player.special_weapon == -1 and _player.weapons.size() == 3, "empty airdrop weapon disappears")

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

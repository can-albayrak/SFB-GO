class_name Player
extends CharacterBody3D
## Player root: owns state and wires the components together.
## Multiplayer authority = owning peer: input, movement and weapon handling run there only.
## health / is_alive belong to the host and are replicated by StateSync (authority 1).
## Movement state: owner -> host (30 Hz) -> other peers, drawn ~100 ms in the past.

signal health_changed(health: int, max_health: int)
signal weapon_changed(weapon: Weapon)
signal alive_changed(is_alive: bool)
signal protection_changed(is_protected: bool)
signal loadout_changed
## Host only. Game registers the kill and schedules the respawn.
signal died(killer_id: int, weapon_name: String, headshot: bool, is_melee: bool)

const MAX_PITCH: float = deg_to_rad(89.0)
const FALL_DEATH_Y: float = -30.0
const STATE_SEND_TICKS: int = 2 ## Physics ticks between state packets (60 Hz / 2 = 30 Hz).
const INTERP_DELAY: float = 0.1 ## Remote players are drawn this far in the past.
const INTERP_SNAP: float = 0.25 ## Re-sync the render clock if it drifts further than this.
const INTERP_CATCHUP: float = 2.0
const MAX_SNAPSHOTS: int = 30
const FIRE_RATE_TOLERANCE: float = 0.95 ## Sustained host-side rate limit: fire_interval * this.
const FIRE_BURST_SLACK: float = 0.25 ## Seconds of shots that may arrive bunched up (jitter, resends).
const MAX_FIRE_ORIGIN_ERROR: float = 3.0 ## Metres between claimed and known eye position.
const MOVE_SPEED_TOLERANCE: float = 1.5 ## Host allows horizontal speed up to bhop cap * this.
const MOVE_BUDGET_SECONDS: float = 1.0 ## Movement budget window, absorbs packet bunching.
const PROTECTION_BLINK_PERIOD: float = 0.25
const FALL_WEAPON_NAME: String = "Fall"

# Hitbox poses: x = centre height above feet, y = box height (0 = keep shape).
const HEAD_POSE_STAND: Vector2 = Vector2(1.62, 0.0)
const HEAD_POSE_CROUCH: Vector2 = Vector2(0.98, 0.0)
const BODY_POSE_STAND: Vector2 = Vector2(1.1, 0.75)
const BODY_POSE_CROUCH: Vector2 = Vector2(0.62, 0.45)
const LEG_POSE_STAND: Vector2 = Vector2(0.37, 0.74)
const LEG_POSE_CROUCH: Vector2 = Vector2(0.2, 0.4)


class Snapshot:
	var time: float
	var position: Vector3
	var yaw: float
	var pitch: float
	var crouched: bool


## Replicated by StateSync (host-owned). Changing it rebuilds class, weapons, knife and ability.
var loadout: PackedInt32Array = Loadout.default_code(): set = _set_loadout
var class_def: ClassDef
var health: int = 0: set = _set_health
var is_alive: bool = true: set = _set_alive
## Spawn protection (host-owned, replicated): no damage taken; firing ends it.
var is_protected: bool = false: set = _set_protected
## Vertical look angle in radians. Yaw is the body's own rotation.y.
var look_pitch: float = 0.0
var weapons: Array[Weapon] = []
var current_weapon: Weapon = null
var melee_weapon: MeleeWeapon = null
var ability: Ability = null
var is_local: bool = false
## Owner: the loadout last sent to the host (drives "Next spawn" on the HUD).
var requested_loadout: PackedInt32Array = PackedInt32Array()

## Increments on every respawn; stale state packets from a previous life are dropped.
var _life: int = 0
var _pose_crouched: bool = false
var _send_tick: int = 0
var _fall_reported: bool = false
var _snapshots: Array[Snapshot] = []
var _render_time: float = 0.0
var _has_render_time: bool = false
# Host-side validation state.
var _next_fire_time: float = -INF
var _move_budget: float = 0.0
var _last_valid_position: Vector3 = Vector3.ZERO
var _last_state_host_time: float = 0.0
var _has_valid_position: bool = false
var _protected_until: float = 0.0
var _last_hit_weapon: String = ""
var _last_hit_melee: bool = false
var _last_hit_zone: Hitbox.Zone = Hitbox.Zone.BODY
var _next_melee_time: float = -INF
var _pending_loadout: PackedInt32Array = PackedInt32Array()
var _spawned_at: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var head_hitbox: Hitbox = $Hitboxes/HeadHitbox
@onready var body_hitbox: Hitbox = $Hitboxes/BodyHitbox
@onready var leg_hitbox: Hitbox = $Hitboxes/LegHitbox
@onready var model: Node3D = $Model
@onready var crown: Node3D = $Model/Crown
@onready var remote_muzzle: Marker3D = $Model/Rifle/Muzzle
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var movement: Movement = $Movement
@onready var player_input: PlayerInput = $PlayerInput


## Called by the spawner before the node enters the tree, on every peer.
func setup_authority(peer_id: int) -> void:
	set_multiplayer_authority(peer_id)
	$StateSync.set_multiplayer_authority(1)


func _ready() -> void:
	is_local = is_multiplayer_authority()
	crown.visible = false
	_apply_loadout()
	if multiplayer.is_server():
		health = class_def.max_health # Clients already got the real value from StateSync's spawn state.
		_spawned_at = _now()
		_grant_protection()

	if is_local:
		# Camera is top-level and placed every frame, so mouse look never waits for a physics tick.
		camera.top_level = true
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.fov = Settings.get_vertical_fov()
		camera.current = true
		Events.local_player_spawned.emit(self)
	else:
		# Remote players are placed in _process from snapshots.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply_alive_state()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and is_protected and _now() >= _protected_until:
		is_protected = false
	if not is_local or not is_alive:
		return
	var cmd: PlayerCommand = player_input.gather()
	if cmd.weapon_slot >= 0:
		equip(cmd.weapon_slot)

	movement.base_speed = class_def.move_speed * current_weapon.def.move_speed_mult
	movement.physics_step(delta, cmd)

	if melee_weapon != null:
		melee_weapon.tick_melee(delta)
		if cmd.melee and not current_weapon.is_busy() and melee_weapon.swing():
			_request_melee.rpc_id(1, get_aim_origin(), -get_aim_basis().z)
	var swinging: bool = melee_weapon != null and melee_weapon.is_swinging()
	current_weapon.visible = not swinging
	# While the knife is out the gun keeps its timers but cannot fire.
	current_weapon.tick(delta, PlayerCommand.new() if swinging else cmd)

	if ability != null:
		ability.tick(delta)
		if cmd.ability and ability.try_use(get_aim_origin(), -get_aim_basis().z):
			_request_ability.rpc_id(1, get_aim_origin(), -get_aim_basis().z)
	_apply_pose(movement.is_crouched)

	_send_tick += 1
	if _send_tick >= STATE_SEND_TICKS:
		_send_tick = 0
		_send_state()

	if global_position.y < FALL_DEATH_Y and not _fall_reported:
		_fall_reported = true
		_request_fall_death.rpc_id(1)


func _process(delta: float) -> void:
	if is_local:
		var eye: Vector3 = head.get_global_transform_interpolated().origin
		camera.global_transform = Transform3D(_look_basis(current_weapon.get_view_recoil()), eye)
	else:
		_interpolate_remote(delta)
		if is_alive and is_protected:
			model.visible = fmod(Time.get_ticks_msec() / 1000.0, PROTECTION_BLINK_PERIOD) < PROTECTION_BLINK_PERIOD * 0.6


func equip(slot: int) -> void:
	if slot < 0 or slot >= weapons.size() or weapons[slot] == current_weapon:
		return
	if current_weapon != null:
		current_weapon.holster()
	current_weapon = weapons[slot]
	current_weapon.draw()
	weapon_changed.emit(current_weapon)


## Eye position at the current physics tick (not interpolated). Shots start here.
func get_aim_origin() -> Vector3:
	return head.global_position


## Look direction including weapon recoil.
func get_aim_basis() -> Basis:
	return _look_basis(current_weapon.recoil_offset)


## Own body and hitboxes, so our rays never hit ourselves.
func get_hit_exclusions() -> Array[RID]:
	return [get_rid(), head_hitbox.get_rid(), body_hitbox.get_rid(), leg_hitbox.get_rid()]


## Owning client: asks the host to resolve a shot.
func send_fire(origin: Vector3, dir: Vector3, slot: int) -> void:
	_request_fire.rpc_id(1, origin, dir, slot, weapons[slot].def.id)


## Host only: false while spawn-protected, dead or between matches (no hit marker then).
func can_take_damage() -> bool:
	return is_alive and not is_protected and Match.state == Match.State.PLAYING


## Host only. Returns true if this hit killed.
func take_hit(amount: float, zone: Hitbox.Zone, attacker_id: int, weapon_name: String, is_melee: bool = false) -> bool:
	assert(multiplayer.is_server(), "take_hit is host-only")
	if not can_take_damage():
		return false
	_last_hit_weapon = weapon_name
	_last_hit_melee = is_melee
	_last_hit_zone = zone
	health = maxi(health - roundi(amount), 0)
	if health > 0:
		return false
	_die(attacker_id)
	return true


## Host only. Restores health and moves the player on every peer.
func server_respawn(spawn_position: Vector3, yaw: float) -> void:
	assert(multiplayer.is_server(), "server_respawn is host-only")
	_life += 1
	_has_valid_position = false
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		compensator.forget(self) # No rewinding into the previous life.
	if not _pending_loadout.is_empty():
		loadout = _pending_loadout
		_pending_loadout = PackedInt32Array()
	_spawned_at = _now()
	health = class_def.max_health
	is_alive = true
	_grant_protection()
	Net.broadcast(self, &"_respawn_at", [spawn_position, yaw, _life])


## Host: respawn counter, used to discard stale respawn timers.
func get_life() -> int:
	return _life


func is_pose_crouched() -> bool:
	return _pose_crouched


## Host lag compensation: moves the body and hitboxes and pushes the hitbox
## transforms to the physics server at once (transform notifications are deferred).
func set_hit_pose(pos: Vector3, yaw: float, crouched: bool) -> void:
	global_position = pos
	rotation.y = yaw
	_apply_pose(crouched)
	for hitbox: Hitbox in [head_hitbox, body_hitbox, leg_hitbox]:
		PhysicsServer3D.area_set_transform(hitbox.get_rid(), hitbox.global_transform)


## Every peer: crown over the current leader (never drawn on yourself).
func set_leader(is_leader: bool) -> void:
	crown.visible = is_leader


func _grant_protection() -> void:
	_protected_until = _now() + Match.rules.spawn_protection
	is_protected = true


func _die(killer_id: int) -> void:
	is_alive = false
	is_protected = false
	var killer_health: int = 0
	var killer := get_parent().get_node_or_null(str(killer_id)) as Player
	if killer != null:
		killer_health = killer.health
	var headshot: bool = _last_hit_zone == Hitbox.Zone.HEAD and killer_id != get_multiplayer_authority()
	Net.broadcast(self, &"_announce_death", [killer_id, _last_hit_weapon, killer_health])
	died.emit(killer_id, _last_hit_weapon, headshot, _last_hit_melee)


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _look_basis(recoil: Vector2) -> Basis:
	var pitch: float = clampf(look_pitch + deg_to_rad(recoil.y), -MAX_PITCH, MAX_PITCH)
	return Basis.from_euler(Vector3(pitch, rotation.y - deg_to_rad(recoil.x), 0.0))


## Owner: choose a loadout. The host applies it now (first seconds after spawning)
## or at the next spawn (GDD). Also remembered for the next session.
func request_loadout(code: PackedInt32Array) -> void:
	if not Loadout.is_valid(code):
		return
	requested_loadout = code
	Loadout.save_to_settings(code)
	_request_loadout.rpc_id(1, code)


## View direction without recoil (host uses it for flashbangs).
func get_look_forward() -> Vector3:
	return -_look_basis(Vector2.ZERO).z


## Rebuilds class stats, weapons, knife and ability from `loadout`. Every peer runs this,
## so the host (damage), the owner (handling) and viewers agree.
func _apply_loadout() -> void:
	class_def = Loadout.get_class_def(loadout)
	movement.def = class_def.movement

	for weapon: Weapon in weapons:
		weapon_holder.remove_child(weapon)
		weapon.queue_free()
	weapons.clear()
	current_weapon = null
	for def: WeaponDef in [Loadout.get_primary(loadout), class_def.secondary_weapon]:
		weapons.append(_add_weapon(def))

	if melee_weapon != null:
		melee_weapon.queue_free()
		melee_weapon = null
	if class_def.quick_melee != null:
		melee_weapon = _add_weapon(class_def.quick_melee) as MeleeWeapon

	# The cooldown belongs to the player, not the ability: swapping must not reset it.
	var carried_cooldown: float = 0.0
	var carried_host_ready: float = -INF
	if ability != null:
		carried_cooldown = ability.cooldown_left
		carried_host_ready = ability.host_ready_at
		ability.queue_free()
		ability = null
	var ability_def: AbilityDef = Loadout.get_ability(loadout)
	if ability_def != null:
		ability = ability_def.scene.instantiate()
		ability.setup(ability_def, self)
		ability.cooldown_left = carried_cooldown
		ability.host_ready_at = carried_host_ready
		add_child(ability)

	equip(0)
	loadout_changed.emit()


func _add_weapon(def: WeaponDef) -> Weapon:
	var weapon: Weapon = def.scene.instantiate()
	weapon.setup(def, self)
	weapon.visible = false
	weapon_holder.add_child(weapon)
	return weapon


func _set_loadout(value: PackedInt32Array) -> void:
	if not Loadout.is_valid(value) or value == loadout and class_def != null:
		return
	loadout = value
	if is_node_ready():
		_apply_loadout()


func _apply_pose(crouched: bool) -> void:
	if crouched == _pose_crouched:
		return
	_pose_crouched = crouched
	head_hitbox.set_pose(HEAD_POSE_CROUCH if crouched else HEAD_POSE_STAND)
	body_hitbox.set_pose(BODY_POSE_CROUCH if crouched else BODY_POSE_STAND)
	leg_hitbox.set_pose(LEG_POSE_CROUCH if crouched else LEG_POSE_STAND)
	model.scale.y = Movement.CROUCH_HEIGHT / Movement.STAND_HEIGHT if crouched else 1.0
	if not is_local:
		movement.set_crouch_shape(crouched)
		head.position.y = Movement.CROUCH_EYE if crouched else Movement.STAND_EYE


func _apply_alive_state() -> void:
	collision.set_deferred(&"disabled", not is_alive)
	for hitbox: Hitbox in [head_hitbox, body_hitbox, leg_hitbox]:
		hitbox.set_enabled(is_alive)
	model.visible = is_alive and not is_local
	weapon_holder.visible = is_alive and is_local


func _set_health(value: int) -> void:
	health = value
	# StateSync can deliver health before _ready has built the class.
	health_changed.emit(health, class_def.max_health if class_def != null else health)


func _set_alive(value: bool) -> void:
	is_alive = value
	if is_node_ready():
		_apply_alive_state()
	alive_changed.emit(value)


func _set_protected(value: bool) -> void:
	is_protected = value
	if is_node_ready() and not value:
		_apply_alive_state() # Stop blinking with the model shown.
	protection_changed.emit(value)


func _sender_id() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


func _sender_is_host() -> bool:
	return _sender_id() == 1


# --- Movement state sync ---------------------------------------------------

func _send_state() -> void:
	var time: float = Time.get_ticks_usec() / 1_000_000.0
	if multiplayer.is_server():
		_relay_state(time, global_position, rotation.y, look_pitch, _pose_crouched, _life)
	else:
		_submit_state.rpc_id(1, time, global_position, rotation.y, look_pitch, _pose_crouched, _life)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_state(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not _is_plausible_move(pos, life):
		return
	_store_snapshot(time, pos, yaw, pitch, crouched, life)
	_relay_state(time, pos, yaw, pitch, crouched, life)


## Host: token-bucket speed check on the host clock. Teleports are dropped, so a
## cheating client freezes in place for everyone and its shots fail the origin check.
func _is_plausible_move(pos: Vector3, life: int) -> bool:
	var now: float = Time.get_ticks_usec() / 1_000_000.0
	var max_speed: float = class_def.move_speed * class_def.movement.bhop_cap_mult * MOVE_SPEED_TOLERANCE
	if life < _life:
		return false
	if not _has_valid_position:
		# First packet since spawn/respawn: the host placed this player itself.
		_has_valid_position = true
		_last_valid_position = pos
		_last_state_host_time = now
		_move_budget = max_speed * MOVE_BUDGET_SECONDS
		return true
	_move_budget = minf(_move_budget + (now - _last_state_host_time) * max_speed, max_speed * MOVE_BUDGET_SECONDS)
	_last_state_host_time = now
	var moved: float = Vector2(pos.x - _last_valid_position.x, pos.z - _last_valid_position.z).length()
	if moved > _move_budget:
		return false
	_move_budget -= moved
	_last_valid_position = pos
	return true


func _relay_state(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	for peer_id: int in Net.state_peers:
		if peer_id != 1 and peer_id != get_multiplayer_authority():
			_receive_state.rpc_id(peer_id, time, pos, yaw, pitch, crouched, life)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_state(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	if not _sender_is_host():
		return
	_store_snapshot(time, pos, yaw, pitch, crouched, life)


func _store_snapshot(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	if life < _life:
		return
	if life > _life:
		_life = life
		_snapshots.clear()
		_has_render_time = false
	if not _snapshots.is_empty() and time <= _snapshots.back().time:
		return
	var snapshot := Snapshot.new()
	snapshot.time = time
	snapshot.position = pos
	snapshot.yaw = yaw
	snapshot.pitch = pitch
	snapshot.crouched = crouched
	_snapshots.append(snapshot)
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()


func _interpolate_remote(delta: float) -> void:
	if _snapshots.is_empty():
		return
	var target: float = _snapshots.back().time - INTERP_DELAY
	if not _has_render_time or absf(target - _render_time) > INTERP_SNAP:
		_render_time = target
		_has_render_time = true
	else:
		_render_time = lerpf(_render_time + delta, target, minf(INTERP_CATCHUP * delta, 1.0))

	while _snapshots.size() > 2 and _snapshots[1].time <= _render_time:
		_snapshots.pop_front()
	var a: Snapshot = _snapshots[0]
	var b: Snapshot = _snapshots[1] if _snapshots.size() > 1 else a
	var weight: float = 0.0
	if b.time > a.time:
		weight = clampf((_render_time - a.time) / (b.time - a.time), 0.0, 1.0)

	global_position = a.position.lerp(b.position, weight)
	rotation.y = lerp_angle(a.yaw, b.yaw, weight)
	look_pitch = lerpf(a.pitch, b.pitch, weight)
	_apply_pose(b.crouched if weight >= 0.5 else a.crouched)


# --- Host-authoritative events ---------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _request_fire(origin: Vector3, dir: Vector3, slot: int, weapon_id: StringName) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not is_alive or slot < 0 or slot >= weapons.size():
		return
	var weapon: Weapon = weapons[slot]
	if weapon.def.id != weapon_id:
		return # Fired with the previous loadout's weapon, still in flight after a swap.
	var now: float = Time.get_ticks_msec() / 1000.0
	# Budget, not gap between arrivals: bunched packets pass, sustained over-rate does not.
	if now < _next_fire_time - FIRE_BURST_SLACK:
		return
	if origin.distance_to(head.global_position) > MAX_FIRE_ORIGIN_ERROR:
		return
	_next_fire_time = maxf(_next_fire_time, now - FIRE_BURST_SLACK) + weapon.def.get_average_shot_interval() * FIRE_RATE_TOLERANCE
	if Match.state == Match.State.PLAYING:
		is_protected = false # GDD: firing ends spawn protection.
	var end_point: Vector3
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		end_point = compensator.fire_rewound(self, weapon, origin, dir.normalized())
	else:
		end_point = weapon.server_fire(origin, dir.normalized())
	Net.broadcast(self, &"_show_shot", [origin, end_point])


@rpc("any_peer", "call_local", "reliable")
func _request_melee(origin: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not is_alive or melee_weapon == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _next_melee_time - FIRE_BURST_SLACK:
		return
	if origin.distance_to(head.global_position) > MAX_FIRE_ORIGIN_ERROR:
		return
	_next_melee_time = maxf(_next_melee_time, now - FIRE_BURST_SLACK) + melee_weapon.def.fire_interval * FIRE_RATE_TOLERANCE
	if Match.state == Match.State.PLAYING:
		is_protected = false
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		compensator.fire_rewound(self, melee_weapon, origin, dir.normalized())
	else:
		melee_weapon.server_fire(origin, dir.normalized())


@rpc("any_peer", "call_local", "reliable")
func _request_ability(origin: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not is_alive or ability == null or Match.state != Match.State.PLAYING:
		return
	if origin.distance_to(head.global_position) > MAX_FIRE_ORIGIN_ERROR:
		return
	if ability.server_try_use(origin, dir.normalized()) and Match.state == Match.State.PLAYING:
		is_protected = false


@rpc("any_peer", "call_local", "reliable")
func _request_loadout(code: PackedInt32Array) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not Loadout.is_valid(code):
		return
	# GDD: choosing within the first seconds after spawning switches at once.
	var in_window: bool = _now() - _spawned_at <= Match.rules.loadout_swap_window
	if is_alive and in_window and Match.state == Match.State.PLAYING:
		# Only an unhurt player gets the new class's full health (no heal-by-swapping).
		var was_full: bool = health >= class_def.max_health
		_pending_loadout = PackedInt32Array()
		loadout = code
		health = class_def.max_health if was_full else mini(health, class_def.max_health)
	else:
		_pending_loadout = code


## Host -> victim: blind for `seconds` (flashbang).
@rpc("any_peer", "call_local", "reliable")
func flash(seconds: float) -> void:
	if not _sender_is_host() or not is_local:
		return
	Events.local_flashed.emit(seconds)


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(_from: Vector3, to: Vector3) -> void:
	if not _sender_is_host() or is_local:
		return
	ShotEffects.spawn_muzzle_flash(remote_muzzle)
	ShotEffects.spawn_tracer(get_parent(), remote_muzzle.global_position, to)


@rpc("any_peer", "call_local", "reliable")
func confirm_hit(zone: Hitbox.Zone, killed: bool) -> void:
	if not _sender_is_host():
		return
	Events.hit_confirmed.emit(zone, killed)


@rpc("any_peer", "call_local", "reliable")
func _request_fall_death() -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority() or not is_alive:
		return
	if Match.state != Match.State.PLAYING:
		return # Between matches: the restart respawns everyone anyway.
	_last_hit_weapon = FALL_WEAPON_NAME
	_last_hit_melee = false
	_last_hit_zone = Hitbox.Zone.BODY
	health = 0
	_die(get_multiplayer_authority())


@rpc("any_peer", "call_local", "reliable")
func _announce_death(killer_id: int, weapon_name: String, killer_health: int) -> void:
	if not _sender_is_host():
		return
	Events.player_died.emit(self, killer_id, weapon_name, killer_health)


@rpc("any_peer", "call_local", "reliable")
func _respawn_at(spawn_position: Vector3, yaw: float, life: int) -> void:
	if not _sender_is_host():
		return
	_life = maxi(_life, life)
	global_position = spawn_position
	rotation.y = yaw
	_snapshots.clear()
	_has_render_time = false
	if is_local:
		velocity = Vector3.ZERO
		look_pitch = 0.0
		movement.reset()
		_fall_reported = false
		for weapon: Weapon in weapons:
			weapon.refill()
	_apply_pose(false)
	reset_physics_interpolation()

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
const SCOPE_FOV_LERP: float = 25.0 ## Per second; how fast the zoom eases in and out.
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
const SHIELD_BLOCK_COS: float = 0.26 ## Hits from within ~75 degrees of the facing are blocked.
const SHIELD_SIZE: Vector3 = Vector3(1.3, 1.7, 0.06)
const SHIELD_OFFSET: Vector3 = Vector3(0.0, 1.0, -0.8)
const SHIELD_COLOR: Color = Color(0.35, 0.8, 1.0, 0.4)
## Scope glint (GDD Hawk): shown to others while scoped, same screen size at any distance.
const GLINT_OFFSET: Vector3 = Vector3(0.15, 1.5, -0.45)
const GLINT_SIZE: float = 0.06
const GLINT_COLOR: Color = Color(1.0, 0.95, 0.8)

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
## Owner: right mouse held with a scoped weapon (zoom, slow, sway, no sprint).
var is_scoped: bool = false
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
var _shield_until: float = 0.0 ## Host clock.
var _stun_until: float = 0.0 ## Host clock.
var _stun_left: float = 0.0 ## Owner: input is ignored while > 0.
# Timed speed / fire rate boost (Adrenaline). The owner applies it to handling; the host
# keeps its own copy on its clock for the speed and fire rate checks.
var _buff_left: float = 0.0 ## Owner.
var _buff_speed_mult: float = 1.0
var _buff_fire_mult: float = 1.0
var _host_buff_until: float = 0.0 ## Host clock.
var _host_buff_speed_mult: float = 1.0
var _host_buff_fire_mult: float = 1.0
var _shield_visual: MeshInstance3D
## Owner only: FOV shift, head bob, landing dip, slide tilt, damage shake (visual only).
var _camera_feel: CameraFeel
var _glint: MeshInstance3D
var _sent_scoped: bool = false ## Owner: scope state last told to the host.
## Host: health removed by the last take_hit (0 when blocked by a shield or not allowed).
var last_damage_dealt: float = 0.0

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
		_camera_feel = CameraFeel.new()
		movement.landed.connect(_camera_feel.on_landed)
		Events.local_player_spawned.emit(self)
	else:
		# Remote players are placed in _process from snapshots.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build_shield_visual()
	_build_glint()
	_apply_alive_state()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if is_protected and _now() >= _protected_until:
			is_protected = false
		if _shield_until > 0.0 and _now() >= _shield_until:
			_clear_shield()
	if not is_local or not is_alive:
		is_scoped = false
		return
	var cmd: PlayerCommand = player_input.gather()
	if _stun_left > 0.0:
		_stun_left -= delta
		cmd = PlayerCommand.new() # Stunned: no moving, firing or abilities.
	if cmd.weapon_slot >= 0:
		equip(cmd.weapon_slot)

	is_scoped = cmd.secondary and current_weapon.def.scope_zoom > 0.0 		and not current_weapon.is_reloading and not movement.is_sliding
	weapon_holder.visible = not is_scoped
	if is_scoped:
		cmd.sprint = false
	if is_scoped != _sent_scoped:
		_sent_scoped = is_scoped
		_request_scope.rpc_id(1, is_scoped) # Others see the glint.
	_buff_left = maxf(_buff_left - delta, 0.0)
	var scope_mult: float = current_weapon.def.scope_move_mult if is_scoped else 1.0
	movement.base_speed = class_def.move_speed * current_weapon.def.move_speed_mult * get_speed_mult() * scope_mult
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
		_camera_feel.update(delta, movement, is_scoped)
		var eye: Vector3 = head.get_global_transform_interpolated().origin
		eye += Vector3.UP * _camera_feel.vertical + global_basis.x * _camera_feel.lateral
		var view: Basis = _look_basis(current_weapon.get_view_recoil() + _get_scope_sway() + _camera_feel.shake)
		camera.global_transform = Transform3D(view * Basis(Vector3.BACK, _camera_feel.roll), eye)
		camera.fov = lerpf(camera.fov, _get_target_fov(), minf(SCOPE_FOV_LERP * delta, 1.0))
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
	return _look_basis(current_weapon.recoil_offset + _get_scope_sway())


## Zoom factor of the active scope (1 when not scoped). Mouse sensitivity is divided by it.
func get_zoom() -> float:
	return current_weapon.def.scope_zoom if is_scoped and current_weapon != null else 1.0


## Degrees of scope sway (x = right, y = up); zero when not scoped.
func _get_scope_sway() -> Vector2:
	if not is_scoped:
		return Vector2.ZERO
	var t: float = Time.get_ticks_msec() / 1000.0
	var amplitude: float = current_weapon.def.scope_sway * (0.5 if movement.is_crouched else 1.0)
	return Vector2(sin(t * 1.1) + 0.5 * sin(t * 2.3), cos(t * 0.9) + 0.5 * cos(t * 1.9)) * amplitude


func _get_target_fov() -> float:
	if not is_scoped:
		return Settings.get_vertical_fov(_camera_feel.fov_extra if _camera_feel != null else 0.0)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(Settings.get_vertical_fov()) * 0.5) / get_zoom()))


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
	last_damage_dealt = 0.0
	if not can_take_damage():
		return false
	if _shield_blocks(attacker_id):
		return false
	_last_hit_weapon = weapon_name
	_last_hit_melee = is_melee
	_last_hit_zone = zone
	var before: int = health
	health = maxi(health - roundi(amount), 0)
	last_damage_dealt = before - health
	if health < before:
		_on_hurt.rpc_id(get_multiplayer_authority(), before - health)
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
	_clear_shield()
	_stun_until = 0.0
	_host_buff_until = 0.0
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
	_host_buff_until = 0.0
	_clear_shield()
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
	_buff_left = 0.0 # A boost belongs to the class that used it.
	_host_buff_until = 0.0
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
	if not is_alive and _glint != null:
		_glint.visible = false


func _set_health(value: int) -> void:
	health = value
	# StateSync can deliver health before _ready has built the class.
	health_changed.emit(health, class_def.max_health if class_def != null else health)


func _set_alive(value: bool) -> void:
	is_alive = value
	if not value:
		_buff_left = 0.0
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
	var max_speed: float = class_def.move_speed * _host_speed_mult() * class_def.movement.bhop_cap_mult * MOVE_SPEED_TOLERANCE
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
	if not is_alive or slot < 0 or slot >= weapons.size() or _now() < _stun_until:
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
	_next_fire_time = maxf(_next_fire_time, now - FIRE_BURST_SLACK) + weapon.def.get_average_shot_interval() * FIRE_RATE_TOLERANCE / _host_fire_rate_mult()
	if Match.state == Match.State.PLAYING:
		is_protected = false # GDD: firing ends spawn protection.
	var end_point: Vector3
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		end_point = compensator.fire_rewound(self, weapon, origin, dir.normalized())
	else:
		end_point = weapon.server_fire(origin, dir.normalized())
	if weapon is ShotgunWeapon:
		Net.broadcast(self, &"_on_pellets_fired", [(weapon as ShotgunWeapon).last_pellet_ends])
	elif weapon.def.fire_type == WeaponDef.FireType.HITSCAN:
		Net.broadcast(self, &"_show_shot", [origin, end_point])


@rpc("any_peer", "call_local", "reliable")
func _request_melee(origin: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not is_alive or melee_weapon == null or _now() < _stun_until:
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
	if not is_alive or ability == null or Match.state != Match.State.PLAYING or _now() < _stun_until:
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


## Host: kill reward. Health is host-owned; ammo lives on the owner, so the owner adds it.
func server_kill_reward(heal: int, ammo: int) -> void:
	assert(multiplayer.is_server(), "server_kill_reward is host-only")
	if not is_alive:
		return
	health = mini(health + heal, class_def.max_health)
	if ammo > 0:
		_receive_kill_ammo.rpc_id(get_multiplayer_authority(), ammo)


## Host: Shield ability. Frontal hits are blocked for `seconds`; everyone sees the panel.
func server_activate_shield(seconds: float) -> void:
	assert(multiplayer.is_server(), "server_activate_shield is host-only")
	_shield_until = _now() + seconds
	Net.broadcast(self, &"_set_shield", [true])


## Host: Charge hit. Blocks the victim's actions and tells its owner to freeze the input.
func server_stun(seconds: float) -> void:
	assert(multiplayer.is_server(), "server_stun is host-only")
	_stun_until = _now() + seconds
	_receive_stun.rpc_id(get_multiplayer_authority(), seconds)


## Host: pushes this player (kick). Movement belongs to the owner, so the owner applies it.
func server_knockback(impulse: Vector3) -> void:
	assert(multiplayer.is_server(), "server_knockback is host-only")
	_receive_knockback.rpc_id(get_multiplayer_authority(), impulse)


## Host: a thrown knife is back (picked up or timed out). Refills the owner's knife ammo.
func server_return_throwable() -> void:
	assert(multiplayer.is_server(), "server_return_throwable is host-only")
	_return_throwable.rpc_id(get_multiplayer_authority())


## Owner: timed speed / fire rate boost (Adrenaline), applied to movement and weapons.
func start_buff_local(seconds: float, speed_mult: float, fire_mult: float) -> void:
	_buff_left = seconds
	_buff_speed_mult = speed_mult
	_buff_fire_mult = fire_mult


## Host: the same boost on the host clock, so its speed and fire rate checks allow it.
func server_start_buff(seconds: float, speed_mult: float, fire_mult: float) -> void:
	assert(multiplayer.is_server(), "server_start_buff is host-only")
	_host_buff_until = _now() + seconds
	_host_buff_speed_mult = speed_mult
	_host_buff_fire_mult = fire_mult


## Owner: movement speed multiplier from an active boost.
func get_speed_mult() -> float:
	return _buff_speed_mult if _buff_left > 0.0 else 1.0


## Owner: fire rate multiplier from an active boost (weapons divide their intervals by it).
func get_fire_rate_mult() -> float:
	return _buff_fire_mult if _buff_left > 0.0 else 1.0


## Owner: seconds left on the boost (HUD).
func get_buff_left() -> float:
	return _buff_left


func _host_speed_mult() -> float:
	return _host_buff_speed_mult if _now() < _host_buff_until else 1.0


func _host_fire_rate_mult() -> float:
	return _host_buff_fire_mult if _now() < _host_buff_until else 1.0


## Host: is a hit from `attacker_id` stopped by the raised shield?
func _shield_blocks(attacker_id: int) -> bool:
	if _shield_until <= 0.0 or _now() >= _shield_until or attacker_id == get_multiplayer_authority():
		return false
	var attacker := get_parent().get_node_or_null(str(attacker_id)) as Player
	if attacker == null:
		return false
	var to_attacker: Vector3 = attacker.global_position - global_position
	to_attacker.y = 0.0
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	if to_attacker.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return true # Standing inside each other counts as in front.
	return forward.normalized().dot(to_attacker.normalized()) > SHIELD_BLOCK_COS


func _clear_shield() -> void:
	if _shield_until <= 0.0:
		return
	_shield_until = 0.0
	if multiplayer.is_server():
		Net.broadcast(self, &"_set_shield", [false])


## Bright dot on the remote body's scope; a fixed-size billboard, so it reads at any distance
## (walls still hide it).
func _build_glint() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(GLINT_SIZE, GLINT_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.fixed_size = true
	material.albedo_color = GLINT_COLOR
	material.albedo_texture = ShotEffects.get_glow_texture()
	quad.material = material
	_glint = MeshInstance3D.new()
	_glint.name = "Glint"
	_glint.mesh = quad
	_glint.position = GLINT_OFFSET
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.visible = false
	model.add_child(_glint) # Hidden with the body (dead, own view).


func _build_shield_visual() -> void:
	_shield_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SHIELD_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = SHIELD_COLOR
	box.material = material
	_shield_visual.mesh = box
	_shield_visual.position = SHIELD_OFFSET
	_shield_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_visual.visible = false
	add_child(_shield_visual)


@rpc("any_peer", "call_local", "reliable")
func _set_shield(active: bool) -> void:
	if not _sender_is_host():
		return
	_shield_visual.visible = active and not is_local # The owner looks through their own shield.


## Owner -> host: scoped in or out. The host tells everyone (scope glint).
@rpc("any_peer", "call_local", "reliable")
func _request_scope(scoped: bool) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	Net.broadcast(self, &"_on_scope_changed", [scoped and is_alive])


@rpc("any_peer", "call_local", "reliable")
func _on_scope_changed(scoped: bool) -> void:
	if not _sender_is_host():
		return
	_glint.visible = scoped and not is_local and is_alive


@rpc("any_peer", "call_local", "reliable")
func _receive_stun(seconds: float) -> void:
	if not _sender_is_host() or not is_local:
		return
	_stun_left = seconds
	Events.local_stunned.emit(seconds)


## Host -> victim's owner: damage taken. Drives the camera shake (visual only, aim unchanged).
@rpc("any_peer", "call_local", "unreliable")
func _on_hurt(amount: int) -> void:
	if not _sender_is_host() or not is_local or _camera_feel == null:
		return
	_camera_feel.add_shake(amount)


@rpc("any_peer", "call_local", "reliable")
func _receive_knockback(impulse: Vector3) -> void:
	if not _sender_is_host() or not is_local or not is_alive:
		return
	velocity += impulse


## Host -> owner: kill reward rounds for the weapon in hand (a reload in progress fills it anyway).
@rpc("any_peer", "call_local", "reliable")
func _receive_kill_ammo(amount: int) -> void:
	if not _sender_is_host() or not is_local or not is_alive:
		return
	var weapon: Weapon = current_weapon
	if weapon.def.uses_ammo and weapon.def.kill_ammo_reward and not weapon.is_reloading:
		weapon.add_ammo(amount)


@rpc("any_peer", "call_local", "reliable")
func _return_throwable() -> void:
	if not _sender_is_host() or not is_local:
		return
	for weapon: Weapon in weapons:
		if weapon.def.fire_type == WeaponDef.FireType.THROWN:
			weapon.add_ammo(1)


## Host: everyone sees the rope of a Hawk grapple.
func show_grapple(point: Vector3, seconds: float) -> void:
	assert(multiplayer.is_server(), "show_grapple is host-only")
	Net.broadcast(self, &"_show_grapple", [point, seconds])


## Host: everyone sees a hologram of this player where they stand now.
func show_decoy(seconds: float) -> void:
	assert(multiplayer.is_server(), "show_decoy is host-only")
	Net.broadcast(self, &"_show_decoy", [global_position, rotation.y, seconds])


@rpc("any_peer", "call_local", "reliable")
func _show_grapple(point: Vector3, seconds: float) -> void:
	if not _sender_is_host():
		return
	get_parent().add_child(GrappleBeam.create(self, point, seconds))


@rpc("any_peer", "call_local", "reliable")
func _show_decoy(at: Vector3, yaw: float, seconds: float) -> void:
	if not _sender_is_host():
		return
	get_parent().add_child(Decoy.create(model, at, yaw, seconds)) # The copy keeps the crouch squash.


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(_from: Vector3, to: Vector3) -> void:
	if not _sender_is_host() or is_local:
		return
	ShotEffects.spawn_muzzle_flash(remote_muzzle)
	ShotEffects.spawn_tracer(get_parent(), remote_muzzle.global_position, to)


## Host -> everyone: a remote player's shotgun blast (one tracer per pellet).
@rpc("any_peer", "call_local", "unreliable")
func _on_pellets_fired(ends: PackedVector3Array) -> void:
	if not _sender_is_host() or is_local:
		return
	ShotEffects.spawn_muzzle_flash(remote_muzzle)
	for end_point: Vector3 in ends:
		ShotEffects.spawn_tracer(get_parent(), remote_muzzle.global_position, end_point)


## Host -> shooter only: a hit landed. Hit marker + damage number at `point` (shooter's screen only).
@rpc("any_peer", "call_local", "reliable")
func confirm_hit(zone: Hitbox.Zone, killed: bool, amount: float, point: Vector3) -> void:
	if not _sender_is_host():
		return
	Events.hit_confirmed.emit(zone, killed, amount)
	DamageNumber.spawn(get_parent(), point, amount, zone)


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
		_stun_left = 0.0
		_buff_left = 0.0
		for weapon: Weapon in weapons:
			weapon.refill()
	_apply_pose(false)
	reset_physics_interpolation()

class_name Player
extends CharacterBody3D
## Player root: owns state and wires the components together.
## Multiplayer authority = owning peer: input, movement and weapon handling run there only.
## health / is_alive belong to the host and are replicated by StateSync (authority 1).
## Movement state: owner -> host (30 Hz) -> other peers, drawn ~100 ms in the past.

signal health_changed(health: int, max_health: int)
signal weapon_changed(weapon: Weapon)
signal alive_changed(is_alive: bool)
## Host only. Game listens to schedule the respawn.
signal died(killer_id: int)

const MAX_PITCH: float = deg_to_rad(89.0)
const FALL_DEATH_Y: float = -30.0
const STATE_SEND_TICKS: int = 2 ## Physics ticks between state packets (60 Hz / 2 = 30 Hz).
const INTERP_DELAY: float = 0.1 ## Remote players are drawn this far in the past.
const INTERP_SNAP: float = 0.25 ## Re-sync the render clock if it drifts further than this.
const INTERP_CATCHUP: float = 2.0
const MAX_SNAPSHOTS: int = 30
const FIRE_RATE_TOLERANCE: float = 0.75 ## Host rejects shots faster than fire_interval * this.
const MAX_FIRE_ORIGIN_ERROR: float = 3.0 ## Metres between claimed and known eye position.
const REMOTE_TRACER_DROP: float = 0.2

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


@export var class_def: ClassDef

var health: int = 0: set = _set_health
var is_alive: bool = true: set = _set_alive
## Vertical look angle in radians. Yaw is the body's own rotation.y.
var look_pitch: float = 0.0
var weapons: Array[Weapon] = []
var current_weapon: Weapon = null
var is_local: bool = false

## Increments on every respawn; stale state packets from a previous life are dropped.
var _life: int = 0
var _pose_crouched: bool = false
var _send_tick: int = 0
var _fall_reported: bool = false
var _snapshots: Array[Snapshot] = []
var _render_time: float = 0.0
var _has_render_time: bool = false
var _last_fire_time: float = -INF

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var head_hitbox: Hitbox = $Hitboxes/HeadHitbox
@onready var body_hitbox: Hitbox = $Hitboxes/BodyHitbox
@onready var leg_hitbox: Hitbox = $Hitboxes/LegHitbox
@onready var model: Node3D = $Model
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var movement: Movement = $Movement
@onready var player_input: PlayerInput = $PlayerInput


## Called by the spawner before the node enters the tree, on every peer.
func setup_authority(peer_id: int) -> void:
	set_multiplayer_authority(peer_id)
	$StateSync.set_multiplayer_authority(1)


func _ready() -> void:
	assert(class_def != null, "Player needs a ClassDef")
	is_local = is_multiplayer_authority()
	movement.def = class_def.movement
	health = class_def.max_health
	_create_weapons()
	equip(0)

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
	if not is_local or not is_alive:
		return
	var cmd: PlayerCommand = player_input.gather()
	if cmd.weapon_slot >= 0:
		equip(cmd.weapon_slot)

	movement.base_speed = class_def.move_speed * current_weapon.def.move_speed_mult
	movement.physics_step(delta, cmd)
	current_weapon.tick(delta, cmd)
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
	_request_fire.rpc_id(1, origin, dir, slot)


## Host only. Returns true if this hit killed.
func take_hit(amount: float, _zone: Hitbox.Zone, attacker_id: int) -> bool:
	assert(multiplayer.is_server(), "take_hit is host-only")
	if not is_alive:
		return false
	health = maxi(health - roundi(amount), 0)
	if health > 0:
		return false
	_die(attacker_id)
	return true


## Host only. Restores health and moves the player on every peer.
func server_respawn(spawn_position: Vector3, yaw: float) -> void:
	assert(multiplayer.is_server(), "server_respawn is host-only")
	_life += 1
	health = class_def.max_health
	is_alive = true
	Net.broadcast(self, &"_respawn_at", [spawn_position, yaw, _life])


func _die(killer_id: int) -> void:
	is_alive = false
	Net.broadcast(self, &"_announce_death", [killer_id])
	died.emit(killer_id)


func _look_basis(recoil: Vector2) -> Basis:
	var pitch: float = clampf(look_pitch + deg_to_rad(recoil.y), -MAX_PITCH, MAX_PITCH)
	return Basis.from_euler(Vector3(pitch, rotation.y - deg_to_rad(recoil.x), 0.0))


func _create_weapons() -> void:
	# Stage 4 adds loadout choice; for now the class's first primary + its secondary.
	assert(not class_def.primary_weapons.is_empty(), "ClassDef has no primary weapon")
	assert(class_def.secondary_weapon != null, "ClassDef has no secondary weapon")
	var defs: Array[WeaponDef] = [class_def.primary_weapons[0], class_def.secondary_weapon]
	for def: WeaponDef in defs:
		var weapon: Weapon = def.scene.instantiate()
		weapon.setup(def, self)
		weapon.visible = false
		weapon_holder.add_child(weapon)
		weapons.append(weapon)


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
	health_changed.emit(health, class_def.max_health)


func _set_alive(value: bool) -> void:
	is_alive = value
	if is_node_ready():
		_apply_alive_state()
	alive_changed.emit(value)


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
	_store_snapshot(time, pos, yaw, pitch, crouched, life)
	_relay_state(time, pos, yaw, pitch, crouched, life)


func _relay_state(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	for peer_id: int in Net.ingame_peers:
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
func _request_fire(origin: Vector3, dir: Vector3, slot: int) -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority():
		return
	if not is_alive or slot < 0 or slot >= weapons.size():
		return
	var weapon: Weapon = weapons[slot]
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_fire_time < weapon.def.fire_interval * FIRE_RATE_TOLERANCE:
		return
	if origin.distance_to(head.global_position) > MAX_FIRE_ORIGIN_ERROR:
		return
	_last_fire_time = now
	var end_point: Vector3 = weapon.server_fire(origin, dir.normalized())
	Net.broadcast(self, &"_show_shot", [origin, end_point])


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(from: Vector3, to: Vector3) -> void:
	if not _sender_is_host() or is_local:
		return
	ShotEffects.spawn_tracer(get_parent(), from + Vector3.DOWN * REMOTE_TRACER_DROP, to)


@rpc("any_peer", "call_local", "reliable")
func confirm_hit(zone: Hitbox.Zone, killed: bool) -> void:
	if not _sender_is_host():
		return
	Events.hit_confirmed.emit(zone, killed)


@rpc("any_peer", "call_local", "reliable")
func _request_fall_death() -> void:
	if not multiplayer.is_server() or _sender_id() != get_multiplayer_authority() or not is_alive:
		return
	health = 0
	_die(get_multiplayer_authority())


@rpc("any_peer", "call_local", "reliable")
func _announce_death(killer_id: int) -> void:
	if not _sender_is_host():
		return
	Events.player_died.emit(self, killer_id)


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

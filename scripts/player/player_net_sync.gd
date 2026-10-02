class_name PlayerNetSync
extends Node
## Movement replication of one Player: owner -> host (30 Hz) -> other peers, drawn
## Player.INTERP_DELAY in the past. The host also checks every packet against a speed
## budget. Child node "NetSync" of the player scene, so its RPC path is the same everywhere.

const STATE_SEND_TICKS: int = 2 ## Physics ticks between state packets (60 Hz / 2 = 30 Hz).
const INTERP_SNAP: float = 0.25 ## Re-sync the render clock if it drifts further than this.
const INTERP_CATCHUP: float = 2.0
const MAX_SNAPSHOTS: int = 30
const MOVE_SPEED_TOLERANCE: float = 1.5 ## Host allows horizontal speed up to bhop cap * this.
const MOVE_BUDGET_SECONDS: float = 1.0 ## Movement budget window, absorbs packet bunching.


class Snapshot:
	var time: float
	var position: Vector3
	var yaw: float
	var pitch: float
	var crouched: bool


var _send_tick: int = 0
var _snapshots: Array[Snapshot] = []
var _render_time: float = 0.0
var _has_render_time: bool = false
# Host-side speed check.
var _move_budget: float = 0.0
var _last_valid_position: Vector3 = Vector3.ZERO
var _last_state_host_time: float = 0.0
var _has_valid_position: bool = false

@onready var player: Player = get_parent()


## Owner, every physics tick: sends the state every STATE_SEND_TICKS ticks.
func tick_send() -> void:
	_send_tick += 1
	if _send_tick < STATE_SEND_TICKS:
		return
	_send_tick = 0
	var time: float = _now()
	var pos: Vector3 = player.global_position
	var yaw: float = player.rotation.y
	var crouched: bool = player.is_pose_crouched()
	if multiplayer.is_server():
		_relay_state(time, pos, yaw, player.look_pitch, crouched, player.get_life())
	else:
		_submit_state.rpc_id(1, time, pos, yaw, player.look_pitch, crouched, player.get_life())


## Host: the next packet starts a new life (the host placed the player itself).
func reset_validation() -> void:
	_has_valid_position = false


## Respawn: drop buffered snapshots so the body never slides from the death spot.
func clear_snapshots() -> void:
	_snapshots.clear()
	_has_render_time = false


## Velocity from the two newest snapshots (remote players have no simulated velocity).
func get_latest_velocity() -> Vector3:
	if _snapshots.size() < 2:
		return Vector3.ZERO
	var a: Snapshot = _snapshots[_snapshots.size() - 2]
	var b: Snapshot = _snapshots[_snapshots.size() - 1]
	if b.time <= a.time:
		return Vector3.ZERO
	return (b.position - a.position) / (b.time - a.time)


## Remote peers, every frame: places the body ~INTERP_DELAY in the past.
func interpolate(delta: float) -> void:
	if _snapshots.is_empty():
		return
	var target: float = _snapshots.back().time - Player.INTERP_DELAY
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

	player.global_position = a.position.lerp(b.position, weight)
	player.rotation.y = lerp_angle(a.yaw, b.yaw, weight)
	player.look_pitch = lerpf(a.pitch, b.pitch, weight)
	player.apply_pose(b.crouched if weight >= 0.5 else a.crouched)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_state(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	if not multiplayer.is_server() or _sender_id() != player.get_multiplayer_authority():
		return
	if not _is_plausible_move(pos, life):
		return
	_store_snapshot(time, pos, yaw, pitch, crouched, life)
	_relay_state(time, pos, yaw, pitch, crouched, life)


## Host: token-bucket speed check on the host clock. Teleports are dropped, so a
## cheating client freezes in place for everyone and its shots fail the origin check.
func _is_plausible_move(pos: Vector3, life: int) -> bool:
	var now: float = _now()
	var movement_def: MovementDef = player.class_def.movement
	var max_speed: float = player.class_def.move_speed * player.status.get_host_speed_mult() \
		* movement_def.bhop_cap_mult * MOVE_SPEED_TOLERANCE
	if life != player.get_life():
		return false # Older life, or a newer one the host never started (a client cannot skip ahead).
	if not _has_valid_position:
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
	var owner_id: int = player.get_multiplayer_authority()
	for peer_id: int in Net.state_peers:
		if peer_id != 1 and peer_id != owner_id:
			_receive_state.rpc_id(peer_id, time, pos, yaw, pitch, crouched, life)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_state(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	if _sender_id() != 1:
		return
	_store_snapshot(time, pos, yaw, pitch, crouched, life)


func _store_snapshot(time: float, pos: Vector3, yaw: float, pitch: float, crouched: bool, life: int) -> void:
	if life < player.get_life():
		return
	if life > player.get_life():
		player.adopt_life(life)
		clear_snapshots()
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


func _sender_id() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0

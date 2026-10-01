class_name LagCompensator
extends Node
## Host only. Records every player's pose each physics tick and, for a shot,
## moves the other players back to where the shooter saw them, traces, then restores.
##
## How far back: a client-owned target is drawn on the host ~INTERP_DELAY behind reality,
## and on the shooter's screen one extra relay hop (host -> shooter) later; the shot then
## takes another hop back. So rewind = shooter RTT. A host-owned target is drawn live on
## the host, so it additionally needs the shooter's interpolation delay.

const GROUP: StringName = &"lag_compensator"
const HISTORY_SECONDS: float = 1.0
const MAX_REWIND: float = 0.4 ## Players with worse ping must lead their shots.


class Sample:
	var time: float
	var position: Vector3
	var yaw: float
	var crouched: bool


var _history: Dictionary[Player, Array] = {}

@onready var _players_root: Node = get_parent().get_node("Players")


static func find(tree: SceneTree) -> LagCompensator:
	return tree.get_first_node_in_group(GROUP) as LagCompensator


func _ready() -> void:
	add_to_group(GROUP)
	_players_root.child_exiting_tree.connect(_on_player_exiting)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now: float = _now()
	for child: Node in _players_root.get_children():
		var player := child as Player
		if player == null:
			continue
		var samples: Array = _history.get_or_add(player, [])
		var sample := Sample.new()
		sample.time = now
		sample.position = player.global_position
		sample.yaw = player.rotation.y
		sample.crouched = player.is_pose_crouched()
		samples.append(sample)
		while not samples.is_empty() and (samples[0] as Sample).time < now - HISTORY_SECONDS:
			samples.pop_front()


## A typed dictionary cannot erase a freed key, so a leaving player is dropped while still valid.
func _on_player_exiting(node: Node) -> void:
	var player := node as Player
	if player != null:
		_history.erase(player)


## Drops a player's history (on respawn), so shots never rewind into a previous life.
func forget(player: Player) -> void:
	_history.erase(player)


## Runs `weapon.server_fire` with every other living player rewound for `shooter`.
func fire_rewound(shooter: Player, weapon: Weapon, origin: Vector3, dir: Vector3) -> Vector3:
	var rtt: float = _get_rtt_seconds(shooter.get_multiplayer_authority())
	var now: float = _now()
	var restore: Array[Array] = []
	for key: Variant in _history.keys():
		if not is_instance_valid(key):
			continue
		var target: Player = key
		if target == shooter or not target.is_alive:
			continue
		var extra: float = Player.INTERP_DELAY if target.is_local else 0.0
		var rewind: float = minf(rtt + extra, MAX_REWIND)
		if rewind <= 0.0:
			continue
		var sample: Sample = _sample_at(_history[target], now - rewind)
		if sample == null:
			continue
		restore.append([target, target.global_position, target.rotation.y, target.is_pose_crouched()])
		target.set_hit_pose(sample.position, sample.yaw, sample.crouched)

	var end_point: Vector3 = weapon.server_fire(origin, dir)

	for entry: Array in restore:
		(entry[0] as Player).set_hit_pose(entry[1], entry[2], entry[3])
	return end_point


func _sample_at(samples: Array, time: float) -> Sample:
	if samples.is_empty():
		return null
	var first: Sample = samples[0]
	if time <= first.time:
		return first
	for i: int in range(samples.size() - 1):
		var a: Sample = samples[i]
		var b: Sample = samples[i + 1]
		if b.time >= time:
			var weight: float = (time - a.time) / maxf(b.time - a.time, 0.0001)
			var result := Sample.new()
			result.time = time
			result.position = a.position.lerp(b.position, weight)
			result.yaw = lerp_angle(a.yaw, b.yaw, weight)
			result.crouched = b.crouched if weight >= 0.5 else a.crouched
			return result
	return samples.back()


func _get_rtt_seconds(peer_id: int) -> float:
	if peer_id == 1:
		return 0.0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return 0.0
	var packet_peer: ENetPacketPeer = enet.get_peer(peer_id)
	if packet_peer == null:
		return 0.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 1000.0


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0

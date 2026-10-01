class_name PlayerRequests
extends Node
## Owner -> host requests of one Player (fire, quick melee, ability, loadout, fall death)
## and the host's checks: right sender, alive, not stunned, fire-rate budget, shot origin
## near the eye the host knows. Child node "Requests" of the player scene.

const FIRE_RATE_TOLERANCE: float = 0.95 ## Sustained host-side rate limit: shot interval * this.
const FIRE_BURST_SLACK: float = 0.25 ## Seconds of shots that may arrive bunched up (jitter, resends).
const MAX_FIRE_ORIGIN_ERROR: float = 3.0 ## Metres between claimed and known eye position.

# Host: fire-rate budgets (host clock).
var _next_fire_time: float = -INF
var _next_melee_time: float = -INF

@onready var player: Player = get_parent()


func send_fire(origin: Vector3, dir: Vector3, slot: int) -> void:
	_request_fire.rpc_id(1, origin, dir, slot, player.weapons[slot].def.id)


func send_melee(origin: Vector3, dir: Vector3) -> void:
	_request_melee.rpc_id(1, origin, dir)


func send_ability(origin: Vector3, dir: Vector3) -> void:
	_request_ability.rpc_id(1, origin, dir)


func send_loadout(code: PackedInt32Array) -> void:
	_request_loadout.rpc_id(1, code)


func send_fall_death() -> void:
	_request_fall_death.rpc_id(1)


## Host: the sender owns this player (the host's own calls count as from peer 1).
func _from_owner() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	return multiplayer.is_server() and (sender if sender != 0 else 1) == player.get_multiplayer_authority()


func _origin_ok(origin: Vector3) -> bool:
	return origin.distance_to(player.get_aim_origin()) <= MAX_FIRE_ORIGIN_ERROR


## Host: firing (or swinging) ends spawn protection (GDD).
func _end_protection() -> void:
	if Match.state == Match.State.PLAYING:
		player.is_protected = false


@rpc("any_peer", "call_local", "reliable")
func _request_fire(origin: Vector3, dir: Vector3, slot: int, weapon_id: StringName) -> void:
	if not _from_owner() or not player.is_alive or player.status.is_stunned_host():
		return
	if slot < 0 or slot >= player.weapons.size():
		return
	var weapon: Weapon = player.weapons[slot]
	if weapon.def.id != weapon_id:
		return # Fired with the previous loadout's weapon, still in flight after a swap.
	var now: float = Time.get_ticks_msec() / 1000.0
	# Budget, not gap between arrivals: bunched packets pass, sustained over-rate does not.
	if now < _next_fire_time - FIRE_BURST_SLACK or not _origin_ok(origin):
		return
	var interval: float = weapon.def.get_average_shot_interval() * FIRE_RATE_TOLERANCE / player.status.get_host_fire_rate_mult()
	_next_fire_time = maxf(_next_fire_time, now - FIRE_BURST_SLACK) + interval
	_end_protection()
	var end_point: Vector3
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		end_point = compensator.fire_rewound(player, weapon, origin, dir.normalized())
	else:
		end_point = weapon.server_fire(origin, dir.normalized())
	if weapon is ShotgunWeapon:
		player.effects.server_show_pellets((weapon as ShotgunWeapon).last_pellet_ends)
	elif weapon.def.fire_type == WeaponDef.FireType.HITSCAN:
		player.effects.server_show_shot(origin, end_point)


@rpc("any_peer", "call_local", "reliable")
func _request_melee(origin: Vector3, dir: Vector3) -> void:
	if not _from_owner() or not player.is_alive or player.status.is_stunned_host():
		return
	var melee: MeleeWeapon = player.melee_weapon
	if melee == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _next_melee_time - FIRE_BURST_SLACK or not _origin_ok(origin):
		return
	_next_melee_time = maxf(_next_melee_time, now - FIRE_BURST_SLACK) + melee.def.fire_interval * FIRE_RATE_TOLERANCE
	_end_protection()
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		compensator.fire_rewound(player, melee, origin, dir.normalized())
	else:
		melee.server_fire(origin, dir.normalized())


@rpc("any_peer", "call_local", "reliable")
func _request_ability(origin: Vector3, dir: Vector3) -> void:
	if not _from_owner() or not player.is_alive or player.status.is_stunned_host():
		return
	if player.ability == null or Match.state != Match.State.PLAYING or not _origin_ok(origin):
		return
	if player.ability.server_try_use(origin, dir.normalized()):
		_end_protection()


@rpc("any_peer", "call_local", "reliable")
func _request_loadout(code: PackedInt32Array) -> void:
	if not _from_owner() or not Loadout.is_valid(code):
		return
	player.server_choose_loadout(code)


@rpc("any_peer", "call_local", "reliable")
func _request_fall_death() -> void:
	if not _from_owner() or not player.is_alive or Match.state != Match.State.PLAYING:
		return # Between matches: the restart respawns everyone anyway.
	player.server_fall_death()

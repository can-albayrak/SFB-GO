class_name PlayerStatus
extends Node
## Timed states of one Player that the host decides and the owner feels: Bear's Shield,
## the Charge stun, kick knockback, the Adrenaline boost, the kill reward and thrown-knife
## returns. The host keeps its own clock; the owner is told by RPC.
## Child node "Status" of the player scene, so its RPC path is the same everywhere.

const SHIELD_BLOCK_COS: float = 0.26 ## Hits from within ~75 degrees of the facing are blocked.

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

@onready var player: Player = get_parent()


## Owner, every physics tick.
func tick_local(delta: float) -> void:
	_stun_left = maxf(_stun_left - delta, 0.0)
	_buff_left = maxf(_buff_left - delta, 0.0)


## Host, every physics tick.
func server_tick() -> void:
	if _shield_until > 0.0 and _now() >= _shield_until:
		clear_shield()


func is_stunned_local() -> bool:
	return _stun_left > 0.0


func is_stunned_host() -> bool:
	return _now() < _stun_until


## Owner: respawn or death; nothing carries over.
func reset_local() -> void:
	_stun_left = 0.0
	_buff_left = 0.0


## Host: respawn or death.
func reset_host() -> void:
	_stun_until = 0.0
	_host_buff_until = 0.0
	clear_shield()


## Both sides: a loadout change ends any boost and Bear's Shield (it belongs to the class that used it).
func clear_buffs() -> void:
	_buff_left = 0.0
	_host_buff_until = 0.0
	clear_shield()


## Host: kill reward. Health is host-owned; ammo lives on the owner, so the owner adds it.
func server_kill_reward(heal: int, ammo: int) -> void:
	assert(multiplayer.is_server(), "server_kill_reward is host-only")
	if not player.is_alive:
		return
	player.health = mini(player.health + heal, player.class_def.max_health)
	if ammo > 0:
		_receive_kill_ammo.rpc_id(player.get_multiplayer_authority(), ammo)


## Host: Shield ability. Frontal hits are blocked for `seconds`; everyone sees the panel.
func server_activate_shield(seconds: float) -> void:
	assert(multiplayer.is_server(), "server_activate_shield is host-only")
	_shield_until = _now() + seconds
	player.shield_up = true # Replicated: everyone (late joiners too) sees the panel.


func clear_shield() -> void:
	if _shield_until <= 0.0:
		return
	_shield_until = 0.0
	if multiplayer.is_server():
		player.shield_up = false


## Host: is a hit from `attacker_id` stopped by the raised shield?
func shield_blocks(attacker_id: int) -> bool:
	if _shield_until <= 0.0 or _now() >= _shield_until or attacker_id == player.get_multiplayer_authority():
		return false
	var attacker := player.get_parent().get_node_or_null(str(attacker_id)) as Player
	if attacker == null:
		return false
	var to_attacker: Vector3 = attacker.global_position - player.global_position
	to_attacker.y = 0.0
	var forward: Vector3 = -player.global_basis.z
	forward.y = 0.0
	if to_attacker.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return true # Standing inside each other counts as in front.
	return forward.normalized().dot(to_attacker.normalized()) > SHIELD_BLOCK_COS


## Host: Charge hit. Blocks the victim's actions and tells its owner to freeze the input.
func server_stun(seconds: float) -> void:
	assert(multiplayer.is_server(), "server_stun is host-only")
	_stun_until = _now() + seconds
	_receive_stun.rpc_id(player.get_multiplayer_authority(), seconds)


## Host: pushes this player (kick). Movement belongs to the owner, so the owner applies it.
func server_knockback(impulse: Vector3) -> void:
	assert(multiplayer.is_server(), "server_knockback is host-only")
	_receive_knockback.rpc_id(player.get_multiplayer_authority(), impulse)


## Host: a thrown knife is back (picked up or timed out). Refills the owner's knife ammo.
func server_return_throwable() -> void:
	assert(multiplayer.is_server(), "server_return_throwable is host-only")
	_return_throwable.rpc_id(player.get_multiplayer_authority())


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


func get_host_speed_mult() -> float:
	return _host_buff_speed_mult if _now() < _host_buff_until else 1.0


func get_host_fire_rate_mult() -> float:
	return _host_buff_fire_mult if _now() < _host_buff_until else 1.0


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _from_host_to_owner() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	return (sender if sender != 0 else multiplayer.get_unique_id()) == 1 and player.is_local


@rpc("any_peer", "call_local", "reliable")
func _receive_stun(seconds: float) -> void:
	if not _from_host_to_owner():
		return
	_stun_left = seconds
	player.movement.cancel_specials()
	Events.local_stunned.emit(seconds)


@rpc("any_peer", "call_local", "reliable")
func _receive_knockback(impulse: Vector3) -> void:
	if not _from_host_to_owner() or not player.is_alive:
		return
	player.velocity += impulse


## Host -> owner: kill reward rounds for the weapon in hand (a reload in progress fills it anyway).
@rpc("any_peer", "call_local", "reliable")
func _receive_kill_ammo(amount: int) -> void:
	if not _from_host_to_owner() or not player.is_alive:
		return
	var weapon: Weapon = player.current_weapon
	if weapon.def.uses_ammo and weapon.def.kill_ammo_reward and not weapon.is_reloading:
		weapon.add_ammo(amount)


@rpc("any_peer", "call_local", "reliable")
func _return_throwable() -> void:
	if not _from_host_to_owner():
		return
	for weapon: Weapon in player.weapons:
		if weapon.def.fire_type == WeaponDef.FireType.THROWN:
			weapon.add_ammo(1)

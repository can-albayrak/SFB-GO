class_name Ability
extends Node
## Base for Q abilities.
## Owner: local cooldown (drives the HUD) + optional instant local effect, then asks the host.
## Host: checks its own cooldown clock and runs server_use(). Subclasses override
## _use_local() (e.g. movement abilities, owner-authoritative) and/or server_use().

## Host accepts a use slightly early, so jitter on the owner's clock never eats a use.
const HOST_COOLDOWN_TOLERANCE: float = 0.9

var def: AbilityDef
var player: Player
## Owner-side seconds until ready (HUD).
var cooldown_left: float = 0.0

## Host clock time when the next use is accepted (carried across loadout swaps).
var host_ready_at: float = -INF


func setup(ability_def: AbilityDef, owner_player: Player) -> void:
	def = ability_def
	player = owner_player


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return cooldown_left <= 0.0


## Owner. Returns true when used (caller then sends the request to the host).
func try_use(origin: Vector3, dir: Vector3) -> bool:
	if cooldown_left > 0.0:
		return false
	cooldown_left = def.cooldown
	_use_local(origin, dir)
	return true


## Host. Returns true when accepted.
func server_try_use(origin: Vector3, dir: Vector3) -> bool:
	assert(multiplayer.is_server(), "server_try_use is host-only")
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < host_ready_at:
		return false
	host_ready_at = now + def.cooldown * HOST_COOLDOWN_TOLERANCE
	server_use(origin, dir)
	return true


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	pass


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	pass

class_name CloakAbility
extends Ability
## Ghost Cloak: nearly invisible to everyone for def.duration seconds; the body fades out
## over def.fade_time (no instant vanish). Firing, stabbing or getting hit ends it early.
## The host owns the state (Player.cloaked, replicated); everyone draws it.

var _active_left: float = 0.0 ## Owner, for the HUD.


func _use_local(_origin: Vector3, _dir: Vector3) -> void:
	_active_left = def.duration


func tick(delta: float) -> void:
	super.tick(delta)
	_active_left = maxf(_active_left - delta, 0.0)
	if _active_left > 0.0 and player.is_local and not player.cloaked and _active_left < def.duration - 0.5:
		_active_left = 0.0 # The host ended it (we fired or were hit).


func server_use(_origin: Vector3, _dir: Vector3) -> void:
	player.server_cloak(def.duration)


func get_hud_window() -> Array:
	if _active_left <= 0.0:
		return []
	return [_active_left, def.duration, "CLOAK  ACTIVE", false]

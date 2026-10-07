class_name StickyBombAbility
extends GrenadeAbility
## Volcano Sticky Bomb (Can, 2026-10-07): the first Q throws it, a second Q inside def.duration
## sets it off (striped HUD bar, like Phantom's recall). The cooldown starts when that window
## closes: set off, timed out (it then goes off by itself) or the thrower died (it fizzles, so
## no kills from the grave). The host owns the bomb; the owner only runs the HUD timer.

var _window_left: float = 0.0 ## Owner: seconds left to set it off.
var _threw: bool = false ## Owner: the last use was the throw, not the trigger.
var _bomb: Grenade = null ## Host.


func try_use(_origin: Vector3, _dir: Vector3) -> bool:
	if _window_left > 0.0:
		_window_left = 0.0 # Set it off.
		_threw = false
		cooldown_left = get_cooldown()
		return true
	if cooldown_left > 0.0:
		return false
	_window_left = def.duration
	_threw = true
	return true


func threw_last() -> bool:
	return _threw


func tick(delta: float) -> void:
	super.tick(delta)
	if _window_left > 0.0:
		_window_left = maxf(_window_left - delta, 0.0)
		if _window_left <= 0.0 or not player.is_alive:
			_window_left = 0.0
			cooldown_left = get_cooldown()


func reset_for_respawn() -> void:
	super.reset_for_respawn()
	_window_left = 0.0


func get_hud_window() -> Array:
	if _window_left <= 0.0:
		return []
	return [_window_left, def.duration, "DETONATE", true]


func server_try_use(origin: Vector3, dir: Vector3) -> bool:
	assert(multiplayer.is_server(), "server_try_use is host-only")
	var now: float = Time.get_ticks_msec() / 1000.0
	if is_instance_valid(_bomb):
		_bomb.server_detonate()
		_end_window(now)
		return true
	if now < host_ready_at:
		return false
	_bomb = _server_throw(origin, dir)
	host_ready_at = INF # Until the window closes.
	return true


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or host_ready_at != INF:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if not is_instance_valid(_bomb): # Went off by itself at the end of its fuse.
		_end_window(now)
	elif not player.is_alive:
		_bomb.queue_free()
		_end_window(now)


func _end_window(now: float) -> void:
	_bomb = null
	host_ready_at = now + get_cooldown() * HOST_COOLDOWN_TOLERANCE


func _exit_tree() -> void:
	if is_instance_valid(_bomb) and multiplayer.is_server():
		_bomb.queue_free() # Loadout swap mid-window: the bomb belonged to the old class.

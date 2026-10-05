class_name RecallAbility
extends Ability
## Phantom Mark / Recall. First Q leaves a mark where the Phantom stands, seen by everyone,
## for def.duration seconds. A second Q inside that window teleports the Phantom back to it.
## The cooldown starts when the window closes (recalled, timed out or died). The host owns
## the mark and the teleport; the owner only runs the HUD timers.

var _window_left: float = 0.0 ## Owner: seconds left to recall (HUD, striped bar).
# Host.
var _mark_until: float = -INF
var _mark_point: Vector3 = Vector3.ZERO
var _mark_live: bool = false


func try_use(origin: Vector3, dir: Vector3) -> bool:
	if _window_left > 0.0:
		_window_left = 0.0 # Recall.
		cooldown_left = get_cooldown()
		return true
	if cooldown_left > 0.0:
		return false
	_window_left = def.duration # Mark; the cooldown waits for the window to close.
	return true


func tick(delta: float) -> void:
	super.tick(delta)
	if _window_left > 0.0:
		_window_left = maxf(_window_left - delta, 0.0)
		if _window_left <= 0.0 or not player.is_alive:
			_window_left = 0.0
			cooldown_left = get_cooldown()


func get_hud_window() -> Array:
	if _window_left <= 0.0:
		return []
	return [_window_left, def.duration, "RECALL", true]


func server_try_use(_origin: Vector3, _dir: Vector3) -> bool:
	assert(multiplayer.is_server(), "server_try_use is host-only")
	var now: float = _now()
	if _mark_live:
		var point: Vector3 = _mark_point
		_end_mark(now)
		player.server_teleport(point)
		return true
	if now < host_ready_at:
		return false
	_mark_live = true
	_mark_point = player.global_position
	_mark_until = now + def.duration
	player.effects.server_show_mark(_mark_point, def.duration)
	return true


func _physics_process(_delta: float) -> void:
	if not _mark_live or not multiplayer.is_server():
		return
	var now: float = _now()
	if now >= _mark_until or not player.is_alive:
		_end_mark(now)


func _end_mark(now: float) -> void:
	_mark_live = false
	host_ready_at = now + get_cooldown() * HOST_COOLDOWN_TOLERANCE
	player.effects.server_hide_mark()


func _exit_tree() -> void:
	if _mark_live and multiplayer.is_server() and is_instance_valid(player) and player.is_inside_tree():
		player.effects.server_hide_mark() # Loadout swap mid-window.


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

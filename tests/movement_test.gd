extends Node
## Headless movement test on the test range stairs (Geometry/Stairs, Geometry/SingleSteps):
##   godot --headless --path . res://tests/movement_test.tscn
## Drives Movement directly with a held W: single steps up to MovementDef.step_height are
## climbed (step-up), stairs (visual steps over a ramp collider) are climbed and walked
## down with the feet on the floor, a 0.6 m block is not stepped onto.
## Prints PASS / FAIL lines and quits with exit code 1 when anything failed.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const STAIRS_X: float = -36.0
const LANDING_TOP: float = 2.0
const TIMEOUT: float = 60.0

var _passes: int = 0
var _failures: int = 0
var _game: Game
var _player: Player


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.player_names[1] = "Tester"
	Net.map_path = Net.DEFAULT_MAP_PATH
	Match.configure(0, 0.0)
	_game = GAME_SCENE.instantiate() as Game
	add_child(_game)
	await _frames(5)
	_player = _game.players_root.get_node_or_null("1") as Player
	_check(_player != null, "local player spawned")
	if _player == null:
		_finish()
		return
	_player.set_physics_process(false) # The test feeds the commands.
	await _test_single_steps()
	await _test_stairs_up()
	await _test_stairs_down()
	await _test_too_high()
	_finish()


func _test_single_steps() -> void:
	# x -26: 0.15 m at z -19.25 .. -20.75, 0.3 m at -22.75 .. -24.25, 0.4 m at -26.25 .. -27.75.
	var stats: Dictionary = await _walk(Vector3(-26.0, 0.05, -17.0), 0.0, -26.8)
	_check(stats.reached, "steps up 0.15 / 0.3 / 0.4 m single steps")
	_check(absf(_player.global_position.y - 0.4) < 0.05, "stands on the 0.4 m step (y=%.2f)" % _player.global_position.y)
	_check(stats.min_speed > 4.0, "keeps running speed over single steps (lowest %.1f m/s)" % stats.min_speed)
	_check(stats.eye_dipped, "camera eases up instead of popping")
	# Off a single step's edge the capsule drops a little (no snap over an edge); speed is kept.
	stats = await _walk(Vector3(-26.0, 0.45, -27.0), PI, -17.0)
	_check(stats.reached and stats.min_speed > 4.0, "walks down single steps at speed (lowest %.1f m/s)" % stats.min_speed)


func _test_stairs_up() -> void:
	# Facing -Z (yaw 0): kerb at z -20, steps from z -22, landing top 2 m at z -24.8 .. -27.8.
	var stats: Dictionary = await _walk(Vector3(STAIRS_X, 0.05, -17.0), 0.0, -25.5)
	_check(stats.reached, "walks over the kerb and up the stairs to the landing")
	_check(absf(_player.global_position.y - LANDING_TOP) < 0.1, "stands on the landing (y=%.2f)" % _player.global_position.y)
	_check(stats.min_speed > 3.0, "keeps running speed on the stairs (lowest %.1f m/s)" % stats.min_speed)


func _test_stairs_down() -> void:
	var stats: Dictionary = await _walk(Vector3(STAIRS_X, LANDING_TOP + 0.05, -25.5), PI, -16.0)
	_check(stats.reached, "walks down the stairs")
	_check(stats.air_ticks <= 2, "feet stay on the floor walking down (%d ticks in the air)" % stats.air_ticks)


func _test_too_high() -> void:
	# The 0.6 m block at x -31, z -21 .. -23.
	var stats: Dictionary = await _walk(Vector3(-31.0, 0.05, -18.0), 0.0, -22.0, 2.0)
	_check(not stats.reached and _player.global_position.y < 0.3, "does not step onto a 0.6 m block")


## Holds W from `from` facing `yaw` until z passes `target_z` or `seconds` run out.
func _walk(from: Vector3, yaw: float, target_z: float, seconds: float = 4.0) -> Dictionary:
	_player.global_position = from
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO
	_player.movement.reset()
	await _frames(2)
	var cmd := PlayerCommand.new()
	cmd.move = Vector2(0.0, -1.0)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var forward_z: float = signf(target_z - from.z)
	var stats: Dictionary = {"reached": false, "air_ticks": 0, "min_speed": INF, "eye_dipped": false}
	var ticks: int = 0
	while ticks * dt < seconds:
		_player.movement.physics_step(dt, cmd)
		await get_tree().physics_frame
		ticks += 1
		if not _player.is_on_floor():
			stats.air_ticks += 1
		if _player.head.position.y < Movement.STAND_EYE - 0.05:
			stats.eye_dipped = true
		if ticks * dt > 1.0: # Past the run-up.
			stats.min_speed = minf(stats.min_speed, _player.movement.get_horizontal_speed())
		if (_player.global_position.z - target_z) * forward_z >= 0.0:
			stats.reached = true
			break
	return stats


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)


func _finish() -> void:
	print("MOVEMENT TEST: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _on_timeout() -> void:
	_check(false, "finished within %d s" % roundi(TIMEOUT))
	_finish()

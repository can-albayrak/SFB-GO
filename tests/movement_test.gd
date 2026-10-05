extends Node
## Headless movement test with the real Movement code (move_and_slide, step-up, floor snap):
##   godot --headless --path . res://tests/movement_test.tscn
## Test range (Geometry/Stairs, Geometry/SingleSteps): single steps up to
## MovementDef.step_height are climbed, stairs (visual steps over a ramp collider) are
## climbed and walked down with the feet on the floor, a 0.6 m block is not stepped onto.
## Mall: escalator up and down, roof stairs, fire escape, dock ramp (ramp-to-slab joints),
## and a full-speed jump off the roof stays inside the site (invisible walls on the fence).
## Slides: on flat ground a slide only slows down; down the escalator it speeds up and lasts.
## Train Factory: the long ladder (func_ladder from the BSP) climbs onto the 10.5 m crane girder,
## looking down climbs back down, and jump lets go.
## Prints PASS / FAIL lines and quits with exit code 1 when anything failed.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const STAIRS_X: float = -36.0
const LANDING_TOP: float = 2.0
const MALL_PATH: String = "res://scenes/maps/mall/mall.tscn"
const ROOF_TOP: float = 10.0
const UPPER_TOP: float = 5.0
const SITE_HALF_DEPTH: float = 32.0 ## Mall site fence at z = +-32.
const LEAP_SPEED: float = 12.0 ## Above Cheetah's slide speed (7.6 * 1.55).
const TRAIN_PATH: String = "res://scenes/maps/train_factory/train_factory.tscn"
const CATWALK_TOP: float = 10.5
const TIMEOUT: float = 120.0

var _passes: int = 0
var _failures: int = 0
var _game: Game
var _player: Player
var _flat_slide: Dictionary = {}


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.player_names[1] = "Tester"
	if await _load_map(Net.DEFAULT_MAP_PATH):
		await _test_single_steps()
		await _test_stairs_up()
		await _test_stairs_down()
		await _test_too_high()
		_flat_slide = await _slide(Vector3(0.0, 0.05, 0.0), 0.0, 2.5)
		_check(_flat_slide.max_speed <= _flat_slide.start_speed + 0.05,
			"a slide on flat ground does not speed up (%.1f -> max %.1f m/s)" % [_flat_slide.start_speed, _flat_slide.max_speed])
	if await _load_map(MALL_PATH):
		await _test_mall_ramps()
		await _test_slope_slide()
		await _test_roof_leap()
	if await _load_map(TRAIN_PATH):
		await _test_ladder()
	_finish()


func _load_map(path: String) -> bool:
	if _game != null:
		_game.queue_free()
		await _frames(3)
	Net.map_path = path
	Match.configure(0, 0.0)
	_game = GAME_SCENE.instantiate() as Game
	add_child(_game)
	await _frames(5)
	_player = _game.players_root.get_node_or_null("1") as Player
	_check(_player != null, "local player spawned on %s" % path.get_file())
	if _player == null:
		return false
	_player.set_physics_process(false) # The test feeds the commands.
	_player.loadout = Loadout.default_code() # Not the tester's saved class: results must not depend on it.
	return true


func _test_single_steps() -> void:
	# x -26: 0.15 m at z -19.25 .. -20.75, 0.3 m at -22.75 .. -24.25, 0.4 m at -26.25 .. -27.75.
	var stats: Dictionary = await _walk(Vector3(-26.0, 0.05, -17.0), 0.0, Vector3(-26.0, 0.0, -26.8))
	_check(stats.reached, "steps up 0.15 / 0.3 / 0.4 m single steps")
	_check(absf(_player.global_position.y - 0.4) < 0.05, "stands on the 0.4 m step (y=%.2f)" % _player.global_position.y)
	_check(stats.min_speed > 4.0, "keeps running speed over single steps (lowest %.1f m/s)" % stats.min_speed)
	_check(stats.eye_dipped, "camera eases up instead of popping")
	# Off a single step's edge the capsule drops a little (no snap over an edge); speed is kept.
	stats = await _walk(Vector3(-26.0, 0.45, -27.0), PI, Vector3(-26.0, 0.0, -17.0))
	_check(stats.reached and stats.min_speed > 4.0, "walks down single steps at speed (lowest %.1f m/s)" % stats.min_speed)


func _test_stairs_up() -> void:
	# Facing -Z (yaw 0): kerb at z -20, steps from z -22, landing top 2 m at z -24.8 .. -27.8.
	var stats: Dictionary = await _walk(Vector3(STAIRS_X, 0.05, -17.0), 0.0, Vector3(STAIRS_X, 0.0, -25.5))
	_check(stats.reached, "walks over the kerb and up the stairs to the landing")
	_check(absf(_player.global_position.y - LANDING_TOP) < 0.1, "stands on the landing (y=%.2f)" % _player.global_position.y)
	_check(stats.min_speed > 3.0, "keeps running speed on the stairs (lowest %.1f m/s)" % stats.min_speed)


func _test_stairs_down() -> void:
	# Stops on the kerb (z -21 .. -19), before its far edge: dropping off a single step's edge
	# is a known short fall and is covered by _test_single_steps, not by this stairs check.
	var stats: Dictionary = await _walk(Vector3(STAIRS_X, LANDING_TOP + 0.05, -25.5), PI, Vector3(STAIRS_X, 0.0, -19.5))
	_check(stats.reached, "walks down the stairs")
	_check(stats.air_ticks <= 2, "feet stay on the floor walking down (%d ticks in the air)" % stats.air_ticks)


func _test_too_high() -> void:
	# The 0.6 m block at x -31, z -21 .. -23. Every class: a fast run (Cheetah) once climbed
	# it in two steps, resting the capsule's rounded bottom on the edge first.
	var classes: Array[ClassDef] = Loadout.roster().classes
	for i: int in classes.size():
		_player.loadout = Loadout.make(i, 0, 0)
		var stats: Dictionary = await _walk(Vector3(-31.0, 0.05, -18.0), 0.0, Vector3(-31.0, 0.0, -22.0), 2.0)
		_check(not stats.reached and _player.global_position.y < 0.3,
			"%s does not step onto a 0.6 m block" % classes[i].display_name)
	_player.loadout = Loadout.default_code()


func _test_mall_ramps() -> void:
	# Each case: start, yaw (0 = facing -Z, PI/2 = facing -X), target, height expected there.
	var cases: Array[Array] = [
		["escalator up", Vector3(4.0, 0.05, -5.0), PI / 2.0, Vector3(-12.0, 0.0, -5.0), UPPER_TOP],
		["escalator down", Vector3(-12.0, UPPER_TOP + 0.05, -5.0), -PI / 2.0, Vector3(3.0, 0.0, -5.0), 0.0],
		["roof stairs up", Vector3(30.35, UPPER_TOP + 0.05, -7.2), PI, Vector3(30.35, 0.0, 8.5), ROOF_TOP],
		["roof stairs down", Vector3(30.35, ROOF_TOP + 0.05, 8.5), 0.0, Vector3(30.35, 0.0, -7.2), UPPER_TOP],
		["fire escape to the landing", Vector3(-33.4, 0.05, 31.0), 0.0, Vector3(-33.4, 0.0, 14.0), UPPER_TOP],
		["fire escape to the roof", Vector3(-36.0, UPPER_TOP + 0.05, 15.0), 0.0, Vector3(-36.0, 0.0, -2.0), ROOF_TOP],
		["dock ramp", Vector3(-34.5, 0.05, 6.0), 0.0, Vector3(-34.5, 0.0, -4.0), 1.2],
		["supermarket stairs down", Vector3(-30.35, UPPER_TOP + 0.05, -19.0), PI, Vector3(-30.35, 0.0, -4.0), 0.0],
		["fire escape down from the roof", Vector3(-36.0, ROOF_TOP + 0.05, -1.5), PI, Vector3(-36.0, 0.0, 13.5), UPPER_TOP],
		["balcony stairs down", Vector3(34.25, UPPER_TOP + 0.05, 15.0), PI, Vector3(34.25, 0.0, 31.0), 0.0],
	]
	for case: Array in cases:
		var stats: Dictionary = await _walk(case[1], case[2], case[3], 6.0)
		var y: float = _player.global_position.y
		_check(stats.reached and absf(y - (case[4] as float)) < 0.15, "mall %s (y=%.2f)" % [case[0], y])
		_check(stats.min_speed > 3.0, "mall %s keeps speed (lowest %.1f m/s)" % [case[0], stats.min_speed])
		_check(stats.air_ticks <= 3, "mall %s stays on the floor (%d ticks in the air)" % [case[0], stats.air_ticks])


## Slide from the top of the down escalator: the slope pulls the slide faster than it started
## and keeps it going past MovementDef.slide_duration.
func _test_slope_slide() -> void:
	var stats: Dictionary = await _slide(Vector3(-12.0, UPPER_TOP + 0.05, -5.0), -PI / 2.0, 2.5)
	_check(stats.max_speed > stats.start_speed + 1.0,
		"a slide down the escalator speeds up (%.1f -> max %.1f m/s)" % [stats.start_speed, stats.max_speed])
	_check(stats.slide_time > _player.class_def.movement.slide_duration,
		"a slide down the escalator outlasts a flat slide (%.2f s)" % stats.slide_time)
	_check(stats.max_speed <= _player.movement.base_speed * _player.class_def.movement.slide_slope_max_speed_mult + 0.05,
		"slope slide stays under its cap (max %.1f m/s)" % stats.max_speed)


## Runs into a slide at `from` facing `yaw` (crouch held) for `seconds`: speeds and slide time.
func _slide(from: Vector3, yaw: float, seconds: float) -> Dictionary:
	_player.global_position = from
	_player.rotation.y = yaw
	_player.movement.reset()
	_player.movement.base_speed = _player.class_def.move_speed # Physics is off: nothing else sets it.
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	_player.velocity = forward * _player.movement.base_speed
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var stats: Dictionary = {"start_speed": 0.0, "max_speed": 0.0, "slide_time": 0.0}
	for i: int in roundi(seconds / dt):
		var cmd := PlayerCommand.new()
		cmd.move = Vector2(0.0, -1.0)
		cmd.crouch = true
		cmd.crouch_pressed = i == 0
		_player.movement.physics_step(dt, cmd)
		await get_tree().physics_frame
		if i == 0:
			stats.start_speed = _player.movement.get_horizontal_speed()
		if not _player.movement.is_sliding:
			break
		stats.slide_time += dt
		stats.max_speed = maxf(stats.max_speed, _player.movement.get_horizontal_speed())
	_player.movement.reset()
	return stats


## Leaps off the roof edge north and south at full speed: the site's invisible walls keep the
## player inside the fence and they land on the site floor.
func _test_roof_leap() -> void:
	for side: float in [-1.0, 1.0]:
		_player.global_position = Vector3(0.0, ROOF_TOP + 1.3, side * 24.4)
		_player.velocity = Vector3(0.0, _player.class_def.movement.jump_velocity, side * LEAP_SPEED)
		_player.movement.reset()
		var cmd := PlayerCommand.new()
		var dt: float = 1.0 / Engine.physics_ticks_per_second
		var furthest: float = 0.0
		for i: int in roundi(4.0 / dt):
			_player.movement.physics_step(dt, cmd)
			await get_tree().physics_frame
			furthest = maxf(furthest, absf(_player.global_position.z))
		var label: String = "north" if side < 0.0 else "south"
		_check(furthest < SITE_HALF_DEPTH and _player.global_position.y > -0.5,
			"a full-speed leap off the %s roof edge stays on the site (|z| max %.1f, y %.1f)" % [label, furthest, _player.global_position.y])


## Holds W from `from` facing `yaw` until it passes `target` (along the facing) or `seconds` run out.
func _test_ladder() -> void:
	# Ladder1: x 26.8 .. 28.0 in front of the catwalk's south edge (z -1.5), 1.6 .. 10.6 m.
	var stats: Dictionary = await _climb(Vector3(27.4, 1.7, -2.3), 0.3, 6.0)
	_check(_player.global_position.y > CATWALK_TOP - 0.1 and _player.is_on_floor(),
		"climbs the ladder onto the crane girder (y=%.2f)" % _player.global_position.y)
	_check(stats.seconds < 4.0, "ladder climb takes %.1f s" % stats.seconds)
	stats = await _climb(Vector3(27.4, 6.0, -2.0), -0.8, 3.0)
	_check(_player.global_position.y < 2.0, "looking down climbs back down (y=%.2f)" % _player.global_position.y)
	# Jump halfway up lets go: the player falls back to the floor.
	await _climb(Vector3(27.4, 6.0, -2.0), 0.3, 0.3)
	var cmd := PlayerCommand.new()
	cmd.jump = true
	for i: int in 90:
		_player.movement.physics_step(1.0 / Engine.physics_ticks_per_second, cmd)
		cmd = PlayerCommand.new()
		await get_tree().physics_frame
	_check(_player.global_position.y < 2.0 and _player.global_position.z < -2.4,
		"jump lets go of the ladder (y=%.2f, z=%.2f)" % [_player.global_position.y, _player.global_position.z])


## Holds forward facing +Z with `pitch` (ladders climb toward the look) for up to `seconds`;
## stops once standing on a floor above the start after climbing.
func _climb(from: Vector3, pitch: float, seconds: float) -> Dictionary:
	_player.global_position = from
	_player.rotation.y = PI
	_player.velocity = Vector3.ZERO
	_player.movement.reset()
	_player.look_pitch = pitch
	await _frames(2)
	var cmd := PlayerCommand.new()
	cmd.move = Vector2(0.0, -1.0)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var stats: Dictionary = {"top": -INF, "seconds": 0.0}
	var ticks: int = 0
	while ticks * dt < seconds:
		_player.movement.look_pitch = pitch
		_player.movement.physics_step(dt, cmd)
		await get_tree().physics_frame
		ticks += 1
		stats.top = maxf(stats.top, _player.global_position.y)
		if pitch > 0.0 and _player.global_position.y > CATWALK_TOP and _player.global_position.z > from.z + 1.1:
			cmd.move = Vector2.ZERO # Over the narrow girder: let go of forward.
		if pitch > 0.0 and _player.is_on_floor() and _player.global_position.y > CATWALK_TOP - 0.1:
			break
	stats.seconds = ticks * dt
	_player.look_pitch = 0.0
	return stats


func _walk(from: Vector3, yaw: float, target: Vector3, seconds: float = 4.0) -> Dictionary:
	_player.global_position = from
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO
	_player.movement.reset()
	await _frames(2)
	var cmd := PlayerCommand.new()
	cmd.move = Vector2(0.0, -1.0)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
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
		var offset: Vector3 = _player.global_position - target
		if Vector3(offset.x, 0.0, offset.z).dot(forward) >= 0.0:
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

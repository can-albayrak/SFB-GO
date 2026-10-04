extends Node
## Third-person animation preview on the offline Test Range: fake remote players run,
## strafe, back-pedal while looking up and down, crouch-walk, jump, fire and die in a loop.
##   godot --path . res://tests/anim_preview.tscn
##   godot --path . res://tests/anim_preview.tscn -- --shots=C:/tmp/anim   (saves frames, quits)
##   ... -- --focus=strafe   (camera close on one act: run_circle, strafe, back_aim, crouch, jump, die)
## The fakes are moved by hand like snapshots would; nothing goes through the network.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ACTS: Array[String] = ["run_circle", "strafe", "back_aim", "crouch", "jump", "die"]
const SPACING: float = 3.0
const SHOT_TIMES: Array[float] = [1.0, 1.6, 2.3, 3.1, 4.4, 5.2]
const FIRE_PERIOD: float = 0.45
const DIE_PERIOD: float = 6.0

var _game: Game
var _fakes: Array[Player] = []
var _origins: Array[Vector3] = []
var _time: float = 0.0
var _fire_timer: float = 0.0
var _shots_dir: String = ""
var _shot_index: int = 0
var _camera: Camera3D
var _focus: int = -1


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--focus="):
			_focus = ACTS.find(arg.trim_prefix("--focus="))
	_open.call_deferred()


func _open() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.player_names[1] = "Viewer"
	Net.map_path = Net.DEFAULT_MAP_PATH
	Match.configure(0, 0.0)
	_game = GAME_SCENE.instantiate() as Game
	add_child(_game)
	for i: int in 3:
		await get_tree().process_frame
	var local := _game.players_root.get_node("1") as Player
	local.visible = false # Only the fakes are on screen.
	var base: Vector3 = local.global_position
	var forward: Vector3 = -local.global_basis.z
	var right: Vector3 = local.global_basis.x
	for i: int in ACTS.size():
		var fake: Player = PLAYER_SCENE.instantiate()
		fake.name = str(100 + i)
		fake.setup_authority(100 + i)
		var origin: Vector3 = _floor_below(base + forward * 7.0 + right * (float(i) - (ACTS.size() - 1) * 0.5) * SPACING)
		fake.position = origin
		_game.players_root.add_child(fake)
		fake.rotation.y = local.rotation.y + PI # Facing the viewer.
		_fakes.append(fake)
		_origins.append(origin)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.fov = 70.0
	_camera.global_position = base + Vector3.UP * 1.7 + forward * 1.5
	_camera.look_at(base + forward * 7.0 + Vector3.UP * 0.9)
	_camera.current = true


func _floor_below(point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = _game.get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 5.0, 1)
	var hit: Dictionary = space.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else point


func _process(delta: float) -> void:
	if _fakes.is_empty():
		return
	_time += delta
	_fire_timer -= delta
	var fire_now: bool = _fire_timer <= 0.0
	if fire_now:
		_fire_timer = FIRE_PERIOD
	for i: int in _fakes.size():
		_act(_fakes[i], _origins[i], ACTS[i], fire_now)
	if _focus >= 0:
		var target: Vector3 = _origins[_focus] + Vector3.UP * 1.1
		var toward: Vector3 = -_fakes[_focus].global_basis.z
		_camera.global_position = target + toward * 2.6 + _fakes[_focus].global_basis.x * 1.2 + Vector3.UP * 0.2
		_camera.look_at(target)
	_camera.current = true
	if not _shots_dir.is_empty() and _shot_index < SHOT_TIMES.size() and _time >= SHOT_TIMES[_shot_index]:
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("%s/anim_%d.png" % [_shots_dir, _shot_index])
		_shot_index += 1
		if _shot_index == SHOT_TIMES.size():
			get_tree().quit()


func _act(fake: Player, origin: Vector3, act: String, fire_now: bool) -> void:
	var facing: float = fake.rotation.y
	var side: Vector3 = fake.global_basis.x
	var ahead: Vector3 = -fake.global_basis.z
	match act:
		"run_circle":
			var angle: float = _time * 2.0
			fake.global_position = origin + Vector3(cos(angle), 0.0, sin(angle)) * 1.2
			fake.rotation.y = -angle # Tangent of the circle: forward run.
			if fire_now:
				_fire(fake)
		"strafe":
			fake.global_position = origin + side * sin(_time * 2.5) * 1.2
			if fire_now:
				_fire(fake)
		"back_aim":
			fake.global_position = origin - ahead * fmod(_time * 2.0, 3.0)
			fake.look_pitch = sin(_time * 1.5) * 0.9
		"crouch":
			fake.apply_pose(true)
			fake.global_position = origin + side * clampf(sin(_time * 1.2) * 2.0, -1.0, 1.0) * 1.0
		"jump":
			var hop: float = fmod(_time, 1.4)
			fake.global_position = origin + Vector3.UP * maxf(0.0, 4.5 * hop - 4.9 * hop * hop)
		"die":
			var cycle: float = fmod(_time, DIE_PERIOD)
			var alive: bool = cycle < DIE_PERIOD * 0.25
			if fake.is_alive != alive:
				fake.is_alive = alive
	fake.rotation.y = fake.rotation.y if act == "run_circle" else facing


func _fire(fake: Player) -> void:
	var from: Vector3 = fake.get_aim_origin()
	fake.effects._show_shot(from, from - fake.global_basis.z * 20.0, false)

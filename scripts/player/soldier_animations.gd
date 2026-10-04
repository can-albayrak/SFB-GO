class_name SoldierAnimations
extends RefCounted
## Builds the third-person animation library once from the Mixamo FBX clips in
## assets/models/characters/mixamo (skeleton only, no mesh). Walk clips lose their root
## motion (the body is placed by the game) and missing directions are made by playing
## existing clips backwards.

const DIR: String = "res://assets/models/characters/mixamo/"
const SOURCE_CLIP: StringName = &"mixamo_com"
const SKELETON_SOURCE: String = "rifle_aiming_idle.fbx"
const HIPS_TRACK: NodePath = ^"Skeleton3D:mixamorig_Hips"

## Clip name -> [file, loop, strip root motion].
const CLIPS: Dictionary = {
	&"idle": ["rifle_aiming_idle.fbx", true, true],
	&"run_fwd": ["walk_with_rifle.fbx", true, true],
	&"run_left": ["walk_left.fbx", true, true],
	&"run_right": ["walk_right.fbx", true, true],
	&"run_fwd_left": ["walk_forward_left.fbx", true, true],
	&"crouch_right": ["walk_crouching_right.fbx", true, true],
	&"jump_up": ["jump_up.fbx", false, true],
	&"jump_down": ["jump_down.fbx", false, true],
	&"fire": ["firing_rifle.fbx", true, true],
	&"dying": ["dying.fbx", false, false], # Keeps root motion: the body falls forward.
}

## Ground speed of each walk clip in m/s (measured from its root motion), keyed by the
## blend space point it sits on (x = right, y = forward).
static var ground_points: Dictionary = {}
static var crouch_speed: float = 2.0

static var _library: AnimationLibrary
static var _skeleton: Skeleton3D


static func get_library() -> AnimationLibrary:
	if _library == null:
		_build()
	return _library


## A fresh copy of the Mixamo skeleton (rest pose, metres, facing +Z).
static func create_skeleton() -> Skeleton3D:
	if _skeleton == null:
		var scene: Node = (load(DIR + SKELETON_SOURCE) as PackedScene).instantiate()
		_skeleton = scene.get_node("Skeleton3D") as Skeleton3D
		scene.remove_child(_skeleton)
		scene.free()
	var copy: Skeleton3D = _skeleton.duplicate() as Skeleton3D
	copy.name = "Skeleton3D"
	return copy


static func _build() -> void:
	_library = AnimationLibrary.new()
	var drift: Dictionary = {}
	for clip: StringName in CLIPS:
		var info: Array = CLIPS[clip]
		var animation: Animation = _load_clip(info[0])
		var moved: Vector3 = _root_drift(animation)
		drift[clip] = Vector2(-moved.x, moved.z) / animation.length # Model faces +Z, its right is -X.
		if info[2]:
			_strip_root_motion(animation)
		animation.loop_mode = Animation.LOOP_LINEAR if info[1] else Animation.LOOP_NONE
		_library.add_animation(clip, animation)

	_library.add_animation(&"run_back", _reversed(_library.get_animation(&"run_fwd")))
	_library.add_animation(&"run_back_right", _reversed(_library.get_animation(&"run_fwd_left")))
	_library.add_animation(&"crouch_left", _reversed(_library.get_animation(&"crouch_right")))
	_library.add_animation(&"crouch_idle", _frozen(_library.get_animation(&"crouch_right"), 0.0))

	for clip: StringName in [&"run_fwd", &"run_left", &"run_right", &"run_fwd_left"]:
		ground_points[clip] = drift[clip]
	ground_points[&"run_back"] = -(drift[&"run_fwd"] as Vector2)
	ground_points[&"run_back_right"] = -(drift[&"run_fwd_left"] as Vector2)
	crouch_speed = absf((drift[&"crouch_right"] as Vector2).x)


static func _load_clip(file: String) -> Animation:
	var scene: Node = (load(DIR + file) as PackedScene).instantiate()
	var player: AnimationPlayer = scene.get_node("AnimationPlayer") as AnimationPlayer
	var animation: Animation = player.get_animation(SOURCE_CLIP).duplicate(true) as Animation
	scene.free()
	return animation


static func _root_drift(animation: Animation) -> Vector3:
	var track: int = animation.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track < 0 or animation.track_get_key_count(track) < 2:
		return Vector3.ZERO
	var last: int = animation.track_get_key_count(track) - 1
	return (animation.track_get_key_value(track, last) as Vector3) - (animation.track_get_key_value(track, 0) as Vector3)


## Removes the steady horizontal travel of the hips, keeping the sway.
static func _strip_root_motion(animation: Animation) -> void:
	var track: int = animation.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track < 0:
		return
	var moved: Vector3 = _root_drift(animation)
	var start: Vector3 = animation.track_get_key_value(track, 0)
	for key: int in animation.track_get_key_count(track):
		var share: float = animation.track_get_key_time(track, key) / animation.length
		var value: Vector3 = animation.track_get_key_value(track, key)
		value.x -= start.x + moved.x * share
		value.z -= start.z + moved.z * share
		animation.track_set_key_value(track, key, value)


static func _reversed(source: Animation) -> Animation:
	var animation := Animation.new()
	animation.length = source.length
	animation.loop_mode = source.loop_mode
	for track: int in source.get_track_count():
		var copy: int = animation.add_track(source.track_get_type(track))
		animation.track_set_path(copy, source.track_get_path(track))
		animation.track_set_interpolation_type(copy, source.track_get_interpolation_type(track))
		for key: int in source.track_get_key_count(track):
			var time: float = source.length - source.track_get_key_time(track, key)
			animation.track_insert_key(copy, time, source.track_get_key_value(track, key))
	return animation


## One pose held still, sampled from `source` at `time`.
static func _frozen(source: Animation, time: float) -> Animation:
	var animation := Animation.new()
	animation.length = 0.1
	animation.loop_mode = Animation.LOOP_LINEAR
	for track: int in source.get_track_count():
		var copy: int = animation.add_track(source.track_get_type(track))
		animation.track_set_path(copy, source.track_get_path(track))
		var value: Variant
		match source.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				value = source.position_track_interpolate(track, time)
			Animation.TYPE_ROTATION_3D:
				value = source.rotation_track_interpolate(track, time)
			Animation.TYPE_SCALE_3D:
				value = source.scale_track_interpolate(track, time)
			_:
				value = source.track_get_key_value(track, 0)
		animation.track_insert_key(copy, 0.0, value)
	return animation

class_name Sfx
extends RefCounted
## Sound effects: positional one-shots (gunshots, explosions, footsteps) and UI blips
## (hit marker, kill). Cosmetic only, played locally on each peer. The clips are generated
## by tools/gen_sfx.py.

const SHOT_LIGHT: AudioStream = preload("res://assets/audio/shot_light.wav")
const SHOT_RIFLE: AudioStream = preload("res://assets/audio/shot_rifle.wav")
const SHOT_HEAVY: AudioStream = preload("res://assets/audio/shot_heavy.wav")
const SHOT_SHOTGUN: AudioStream = preload("res://assets/audio/shot_shotgun.wav")
const SHOT_RAIL: AudioStream = preload("res://assets/audio/shot_rail.wav")
const SHOT_LAUNCHER: AudioStream = preload("res://assets/audio/shot_launcher.wav")
const EXPLOSION: AudioStream = preload("res://assets/audio/explosion.wav")
const LAND: AudioStream = preload("res://assets/audio/land.wav")
const HIT: AudioStream = preload("res://assets/audio/hit.wav")
const KILL: AudioStream = preload("res://assets/audio/kill.wav")
const SWING: AudioStream = preload("res://assets/audio/swing.wav")
const STEPS: Array[AudioStream] = [
	preload("res://assets/audio/step_1.wav"),
	preload("res://assets/audio/step_2.wav"),
	preload("res://assets/audio/step_3.wav"),
]

const SHOT_DB: float = -4.0
const EXPLOSION_DB: float = 2.0
const STEP_DB: float = -10.0
const UI_DB: float = -8.0
const PITCH_JITTER: float = 0.06
const UNIT_SIZE: float = 8.0 ## Metres at which a sound is at its full volume.
const MAX_DISTANCE: float = 120.0


## Plays `stream` once at `point` in `parent`'s world; the player frees itself afterwards.
static func play_at(parent: Node, stream: AudioStream, point: Vector3, volume_db: float = 0.0, unit_size: float = UNIT_SIZE) -> void:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = volume_db + _master_db()
	audio.unit_size = unit_size
	audio.max_distance = MAX_DISTANCE
	audio.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	audio.attenuation_filter_cutoff_hz = 8000.0
	audio.finished.connect(audio.queue_free)
	parent.add_child(audio)
	audio.global_position = point
	audio.play()


## Non-positional (hit marker, kill confirm).
static func play_ui(parent: Node, stream: AudioStream, volume_db: float = UI_DB) -> void:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = volume_db + _master_db()
	audio.finished.connect(audio.queue_free)
	parent.add_child(audio)
	audio.play()


static func shot(parent: Node, def: WeaponDef, point: Vector3) -> void:
	if def == null:
		return
	play_at(parent, shot_stream(def), point, SHOT_DB, UNIT_SIZE * 2.0)


## Picks the gunshot clip from the weapon's stats, so new weapons get a fitting sound.
static func shot_stream(def: WeaponDef) -> AudioStream:
	if def.grenade != null:
		return SHOT_LAUNCHER
	if def.pierce_walls:
		return SHOT_RAIL
	if not def.pellet_pattern.is_empty():
		return SHOT_SHOTGUN
	if def.damage >= 45.0:
		return SHOT_HEAVY
	if def.damage >= 20.0 or def.fire_interval >= 0.25:
		return SHOT_RIFLE
	return SHOT_LIGHT


static func explosion(parent: Node, point: Vector3) -> void:
	play_at(parent, EXPLOSION, point, EXPLOSION_DB, UNIT_SIZE * 3.0)


static func step(parent: Node, point: Vector3) -> void:
	play_at(parent, STEPS[randi() % STEPS.size()], point, STEP_DB, UNIT_SIZE * 0.5)


static func _master_db() -> float:
	return linear_to_db(maxf(Settings.sfx_volume, 0.0001))
